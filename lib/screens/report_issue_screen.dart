import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fyp_civic_connect/screens/maplocationpicker.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:fyp_civic_connect/widgets/bordered_dropdown.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';
import 'package:fyp_civic_connect/widgets/image_picker_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../utils/image_compression.dart';
import 'package:fyp_civic_connect/utils/report_code_generator.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  List<XFile> _images = [];
  final _formKey = GlobalKey<FormState>();
  String? selectedValue;
  TextEditingController locationController = TextEditingController();
  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  bool isSubmitting = false;

  void _handleImagesSelected(List<XFile> images) {
    setState(() {
      _images = images;
    });
  }

  Future<void> _pickLocation(BuildContext context) async {
    LatLng? pickedLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapLocationPicker()),
    );

    if (pickedLocation != null) {
      setState(() {
        locationController.text =
            "${pickedLocation.latitude}, ${pickedLocation.longitude}";
      });
    }
  }

  Future<void> _submitReport() async {
    // Check for minimum image requirement
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one image is required')),
      );
      return;
    }

    if (_formKey.currentState!.validate() && selectedValue != null) {
      setState(() {
        isSubmitting = true;
      });

      try {
        // Initialize Supabase client
        final supabase = Supabase.instance.client;

        // Upload images to Supabase Storage
        List<String> imageUrls = [];
        for (XFile image in _images) {
          String imageId = const Uuid().v4();
          final file = File(image.path);

          // Compress image using TinyPNG
          final compressedFile = await ImageCompression.compressImage(file);

          final response = await supabase.storage
              .from('reports-images')
              .uploadBinary(
                  'public/$imageId.jpg', compressedFile.readAsBytesSync());

          if (response.isEmpty) {
            throw Exception('Failed to upload image');
          }

          final publicUrl = supabase.storage
              .from('reports-images')
              .getPublicUrl('public/$imageId.jpg');
          imageUrls.add(publicUrl);
        }

        // Generate report code
        final reportCode =
            await ReportCodeGenerator.generateReportCode(selectedValue!);

        // Save report data to Firestore
        await FirebaseFirestore.instance.collection('reports').add({
          'title': titleController.text,
          'description': descriptionController.text,
          'category': selectedValue,
          'location': locationController.text,
          'images': imageUrls,
          'reporterId': FirebaseAuth.instance.currentUser!.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'avatar': globalCitizenUser!.displayPicture,
          'reporterName': globalCitizenUser!.fullName,
          'reportCode': reportCode, // Add the report code
          'upvotes': 0,
          'upvotedBy': [],
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully!')),
        );

        // Reset the form
        setState(() {
          _images.clear();
          titleController.clear();
          descriptionController.clear();
          locationController.clear();
          selectedValue = null;
        });
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      } finally {
        setState(() {
          isSubmitting = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CustomNavBarCurved(),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
              left: AppTheme.borderPadding,
              right: AppTheme.borderPadding,
              top: AppTheme.borderPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Report the Issue',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTheme.titleFontSize,
                    color: AppTheme.themeGray),
                textAlign: TextAlign.center,
              ),
              Text(
                'Spamming will result in permanent ban! ⚠️',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.themePink),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text("Attach Media Files",
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: AppTheme.themeGray,
                      fontWeight: FontWeight.w500)),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ImagePickerWidget(
                      onImagesSelected: _handleImagesSelected,
                    ),
                    EntryText(title: "Title"),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),
                    EntryText(title: "Description"),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 5,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),
                    EntryText(title: "Category"),
                    BorderedDropdown(
                      value: selectedValue,
                      hintText: "Choose an Option",
                      items: [
                        "Municipal Corportaion",
                        "Police Department",
                        "Fire & Emergency Services",
                        "Electricity & Gas Department",
                        "Public Works Department (PWD)",
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedValue = value;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EntryText(title: "Location"),
                              TextField(
                                controller: locationController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                // Add validator for location field
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Location is required.')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          margin: EdgeInsets.only(
                              top: 24), // Align the icon with the entry field
                          child: IconButton(
                            onPressed: () => _pickLocation(context),
                            icon: Icon(Icons.location_on, color: Colors.white),
                            color: AppTheme.themePurple,
                            iconSize: 32,
                            padding: EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.themePurple,
                              shape: CircleBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4267B2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 22),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
                          ? Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Please Wait...',
                                  style: GoogleFonts.poppins(
                                      color: AppTheme.themeWhite),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Submit',
                                  style: GoogleFonts.poppins(
                                      color: AppTheme.themeWhite),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class EntryText extends StatelessWidget {
  final String title;
  const EntryText({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(
        title,
        style: GoogleFonts.poppins(fontSize: 18, color: AppTheme.themeGray),
      ),
      Text(
        " *",
        style: GoogleFonts.poppins(color: AppTheme.themeRed),
      ),
    ]);
  }
}
