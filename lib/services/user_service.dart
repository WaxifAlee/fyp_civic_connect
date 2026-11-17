import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/citizen_user.dart';

/// Current authenticated citizen profile. Preview profiles never enter this cache.
CitizenUser? globalCitizenUser;

Future<void> fetchAndSetCitizenUser(String userId) async {
  final snapshot =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final data = snapshot.data();
  if (data == null) {
    throw StateError('Your citizen profile could not be found.');
  }
  final rawDate = data['created_at'];
  final date = rawDate is Timestamp
      ? rawDate.toDate()
      : DateTime.tryParse(rawDate?.toString() ?? '');
  String? text(String field) =>
      data[field] is String ? data[field] as String : null;
  globalCitizenUser = CitizenUser(
    uid: text('uid') ?? userId,
    fullName: text('full_name'),
    email: text('email'),
    location: text('locations'),
    phone: text('phone'),
    displayPicture: text('profile_picture'),
    cnic: text('cnic'),
    gender: text('gender'),
    joinDate: date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
  );
}
