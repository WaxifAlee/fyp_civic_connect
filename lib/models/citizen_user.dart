/// Citizen profile fields mapped by the user service to the existing schema.
class CitizenUser {
  CitizenUser(
      {required this.uid,
      required this.fullName,
      required this.email,
      required this.location,
      required this.phone,
      required this.displayPicture,
      required this.cnic,
      required this.gender,
      required this.joinDate});
  String? uid;
  String? fullName;
  String? email;
  String? location;
  String? phone;
  String? displayPicture;
  String? cnic;
  String? gender;
  String? joinDate;
}
