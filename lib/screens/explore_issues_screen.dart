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
  bool _sortByPopularity = false;

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

  void _applyAdvancedFilters({String? category, String? status}) {
    setState(() {
      _filteredReports = _reports.where((report) {
        bool matchesCategory = category == null || report.category == category;
        bool matchesStatus = status == null || report.status == status;
        return matchesCategory && matchesStatus;
      }).toList();

      // Sort by upvotes if popularity sort is enabled
      if (_sortByPopularity) {
        _filteredReports
            .sort((a, b) => (b.upvotes ?? 0).compareTo(a.upvotes ?? 0));
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _filteredReports = _reports;
    });
  }

  void _toggleSortByPopularity(bool value) {
    setState(() {
      _sortByPopularity = value;
      if (_sortByPopularity) {
        _filteredReports
            .sort((a, b) => (b.upvotes ?? 0).compareTo(a.upvotes ?? 0));
      } else {
        _fetchReports(); // Reset to default order
      }
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
                                double? latitude;
                                double? longitude;
                                if (report.location != null &&
                                    report.location!.contains(',')) {
                                  try {
                                    latitude = double.parse(
                                        report.location!.split(',')[0]);
                                    longitude = double.parse(
                                        report.location!.split(',')[1]);
                                  } catch (e) {
                                    // Handle parsing error
                                    latitude = null;
                                    longitude = null;
                                  }
                                }
                                return IssueCard(
                                  category: report.category ?? "No Category",
                                  upvotes: report.upvotes ?? 0,
                                  id: report.id ?? "No ID",
                                  reporterName:
                                      report.reporterName ?? 'Unknown',
                                  date: report.date.toString(),
                                  profileImage: report.profilePicture != null &&
                                          report.profilePicture != ''
                                      ? 'https://vlkfmraxbpwctukymsyt.supabase.co/storage/v1/object/public/${report.profilePicture}'
                                      : "https://ui-avatars.com/api/?name=${report.reporterName}&background=0D8ABC&color=fff&size=128", // Add profile image if available
                                  issueImages: report.mediaRefrence,
                                  title: report.title ?? "No Title",
                                  description:
                                      report.description ?? "No Description",
                                  location: report.location ?? "No Location",
                                  status: report.status ?? "No Status",
                                  latitude: latitude ?? 0.0,
                                  longitude: longitude ?? 0.0,
                                  upvotedBy: report.upvotedBy ?? [],
                                  onUpvote: () async {
                                    await _reportService
                                        .toggleUpvote(report.id!);
                                    print(
                                        "Upvoted report with ID: ${report.id}");
                                    setState(() {
                                      _fetchReports(); // Refresh the entire list after upvote
                                    });
                                  },
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
    String? selectedCategory;
    String? selectedStatus;
    bool sortByPopularity = _sortByPopularity;
    List<String> categories = _reports
        .map((report) => report.category ?? "No Category")
        .toSet()
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Filter Issues", style: GoogleFonts.poppins()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Add sort by popularity switch
                  SwitchListTile(
                    title: Text("Sort by Popularity",
                        style: GoogleFonts.poppins()),
                    value: sortByPopularity,
                    onChanged: (bool value) {
                      setState(() {
                        sortByPopularity = value;
                      });
                    },
                  ),
                  // ...existing dropdown buttons code...
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
                    _toggleSortByPopularity(sortByPopularity);
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
                    _toggleSortByPopularity(false);
                    Navigator.pop(context);
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
