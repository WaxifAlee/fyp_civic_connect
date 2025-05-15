import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';
import 'package:fyp_civic_connect/widgets/issue_card.dart';
import 'package:fyp_civic_connect/services/report_service.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:google_fonts/google_fonts.dart';

class ExploreIssuesScreen extends StatefulWidget {
  const ExploreIssuesScreen({super.key});

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
        bool matchesCategory = category == null ||
            (report.category?.toLowerCase() == category.toLowerCase());
        bool matchesStatus = status == null ||
            (report.status?.toLowerCase() == status.toLowerCase());

        print('Filtering report: ${report.title}');
        print(
            'Category match: $matchesCategory (filter: $category, report: ${report.category})');
        print(
            'Status match: $matchesStatus (filter: $status, report: ${report.status})');

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
                                return Container(
                                  key: Key(report.id!),
                                  child: GestureDetector(
                                    child: IssueCard(
                                      id: report.id ?? "No ID",
                                      category:
                                          report.category ?? "No Category",
                                      upvotes: report.upvotes ?? 0,
                                      reporterName:
                                          report.reporterName ?? 'Unknown',
                                      date: report.date.toString(),
                                      reportCode: report.reportCode,
                                      profileImage: report.profilePicture !=
                                                  null &&
                                              report.profilePicture != ''
                                          ? 'https://vlkfmraxbpwctukymsyt.supabase.co/storage/v1/object/public/${report.profilePicture}'
                                          : "https://ui-avatars.com/api/?name=${report.reporterName}&background=0D8ABC&color=fff&size=128",
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

    // Define all available categories
    List<String> predefinedCategories = [
      'Municipal Corportaion',
      'Police Department',
      'Fire & Emergency Services',
      'Electricity & Gas Department',
      'Public Works Department (PWD)',
    ];

    // Combine predefined categories with any additional ones from reports
    List<String> categories = {
      ...predefinedCategories,
      ..._reports.map((report) => report.category ?? "No Category")
    }.toList()
      ..removeWhere(
          (category) => category == "No Category") // Remove empty categories
      ..sort();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return AlertDialog(
              title: Text("Filter Issues", style: GoogleFonts.poppins()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Status",
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    DropdownButton<String>(
                      value: selectedStatus,
                      hint: Text("Select Status",
                          style: GoogleFonts.poppins(fontSize: 14)),
                      isExpanded: true,
                      items: ["solved", "pending", "rejected"]
                          .map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        dialogSetState(() {
                          selectedStatus = newValue;
                          print('Selected status: $newValue');
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    Text("Category",
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    DropdownButton<String>(
                      value: selectedCategory,
                      hint: Text("Select Category",
                          style: GoogleFonts.poppins(fontSize: 14)),
                      isExpanded: true,
                      items: categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        dialogSetState(() {
                          selectedCategory = newValue;
                          print('Selected category: $newValue');
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text("Cancel", style: GoogleFonts.poppins()),
                ),
                TextButton(
                  onPressed: () {
                    _applyAdvancedFilters(
                      category: selectedCategory,
                      status: selectedStatus?.toLowerCase(),
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: Text("Apply", style: GoogleFonts.poppins()),
                ),
                TextButton(
                  onPressed: () {
                    _clearFilters();
                    Navigator.pop(dialogContext);
                  },
                  child: Text("Clear Filters", style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
