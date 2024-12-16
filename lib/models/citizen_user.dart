import 'custom_location.dart';

class CitizenUser {
  // Private members
  String? _uid;
  String? _fullName;
  String? _email;
  String? _location;
  String? _phone;

  // Constructor
  CitizenUser({
    required String? uid,
    required String? fullName,
    required String? email,
    required String? location,
    String? phone,
  }) {
    _uid = uid;
    _fullName = fullName;
    _email = email;
    _location = location;
    _phone = phone;
  }

  // Getters
  String? get uid => _uid;
  String? get fullName => _fullName;
  String? get email => _email;
  String? get location => _location;
  String? get phone => _phone;

  // Setters
  set uid(String? value) => _uid = value;
  set fullName(String? value) => _fullName = value;
  set email(String? value) => _email = value;
  set location(String? value) => _location = value;
  set phone(String? value) => _phone = value;
}
