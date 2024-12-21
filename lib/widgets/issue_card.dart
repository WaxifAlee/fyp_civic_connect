import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/widgets/image_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // For launching Google Maps
import 'package:intl/intl.dart'; // For date formatting

class IssueCard extends StatelessWidget {
  final String reporterName;
  final String profileImage;
  final List<String> issueImages;
  final String title;
  final String description;
  final String location;
  final String status;
  final double latitude;
  final double longitude;
  final String date;
  final String category;

  const IssueCard({
    Key? key,
    required this.reporterName,
    required this.profileImage,
    required this.issueImages,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.category,
  }) : super(key: key);

  void _openMap() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  String _getTimeAgo(String date) {
    final DateTime issueDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(date);
    final Duration difference = DateTime.now().difference(issueDate);

    if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reporter Info
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(profileImage),
                  radius: 20,
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 12),
                    Text(
                      reporterName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(_getTimeAgo(date),
                        style: GoogleFonts.poppins(fontSize: 10)),
                  ],
                )
              ],
            ),
            SizedBox(height: 12),
            // Title
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            // Image Slider
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ImageSlider(images: issueImages),
            ),
            SizedBox(height: 12),
            // Description
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            // Location & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: _openMap,
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.red),
                      SizedBox(width: 4),
                      Text(
                        'Open in Maps',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  category,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[600]),
                ),
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == "solved"
                        ? Colors.green[200]
                        : Colors.orange[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: status == "solved" ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
