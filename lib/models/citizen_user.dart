class CitizenUser {
  // Private members
  String? _uid;
  String? _fullName;
  String? _email;
  String? _location;
  String? _phone;
  String? _displayPicture;
  String? _cnic;
  String? _gender;
  String? _joinDate;

  // Constructor
  CitizenUser({
    required String? uid,
    required String? fullName,
    required String? email,
    required String? location,
    required String? phone,
    required String? displayPicture,
    required String? cnic,
    required String? gender,
    required String? joinDate,
  }) {
    _uid = uid;
    _fullName = fullName;
    _email = email;
    _location = location;
    _phone = phone;
    _displayPicture = displayPicture;
    _cnic = cnic;
    _gender = gender;
    _joinDate = joinDate;
  }

  // Getters
  String? get uid => _uid;
  String? get fullName => _fullName;
  String? get email => _email;
  String? get location => _location;
  String? get phone => _phone;
  String? get displayPicture => _displayPicture;
  String? get cnic => _cnic;
  String? get gender => _gender;
  String? get joinDate => _joinDate;

  // Setters
  set uid(String? value) => _uid = value;
  set fullName(String? value) => _fullName = value;
  set email(String? value) => _email = value;
  set location(String? value) => _location = value;
  set phone(String? value) => _phone = value;
  set displayPicture(String? value) => _displayPicture = value;
  set cnic(String? value) => _cnic = value;
  set gender(String? value) => _gender = value;
  set joinDate(String? value) => _joinDate = value;
}
