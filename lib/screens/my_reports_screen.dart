import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';
import 'package:fyp_civic_connect/widgets/issue_card.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:google_fonts/google_fonts.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  _MyReportsScreenState createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
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
      List<Report> reports = await _reportService.fetchReportsByCurrentUser();
      setState(() {
        _reports = reports;
        _filteredReports = reports;
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

  void _applyAdvancedFilters({String? category, String? status}) {
    setState(() {
      _filteredReports = _reports.where((report) {
        bool matchesCategory = category == null || report.category == category;
        bool matchesStatus = status == null || report.status == status;
        return matchesCategory && matchesStatus;
      }).toList();
    });
  }

  Future<void> _deleteReport(String reportId, List<String> imagePaths) async {
    try {
      await _reportService.deleteReport(reportId, imagePaths);
      setState(() {
        _reports.removeWhere((report) => report.id == reportId);
        _filteredReports.removeWhere((report) => report.id == reportId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report deleted successfully!'),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete report. Please try again.'),
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog(String reportId, List<String> imagePaths) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete Report", style: GoogleFonts.poppins()),
          content: Text("Are you sure you want to delete this report?",
              style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel", style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteReport(reportId, imagePaths);
              },
              child: Text("Delete", style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CustomNavBarCurved(),
      appBar: AppBar(
        title: Text(
          "Your Reports",
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
                                const EdgeInsets.all(20.0), // Add padding here
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
                                return Dismissible(
                                  key: Key(report.id!),
                                  background: Container(color: Colors.red),
                                  onDismissed: (direction) {
                                    _showDeleteConfirmationDialog(
                                        report.id!, report.mediaRefrence);
                                  },
                                  child: GestureDetector(
                                    child: IssueCard(
                                      id: report.id ?? "No ID",
                                      category:
                                          report.category ?? "No Category",
                                      upvotes: report.upvotes ?? 0,
                                      reporterName:
                                          report.reporterName ?? 'Unknown',
                                      date: report.date.toString(),
                                      profileImage: report.profilePicture !=
                                                  null &&
                                              report.profilePicture != ''
                                          ? 'https://vlkfmraxbpwctukymsyt.supabase.co/storage/v1/object/public/${report.profilePicture}'
                                          : "https://ui-avatars.com/api/?name=${report.reporterName}&background=0D8ABC&color=fff&size=128", // Add profile image if available
                                      issueImages: report.mediaRefrence,
                                      title: report.title ?? "No Title",
                                      description: report.description ??
                                          "No Description",
                                      location:
                                          report.location ?? "No Location",
                                      status: report.status ??
                                          "No Status", // Add status if available
                                      latitude: double.parse(report.location!
                                          .split(',')[0]), // Add latitude
                                      longitude: double.parse(report.location!
                                          .split(',')[1]), // Add longitude

                                      onUpvote: () async {
                                        await _reportService
                                            .toggleUpvote(report.id!);
                                        _fetchReports();
                                      },
                                    ),
                                  ),
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
  void _clearFilters() {
    setState(() {
      _filteredReports = _reports;
    });
  }

  void _showFilterDialog() {
    String? selectedCategory;
    String? selectedStatus;
    List<String> categories = _reports
        .map((report) => report.category ?? "No Category")
        .toSet()
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Filter Issues", style: GoogleFonts.poppins()),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Add filter options here
                  DropdownButton<String>(
                    value: selectedStatus,
                    hint: Text("Select Status"),
                    items: ["Solved", "Pending"].map((String status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedStatus = newValue;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedCategory,
                    hint: Text("Select Category"),
                    items: categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCategory = newValue;
                      });
                    },
                  ),
                ],
              );
            },
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
                  category: selectedCategory,
                  status: selectedStatus?.toLowerCase(),
                );
                Navigator.pop(context);
              },
              child: Text("Apply", style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                _clearFilters();
                Navigator.pop(context);
              },
              child: Text("Clear Filters", style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }
}
