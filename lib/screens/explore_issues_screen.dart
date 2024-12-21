import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';
import 'package:fyp_civic_connect/widgets/issue_card.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:google_fonts/google_fonts.dart';

class ExploreIssuesScreen extends StatefulWidget {
  const ExploreIssuesScreen({Key? key}) : super(key: key);

  @override
  _ExploreIssuesScreenState createState() => _ExploreIssuesScreenState();
}

class _ExploreIssuesScreenState extends State<ExploreIssuesScreen> {
  final ReportService _reportService = ReportService();
  List<Report> _reports = [];
  List<Report> _filteredReports = [];
  String _searchQuery = "";
  bool _isLoading = false;
  String _errorMessage = "";
  int _currentPage = 1;
  final int _reportsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });
    try {
      List<Report> reports = await _reportService.fetchAllReports();
      setState(() {
        _reports = reports;
        _filteredReports = reports; // Initially, show all reports
      });
    } catch (error) {
      setState(() {
        _errorMessage = "Failed to load reports. Please try again.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterReports(String query) {
    setState(() {
      _searchQuery = query;
      _filteredReports = _reports.where((report) {
        return report.title!.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _applyAdvancedFilters(
      {String? location, DateTime? startDate, DateTime? endDate}) {
    setState(() {
      _filteredReports = _reports.where((report) {
        bool matchesLocation = location == null || report.location == location;
        bool matchesDate =
            (startDate == null || report.date!.isAfter(startDate)) &&
                (endDate == null || report.date!.isBefore(endDate));
        return matchesLocation && matchesDate;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CustomNavBarCurved(),
      appBar: AppBar(
        title: Text(
          "Reports Feed",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              // Add filter functionality
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) {
                _filterReports(value);
              },
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search issues...",
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Reports List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage))
                    : _filteredReports.isEmpty
                        ? Center(child: Text("No issues found"))
                        : Padding(
                            padding:
                                const EdgeInsets.all(12.0), // Add padding here
                            child: ListView.builder(
                              itemCount: (_currentPage * _reportsPerPage <
                                      _filteredReports.length)
                                  ? _currentPage * _reportsPerPage
                                  : _filteredReports.length,
                              itemBuilder: (context, index) {
                                if (index ==
                                        _currentPage * _reportsPerPage - 1 &&
                                    _currentPage * _reportsPerPage <
                                        _filteredReports.length) {
                                  _currentPage++;
                                }
                                final report = _filteredReports[index];
                                return IssueCard(
                                  reporterName:
                                      report.reporterName ?? 'Unknown',
                                  date: report.date.toString(),
                                  profileImage:
                                      'https://vlkfmraxbpwctukymsyt.supabase.co/storage/v1/object/public/${report.profilePicture}', // Add profile image if available
                                  issueImages: report.mediaRefrence,
                                  title: report.title ?? "No Title",
                                  description:
                                      report.description ?? "No Description",
                                  location: report.location ?? "No Location",
                                  status: '', // Add status if available
                                  latitude: double.parse(report.location!
                                      .split(',')[0]), // Add latitude
                                  longitude: double.parse(report.location!
                                      .split(',')[1]), // Add longitude
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // Filter Dialog
  void _showFilterDialog() {
    String? selectedLocation;
    DateTime? selectedStartDate;
    DateTime? selectedEndDate;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Filter Issues", style: GoogleFonts.poppins()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add filter options here
              FilterChip(
                label: Text("Resolved"),
                onSelected: (bool value) {
                  setState(() {
                    _filteredReports = _reports
                        .where((report) => report.status == "Resolved")
                        .toList();
                  });
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: 8),
              FilterChip(
                label: Text("Pending"),
                onSelected: (bool value) {
                  setState(() {
                    _filteredReports = _reports
                        .where((report) => report.status == "Pending")
                        .toList();
                  });
                  Navigator.pop(context);
                },
              ),
              TextField(
                decoration: InputDecoration(labelText: "Location"),
                onChanged: (value) {
                  selectedLocation = value;
                },
              ),
              SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(labelText: "Start Date"),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    selectedStartDate = pickedDate;
                  }
                },
              ),
              SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(labelText: "End Date"),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    selectedEndDate = pickedDate;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel", style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                _applyAdvancedFilters(
                  location: selectedLocation,
                  startDate: selectedStartDate,
                  endDate: selectedEndDate,
                );
                Navigator.pop(context);
              },
              child: Text("Apply", style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }
}
