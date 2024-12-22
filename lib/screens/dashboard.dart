import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/models/citizen_user.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:fyp_civic_connect/screens/explore_issues_screen.dart';
import 'package:fyp_civic_connect/screens/my_reports_screen.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ReportService _reportService = ReportService();
  bool _isLoading = true;
  String _errorMessage = "";
  int _solvedCount = 0;
  int _reportedCount = 0;
  int _pendingCount = 0;
  List<Report> _recentReports = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });
    try {
      List<Report> reports = await _reportService.fetchReportsByCurrentUser();
      setState(() {
        _solvedCount =
            reports.where((report) => report.status == "solved").length;
        _reportedCount = reports.length;
        _pendingCount =
            reports.where((report) => report.status == "pending").length;
        _recentReports =
            reports.take(3).toList(); // Get the 3 most recent reports
      });
    } catch (error) {
      setState(() {
        _errorMessage = "Failed to load dashboard data. Please try again.";
      });
    } finally {
      setState(() {
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final displayPicture = globalCitizenUser!.displayPicture;
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
            padding: EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Icon(Icons.notifications_rounded, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : SingleChildScrollView(
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
                                    displayPicture != null
                                        ? "https://vlkfmraxbpwctukymsyt.supabase.co/storage/v1/object/public/$displayPicture"
                                        : "https://ui-avatars.com/api/?name=${globalCitizenUser!.fullName}&background=0D8ABC&color=fff&size=128" // Default avatar
                                    ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  globalCitizenUser!.fullName ??
                                      "Hmm You are...",
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
                          padding: EdgeInsets.only(left: 5, right: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              MyReportsScreen()));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xffB2AFEF),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
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
                                onPressed: () {
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              ExploreIssuesScreen()));
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Color(0xffB2AFEF), width: 3.0),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
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
                          decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFD9D9D9))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildOverviewItem(_solvedCount.toString(),
                                  'Solved', AppTheme.mintGreen),
                              _buildOverviewItem(_reportedCount.toString(),
                                  'Reported', AppTheme.softPurple),
                              _buildOverviewItem(_pendingCount.toString(),
                                  'Pending', AppTheme.honeyYellow),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
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
                        SizedBox(height: 12),
                        _recentReports.isEmpty
                            ? Center(
                                child: Text(
                                  'No reports found.',
                                  style:
                                      GoogleFonts.poppins(color: Colors.grey),
                                ),
                              )
                            : Column(
                                children: _recentReports
                                    .map((report) => _buildRecentReport(
                                        report.title ?? 'No Title',
                                        report.status ?? 'Unknown',
                                        report.date.toString().split(' ')[0]))
                                    .toList(),
                              ),
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
    final String? description;

    if (status == "declined") {
      statusColor = AppTheme.themePink;
      statusIcon = Icon(Icons.cancel_rounded, size: 32, color: Colors.black);
      description = "This report was declined by the admin.";
    } else if (status == "pending") {
      statusColor = AppTheme.honeyYellow;
      statusIcon = Icon(Icons.feedback_outlined, color: Colors.black, size: 32);
      description = "This report is waiting for admin's response.";
    } else {
      statusColor = AppTheme.mintGreen;
      statusIcon = Icon(Icons.check_circle_outline_rounded,
          color: Colors.black, size: 32);
      description = "This report has been successfully solved.";
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
                  Text(description,
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
