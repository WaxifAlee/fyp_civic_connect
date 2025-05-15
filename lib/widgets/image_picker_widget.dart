import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_compression.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(List<XFile>) onImagesSelected;

  const ImagePickerWidget({super.key, required this.onImagesSelected});

  @override
  _ImagePickerWidgetState createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      List<XFile> compressedFiles = [];
      for (XFile file in pickedFiles) {
        final compressedFile =
            await ImageCompression.compressImage(File(file.path));
        compressedFiles.add(XFile(compressedFile.path));
      }
      setState(() {
        _selectedImages = compressedFiles.length > 3
            ? compressedFiles.sublist(0, 3) // Limit to 3 images
            : compressedFiles;
      });
      // Pass the selected images to the parent via the callback
      widget.onImagesSelected(_selectedImages);
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
                  "*Required (1-3 images in jpg/png format)",
                  style: TextStyle(
                      color: Colors.red[400], fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _pickImages,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text("Select Images",
                      style: TextStyle(color: Colors.white)),
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
