import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(List<XFile>) onImagesSelected;

  const ImagePickerWidget({Key? key, required this.onImagesSelected})
      : super(key: key);

  @override
  _ImagePickerWidgetState createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  Future<void> _pickImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles != null) {
        setState(() {
          _selectedImages = pickedFiles.length > 3
              ? pickedFiles.sublist(0, 3) // Limit to 3 images
              : pickedFiles;
        });
        // Pass the selected images to the parent via the callback
        widget.onImagesSelected(_selectedImages);
      }
    } catch (e) {
      print("Image picker error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 100, color: Colors.grey[600]),
                SizedBox(height: 10),
                Text(
                  "(Upto 3 images in jpg/png format)",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _pickImages,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                  ),
                  child: Text("Select", style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        if (_selectedImages.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _selectedImages.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (BuildContext context, int index) {
              return Image.file(
                File(_selectedImages[index].path),
                fit: BoxFit.cover,
              );
            },
          ),
      ],
    );
  }
}
