import 'package:fyp_civic_connect/models/custom_location.dart';

class Report {
  String? category;
  String? description;
  Customlocation? location;
  String? mediaRefrence;
  String? reportedBy;
  String? title;

  Report(
      {required this.category,
      required this.description,
      required this.location,
      required this.mediaRefrence,
      required this.reportedBy,
      required this.title});
}
