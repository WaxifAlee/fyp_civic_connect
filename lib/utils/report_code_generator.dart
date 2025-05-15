import 'package:cloud_firestore/cloud_firestore.dart';

class ReportCodeGenerator {
  static Map<String, String> categoryToPrefix = {
    'Municipal Corportaion': 'MC',
    'Police Department': 'PD',
    'Fire & Emergency Services': 'FE',
    'Electricity & Gas Department': 'EG',
    'Public Works Department (PWD)': 'PW',
  };

  static Future<String> generateReportCode(String category) async {
    final firestore = FirebaseFirestore.instance;
    final String prefix = categoryToPrefix[category] ?? 'OT'; // OT for Others

    try {
      // Use a transaction to ensure atomicity
      String reportCode =
          await firestore.runTransaction<String>((transaction) async {
        // Get the counter document for this category
        final counterRef = firestore.collection('report_counters').doc(prefix);
        final counterDoc = await transaction.get(counterRef);

        // Get the current counter value or start from 0
        final data = counterDoc.data();
        final int currentCounter =
            data != null ? (data['counter'] as int? ?? 0) : 0;
        int newCounter = currentCounter + 1;

        // Update the counter atomically
        transaction.set(
            counterRef, {'counter': newCounter}, SetOptions(merge: true));

        // Format the report code with leading zeros
        String formattedNumber = newCounter.toString().padLeft(5, '0');
        return '$prefix$formattedNumber';
      });

      return reportCode;
    } catch (e) {
      print('Error generating report code: $e');
      // Generate a fallback code using timestamp to ensure uniqueness
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      return '$prefix${timestamp.substring(timestamp.length - 5)}';
    }
  }
}
