import 'dart:core';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/report_id_generator.dart';

class ReportService {
  // Add a method to get the next sequence number
  Future<int> _getNextSequenceNumber() async {
    try {
      // Get the reports collection ordered by reportNumber in descending order
      final QuerySnapshot snapshot = await _firestore
          .collection('reports')
          .orderBy('reportNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 1; // Start with 1 if no reports exist
      }

      // Extract the number part from the last report number
      final String lastReportNumber =
          snapshot.docs.first['reportNumber'] ?? 'XX00000';
      final String numberPart =
          lastReportNumber.substring(2); // Get last 5 digits
      return int.parse(numberPart) + 1;
    } catch (e) {
      print('Error getting next sequence number: $e');
      return 1; // Return 1 as fallback
    }
  }

  // Add a method to generate the next report number
  Future<String> generateReportNumber(String category) async {
    final int nextNumber = await _getNextSequenceNumber();
    return ReportIdGenerator.generateReportId(category, nextNumber);
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Fetch all reports from Firestore
  Future<List<Report>> fetchAllReports() async {
    try {
      // Get all reports ordered by date
      QuerySnapshot querySnapshot = await _firestore
          .collection('reports')
          .orderBy('date', descending: true)
          .get();

      List<Report> reports = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Convert the Timestamp to DateTime safely
          DateTime? date;
          try {
            var timestamp = data['timestamp'];
            if (timestamp is Timestamp) {
              date = timestamp.toDate().toLocal();
            } else {
              date = DateTime.now(); // Fallback to current time
            }
          } catch (e) {
            print('Error parsing date for report ${doc.id}: $e');
            date = DateTime.now(); // Fallback to current time
          }

          // Handle media references safely
          List<String> mediaRefs = [];
          try {
            var images = data['images'];
            if (images != null) {
              mediaRefs = List<String>.from(images);
            }
          } catch (e) {
            print('Error parsing media references for report ${doc.id}: $e');
          }

          // Handle upvotedBy list safely
          List<String> upvotedBy = [];
          try {
            var upvotes = data['upvotedBy'];
            if (upvotes != null) {
              upvotedBy = List<String>.from(upvotes);
            }
          } catch (e) {
            print('Error parsing upvotedBy for report ${doc.id}: $e');
          }

          reports.add(Report(
            upvotes: data['upvotes'] ?? 0,
            upvotedBy: upvotedBy,
            id: doc.id,
            reportNumber: data['reportNumber'],
            category: data['category'] ?? 'Uncategorized',
            description: data['description'] ?? 'No description provided',
            location: data['location'] ?? 'Location not specified',
            mediaRefrence: mediaRefs,
            reportedBy: data['reporterId'] ?? 'Unknown',
            title: data['title'] ?? 'Untitled Report',
            status: data['status'] ?? 'pending',
            profilePicture: data['avatar'] ?? '',
            reporterName: data['reporterName'] ?? 'Anonymous',
            date: date,
          ));
        } catch (e) {
          print('Error parsing report ${doc.id}: $e');
          // Continue to next report instead of failing the entire fetch
          continue;
        }
      }

      return reports;
    } catch (e) {
      print('Error fetching reports: $e');
      throw Exception('Failed to load reports. Please check your connection and try again.');
    }
  }
  // Fetch reports reported by the current user
  Future<List<Report>> fetchReportsByCurrentUser() async {
    try {
      // Check user authentication
      firebase_auth.User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Please sign in to view your reports.');
      }

      // Get user's reports ordered by date
      QuerySnapshot querySnapshot = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: currentUser.uid)
          .orderBy('date', descending: true)
          .get();

      List<Report> reports = [];

      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Handle date conversion safely
          DateTime? date;
          try {
            var timestamp = data['timestamp'];
            if (timestamp is Timestamp) {
              date = timestamp.toDate().toLocal();
            } else {
              date = DateTime.now();
            }
          } catch (e) {
            print('Error parsing date for report ${doc.id}: $e');
            date = DateTime.now();
          }

          // Handle media references safely
          List<String> mediaRefs = [];
          try {
            if (data['images'] != null) {
              mediaRefs = List<String>.from(data['images']);
            }
          } catch (e) {
            print('Error parsing media references for report ${doc.id}: $e');
          }

          // Handle upvotedBy list safely
          List<String> upvotedBy = [];
          try {
            if (data['upvotedBy'] != null) {
              upvotedBy = List<String>.from(data['upvotedBy']);
            }
          } catch (e) {
            print('Error parsing upvotedBy for report ${doc.id}: $e');
          }

          reports.add(Report(
            id: doc.id,
            reportNumber: data['reportNumber'],
            category: data['category'] ?? 'Uncategorized',
            description: data['description'] ?? 'No description provided',
            location: data['location'] ?? 'Location not specified',
            mediaRefrence: mediaRefs,
            reportedBy: data['reporterId'] ?? currentUser.uid,
            title: data['title'] ?? 'Untitled Report',
            status: data['status'] ?? 'pending',
            profilePicture: data['avatar'] ?? '',
            reporterName: data['reporterName'] ?? 'Anonymous',
            date: date,
            upvotes: data['upvotes'] ?? 0,
            upvotedBy: upvotedBy,
          ));
        } catch (e) {
          print('Error parsing report ${doc.id}: $e');
          // Continue to next report instead of failing the entire fetch
          continue;
        }
      }

      return reports;
    } catch (e) {
      print('Error fetching reports by current user: $e');
      return [];
    }
  }
  Future<void> deleteReport(String reportId, List<String> imagePaths) async {
    try {
      // Verify user authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please sign in to delete reports.');
      }

      // Check if report exists and belongs to the current user
      final reportDoc = await _firestore.collection('reports').doc(reportId).get();
      if (!reportDoc.exists) {
        throw Exception('Report not found.');
      }

      final reportData = reportDoc.data();
      if (reportData == null || reportData['reportedBy'] != user.uid) {
        throw Exception('You do not have permission to delete this report.');
      }

      // Delete images from Supabase bucket
      final client = Supabase.instance.client;
      final failedDeletes = <String>[];

      for (String path in imagePaths) {
        try {
          if (path.isEmpty) continue;

          final _path = path.split('/').lastWhere(
            (element) => element.isNotEmpty,
            orElse: () => '',
          );

          if (_path.isEmpty) continue;

          await client.storage.from('reports-images').remove(['public/$_path']);
        } catch (e) {
          print('Error deleting image $path: $e');
          failedDeletes.add(path);
        }
      }

      // Delete report from Firestore
      await _firestore.collection('reports').doc(reportId).delete();

      // If any images failed to delete, log it but don't fail the operation
      if (failedDeletes.isNotEmpty) {
        print('Warning: Failed to delete some images: ${failedDeletes.join(", ")}');
      }
    } catch (e) {
      print('Error deleting report: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to delete report: $e');
    }
  }
  Future<void> toggleUpvote(String reportId) async {
    try {
      // Check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please sign in to upvote reports.');
      }

      final reportRef =
          FirebaseFirestore.instance.collection('reports').doc(reportId);

      return FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get report document
        final reportDoc = await transaction.get(reportRef);

        // Check if report exists
        if (!reportDoc.exists) {
          throw Exception('Report not found.');
        }

        // Get current upvote data with null safety
        final reportData = reportDoc.data();
        if (reportData == null) {
          throw Exception('Report data is corrupted.');
        }

        List<String> upvotedBy =
            List<String>.from(reportData['upvotedBy'] ?? []);
        int currentUpvotes = reportData['upvotes'] ?? 0;

        // Validate upvotes consistency
        if (upvotedBy.length != currentUpvotes) {
          // Fix the inconsistency
          currentUpvotes = upvotedBy.length;
        }

        if (upvotedBy.contains(user.uid)) {
          // Remove upvote
          upvotedBy.remove(user.uid);
          currentUpvotes = math.max(0, currentUpvotes - 1); // Ensure non-negative
        } else {
          // Add upvote
          if (!upvotedBy.contains(user.uid)) { // Double-check to prevent duplicates
            upvotedBy.add(user.uid);
            currentUpvotes++;
          }
        }

        // Update the document with new values
        transaction.update(reportRef, {
          'upvotedBy': upvotedBy,
          'upvotes': currentUpvotes,
          'lastUpdated': FieldValue.serverTimestamp(), // Track last update
        });
      });
    } catch (e) {
      print('Error in toggleUpvote: $e');
      rethrow; // Let the UI handle the error
    }
  }
}
