import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart'; // Import your custom navbar

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous screen
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CivicConnect',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildNotificationItem(
                    icon: Icons.construction,
                    title: 'Pot-Hole Repair',
                    subtitle: 'Report is in review',
                    date: '21/09/2024',
                    iconColor: Colors.amber,
                  ),
                  _buildNotificationItem(
                    icon: Icons.lightbulb,
                    title: 'Street Light Broken',
                    subtitle: 'Issue was Solved',
                    date: '21/09/2024',
                    iconColor: Colors.green,
                  ),
                  _buildNotificationItem(
                    icon: Icons.construction,
                    title: 'Pot-Hole Repair',
                    subtitle: 'Report was declined',
                    date: '21/09/2024',
                    iconColor: Colors.red,
                  ),
                  _buildNotificationItem(
                    icon: Icons.water_drop,
                    title: 'Water Supply',
                    subtitle: 'Issue was Solved',
                    date: '21/09/2024',
                    iconColor: Colors.green,
                  ),
                  _buildNotificationItem(
                    icon: Icons.volume_up,
                    title: 'Noise Pollution',
                    subtitle: 'Issue was Solved',
                    date: '21/09/2024',
                    iconColor: Colors.green,
                  ),
                  _buildNotificationItem(
                    icon: Icons.home,
                    title: 'Illegal hold of property',
                    subtitle: 'Issue was Solved',
                    date: '21/09/2024',
                    iconColor: Colors.green,
                  ),
                  _buildNotificationItem(
                    icon: Icons.security,
                    title: 'Theft and Crimes',
                    subtitle: 'Issue was Solved',
                    date: '21/09/2024',
                    iconColor: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          CustomNavBarCurved(), // Your custom navigation bar widget
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String date,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconColor.withOpacity(0.2),
            child: Icon(icon, color: iconColor),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            date,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
