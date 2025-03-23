import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/widgets/image_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // For launching Google Maps
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Authentication
import 'package:fyp_civic_connect/themes/app_theme.dart'; // For AppTheme

class IssueCard extends StatefulWidget {
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
  final String id; // Add this
  final int upvotes; // Add this
  final List<String> upvotedBy; // Add this
  final Function()? onUpvote; // Add this

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
    required this.id,
    this.upvotes = 0,
    this.upvotedBy = const [],
    this.onUpvote,
  }) : super(key: key);

  @override
  _IssueCardState createState() => _IssueCardState();
}

class _IssueCardState extends State<IssueCard> {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _openMap() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showImageDialog(BuildContext context, List<String> images) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 600,
                width: 600,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Image.network(images[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
    final currentUser = FirebaseAuth.instance.currentUser;
    final hasUpvoted = currentUser != null &&
        widget.upvotedBy.contains(currentUser.uid); // Fixed this line

    return GestureDetector(
      onTap: _toggleExpand,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reporter Info
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(widget.profileImage),
                    radius: 20,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 12),
                      Text(
                        widget.reporterName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(_getTimeAgo(widget.date),
                          style: GoogleFonts.poppins(fontSize: 10)),
                    ],
                  )
                ],
              ),
              SizedBox(height: 12),
              // Title
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              // Image Slider
              AspectRatio(
                aspectRatio: 16 / 9,
                child: GestureDetector(
                  onTap: () {
                    _showImageDialog(context, widget.issueImages);
                  },
                  child: ImageSlider(images: widget.issueImages),
                ),
              ),
              SizedBox(height: 12),
              // Description
              Text(
                widget.description,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: _isExpanded ? null : 2,
                overflow:
                    _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              // Location & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.category,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  // Status Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.status == "solved"
                          ? Colors.green[200]
                          : Colors.orange[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.status == "solved"
                          ? Icons.check
                          : Icons.remove_red_eye,
                      color: widget.status == "solved"
                          ? Colors.green
                          : Colors.orange,
                      size: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Upvote Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text("Upvote ", style: GoogleFonts.poppins(fontSize: 12)),
                      IconButton(
                        icon: Icon(
                          hasUpvoted
                              ? Icons.arrow_circle_up
                              : Icons.arrow_circle_up_outlined,
                          color:
                              hasUpvoted ? AppTheme.themePurple : Colors.grey,
                        ),
                        onPressed: widget.onUpvote,
                      ),
                      Text(
                        "${widget.upvotes}",
                        style: TextStyle(
                          color:
                              hasUpvoted ? AppTheme.themePurple : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
