import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_civic_connect/models/citizen_user.dart'; // Adjust the path as needed
// Adjust the path as needed

// Global variable to store the logged-in user's data
CitizenUser? globalCitizenUser;

Future<void> fetchAndSetCitizenUser(String userId) async {
  try {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('users') // Replace with your Firestore collection name
        .doc(userId)
        .get();

    if (snapshot.exists) {
      Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
      globalCitizenUser = CitizenUser(
        uid: userData['uid'],
        fullName: userData['full_name'],
        email: userData['email'],
        location: userData['locations'],
        phone: userData['phone'],
      );
    } else {
      throw Exception('User data does not exist.');
    }
  } catch (e) {
    print('Error in fetchAndSetCitizenUser: $e');
    rethrow; // Let the calling function handle this error
  }
}
