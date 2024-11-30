// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:fyp_civic_connect/widgets/bordered_dropdown.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';
import 'package:fyp_civic_connect/widgets/image_picker_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  List<XFile> _images = [];

  void _handleImagesSelected(List<XFile> images) {
    setState(() {
      _images = images;
    });
  }

  final _formKey = GlobalKey<FormState>();
  String? selectedValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: CustomNavBarCurved(),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
                left: AppTheme.borderPadding, right: AppTheme.borderPadding),
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
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ImagePickerWidget(
                      onImagesSelected: _handleImagesSelected,
                    ),
                    EntryText(title: "Title"),
                    TextField(
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      )),
                    ),
                    SizedBox(height: 12),
                    EntryText(title: "Description"),
                    TextField(
                      minLines: 5,
                      maxLines: 5,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      )),
                    ),
                    SizedBox(height: 12),
                    EntryText(title: "Category"),
                    BorderedDropdown(
                      value: selectedValue,
                      hintText: "Choose an Option",
                      items: [
                        "Garbage Disposal",
                        "Civil Infastructure",
                        "Water Supply",
                        "Illegal Property Hold"
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedValue = value;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    EntryText(title: "Location"),
                    TextField(
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      )),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Add your submission logic here
                      },
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
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Submit',
                            style:
                                GoogleFonts.poppins(color: AppTheme.themeWhite),
                          ),
                        ],
                      ),
                    )
                  ],
                ))
              ],
            ),
          ),
        ));
  }
}

class EntryText extends StatelessWidget {
  final String title;
  const EntryText({required this.title});
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
