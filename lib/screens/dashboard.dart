import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';

class DashboardPage extends StatefulWidget {
  final User? user;
  const DashboardPage({super.key, required this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? userName;

  @override
  void initState() {
    super.initState();
    fetchUserName();
  }

  Future<void> fetchUserName() async {
    try {
      if (widget.user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            userName = userDoc.data()!['full_name'] ?? 'User';
          });
        } else {
          setState(() {
            userName = 'User';
          });
        }
      }
    } catch (e) {
      setState(() {
        userName = 'User';
      });
    }
  }

  String getGreeting() {
    final currentHour = DateTime.now().hour;
    if (currentHour >= 5 && currentHour < 12) {
      return "Good Morning! \ud83c\udf05";
    } else if (currentHour >= 12 && currentHour < 17) {
      return "Good Afternoon! \ud83c\udf1e";
    } else {
      return "Good Evening! \ud83c\udf15";
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentReports() async {
    await Future.delayed(Duration(seconds: 2));
    return [
      {'title': 'Pot-Hole Repair', 'status': 'pending', 'date': '21/09/2024'},
      {
        'title': 'Street Light Broken',
        'status': 'solved',
        'date': '21/09/2024'
      },
      {'title': 'Pot-Hole Repair', 'status': 'declined', 'date': '21/09/2024'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 40,
        title: Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text("Dashboard",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500, fontSize: 20)),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 32),
            child: IconButton(
              icon: Icon(Icons.notifications_rounded, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Section
              Column(
                children: [
                  CircleAvatar(
                    radius: 90,
                    backgroundColor: Color(0xffB2AFEF),
                    child: CircleAvatar(
                      radius: 84,
                      backgroundImage: NetworkImage(
                          "https://avatar.iran.liara.run/username?username=$userName"),
                    ),
                  ),
                  SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        userName ?? "Hmm You are...",
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        getGreeting(),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Buttons
              Padding(
                padding: EdgeInsets.only(left: 25, right: 25),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xffB2AFEF),
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: Text(
                        'View My Reports',
                        style: GoogleFonts.poppins(
                            color: Color(0xff000000),
                            fontWeight: FontWeight.normal,
                            fontSize: 14),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xffB2AFEF), width: 3.0),
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: Text(
                        'Explore Issues',
                        style: GoogleFonts.poppins(
                          color: AppTheme.themeGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),
              // Overview Section
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Overview',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      textStyle: TextStyle()),
                ),
              ),

              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(20.0),
                decoration:
                    BoxDecoration(border: Border.all(color: Color(0xFFD9D9D9))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOverviewItem('59', 'Solved', AppTheme.mintGreen),
                    _buildOverviewItem('69', 'Reported', AppTheme.softPurple),
                    _buildOverviewItem('5', 'Pending', AppTheme.honeyYellow),
                  ],
                ),
              ),

              SizedBox(height: 24),
              // Recent Reports Section
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: EdgeInsets.only(left: 25),
                    child: Text(
                      'Recent Reports',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.themePurple),
                    )),
              ),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchRecentReports(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return Column(
                      children: snapshot.data!
                          .map((report) => _buildRecentReport(report['title'],
                              report['status'], report['date']))
                          .toList(),
                    );
                  } else {
                    return Center(
                      child: Text(
                        'No reports found.',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    );
                  }
                },
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomNavBarCurved(),
    );
  }

  Widget _buildOverviewItem(String count, String label, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentReport(String title, String status, String date) {
    final Color? statusColor;
    final Icon? statusIcon;
    final String? _description;

    if (status == "declined") {
      statusColor = AppTheme.themePink;
      statusIcon = Icon(Icons.cancel_rounded, size: 32, color: Colors.black);
      _description = "This report was declined by the admin.";
    } else if (status == "pending") {
      statusColor = AppTheme.honeyYellow;
      statusIcon = Icon(Icons.feedback_outlined, color: Colors.black, size: 32);
      _description = "This report is waiting for admin's response.";
    } else {
      statusColor = AppTheme.mintGreen;
      statusIcon = Icon(Icons.check_circle_outline_rounded,
          color: Colors.black, size: 32);
      _description = "This report has been successfully solved.";
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Color(0xFFD9D9D9))),
      padding: EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: statusColor,
              child: statusIcon,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(_description,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Color(0xff4f4f4f))),
                  Text(date,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xff4f4f4f)))
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
