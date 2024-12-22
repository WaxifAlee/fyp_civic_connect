import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_civic_connect/models/report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch all reports from Firestore
  Future<List<Report>> fetchAllReports() async {
    try {
      QuerySnapshot querySnapshot =
          await _firestore.collection('reports').get();
      return await Future.wait(querySnapshot.docs.map((doc) async {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        return Report(
            id: doc.id,
            category: data['category'],
            description: data['description'],
            location: data['location'],
            mediaRefrence: List<String>.from(data['images']),
            reportedBy: data['reporterId'],
            title: data['title'],
            status: data['status'],
            profilePicture: data['avatar'],
            reporterName: data['reporterName'],
            date: (data['timestamp'] as Timestamp).toDate().toLocal());
      }).toList());
    } catch (e) {
      print('Error fetching reports: $e');
      return [];
    }
  }

  // Fetch reports reported by the current user
  Future<List<Report>> fetchReportsByCurrentUser() async {
    try {
      firebase_auth.User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No user is currently signed in.');
        return [];
      }

      QuerySnapshot querySnapshot = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: currentUser.uid)
          .get();
      return await Future.wait(querySnapshot.docs.map((doc) async {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        return Report(
            id: doc.id,
            category: data['category'],
            description: data['description'],
            location: data['location'],
            mediaRefrence: List<String>.from(data['images']),
            reportedBy: data['reporterId'],
            title: data['title'],
            status: data['status'],
            profilePicture: data['avatar'],
            reporterName: data['reporterName'],
            date: (data['timestamp'] as Timestamp).toDate().toLocal());
      }).toList());
    } catch (e) {
      print('Error fetching reports by current user: $e');
      return [];
    }
  }

  Future<void> deleteReport(String reportId, List<String> imagePaths) async {
    try {
      // Delete images from Supabase bucket
      final client = Supabase.instance.client;
      for (String path in imagePaths) {
        final _path = "public/${path.split('/')[9]}";
        await client.storage.from('reports-images').remove([_path]);
      }

      // Delete report from Firestore
      await _firestore.collection('reports').doc(reportId).delete();
    } catch (e) {
      print('Error deleting report: $e');
      throw e;
    }
  }
}
