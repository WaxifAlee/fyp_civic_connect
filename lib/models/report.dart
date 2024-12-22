class Report {
  final String? category;
  final String? description;
  final String? location;
  final List<String> mediaRefrence;
  final String? title;
  final String? reportedBy;
  final String? reporterName; // Ensure reporterName is included
  final String? status; // Ensure status is included
  final String? profilePicture;
  final DateTime? date;
  final String? id;

  Report(
      {required this.category,
      required this.description,
      required this.location,
      required this.mediaRefrence,
      required this.reportedBy,
      required this.title,
      required this.status, // Ensure status is included
      required this.profilePicture,
      required this.reporterName,
      required this.date, // Ensure reporterName is included
      required this.id});
}
