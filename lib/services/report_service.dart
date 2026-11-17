import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'storage_paths.dart';

/// Firebase-backed report operations. Failures remain visible to the caller.
class ReportService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<List<Report>> fetchAllReports(
      {String? category, String? status, bool sortByPopularity = false}) async {
    Query<Map<String, dynamic>> query = _firestore.collection('reports');
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    final snapshot = await query
        .orderBy(sortByPopularity ? 'upvotes' : 'timestamp', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Report.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<Report>> fetchReportsByCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to view your reports.');
    final snapshot = await _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: user.uid)
        .get();
    return snapshot.docs
        .map((doc) => Report.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<void> deleteReport(String reportId, List<String> imagePaths) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to manage your reports.');
    final reference = _firestore.collection('reports').doc(reportId);
    final snapshot = await reference.get();
    if (snapshot.data()?['reporterId'] != user.uid) {
      throw StateError('Only the reporter can remove this report.');
    }
    await reference.delete();
    // Deleting the record first keeps an unsuccessful delete from losing photos.
    if (!SupabaseService.isConfigured) return;
    try {
      final paths = reportImageStoragePaths(imagePaths, SupabaseService.url);
      if (paths.isEmpty) return;
      await Supabase.instance.client.storage
          .from('reports-images')
          .remove(paths);
    } catch (error) {
      debugPrint(
          'Report removed; storage cleanup needs retry: ${error.runtimeType}');
    }
  }

  Future<ReportVote> toggleUpvote(String reportId) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to support a report.');
    final reference = _firestore.collection('reports').doc(reportId);
    return _firestore.runTransaction<ReportVote>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('This report is no longer available.');
      }
      final voters = List<String>.from(snapshot.data()?['upvotedBy'] ?? []);
      final count = (snapshot.data()?['upvotes'] as num?)?.toInt() ?? 0;
      final voted = voters.contains(user.uid);
      voted ? voters.remove(user.uid) : voters.add(user.uid);
      final nextCount = (count + (voted ? -1 : 1)).clamp(0, 1 << 31);
      transaction.update(reference, {
        'upvotedBy': voters,
        'upvotes': nextCount,
      });
      return ReportVote(count: nextCount, voters: voters);
    });
  }
}
