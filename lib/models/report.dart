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
  final String? reportNumber; // New field for custom report ID (e.g., MC00001)
  int? upvotes;
  List<String>? upvotedBy; // List of user IDs who upvoted

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
      required this.id,
      this.reportNumber, // Add to constructor
      this.upvotedBy,
      this.upvotes = 0});

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      category: map['category'],
      description: map['description'],
      location: map['location'],
      mediaRefrence: List<String>.from(map['mediaRefrence']),
      reportedBy: map['reportedBy'],
      title: map['title'],
      status: map['status'],
      profilePicture: map['profilePicture'],
      reporterName: map['reporterName'],
      date: DateTime.parse(map['date']),
      id: map['id'],
      reportNumber: map['reportNumber'], // Add to fromMap
      upvotedBy: List<String>.from(map['upvotedBy'] ?? []),
      upvotes: map['upvotes']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'description': description,
      'location': location,
      'mediaRefrence': mediaRefrence,
      'reportedBy': reportedBy,
      'title': title,
      'status': status,
      'profilePicture': profilePicture,
      'reporterName': reporterName,
      'date': date?.toIso8601String(),
      'id': id,
      'reportNumber': reportNumber, // Add to toMap
      'upvotedBy': upvotedBy ?? [],
      'upvotes': upvotes ?? 0,
    };
  }
}
