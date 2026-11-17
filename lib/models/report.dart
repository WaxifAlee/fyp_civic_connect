import 'package:cloud_firestore/cloud_firestore.dart';

/// The vote state returned by the committed Firestore transaction.
class ReportVote {
  const ReportVote({required this.count, required this.voters});
  final int count;
  final List<String> voters;
}

/// The persisted report contract, including aliases from earlier app versions.
class Report {
  final String? category;
  final String? description;
  final String? location;
  final List<String> mediaRefrence;
  final String? title;
  final String? reportedBy;
  final String? reporterName;
  final String? status;
  final String? profilePicture;
  final DateTime? date;
  final String? id;
  final String? reportCode;
  int? upvotes;
  List<String>? upvotedBy;

  Report(
      {this.category,
      this.description,
      this.location,
      this.mediaRefrence = const [],
      this.reportedBy,
      this.title,
      this.status,
      this.profilePicture,
      this.reporterName,
      this.date,
      this.id,
      this.reportCode,
      this.upvotedBy,
      this.upvotes = 0});

  factory Report.fromMap(Map<String, dynamic> map) {
    final rawDate = map['timestamp'] ?? map['date'];
    return Report(
      category: _string(map['category']),
      description: _string(map['description']),
      location: _string(map['location']),
      title: _string(map['title']),
      mediaRefrence: _strings(map['images'] ?? map['mediaRefrence']),
      reportedBy: _string(map['reporterId'] ?? map['reportedBy']),
      status: _string(map['status']),
      profilePicture: _string(map['avatar'] ?? map['profilePicture']),
      reporterName: _string(map['reporterName']),
      id: _string(map['id']),
      reportCode: _string(map['reportCode']),
      date: rawDate is Timestamp
          ? rawDate.toDate()
          : rawDate is DateTime
              ? rawDate
              : DateTime.tryParse(rawDate?.toString() ?? ''),
      upvotedBy: _strings(map['upvotedBy']),
      upvotes: map['upvotes'] is num
          ? (map['upvotes'] as num).toInt().clamp(0, 1 << 31)
          : 0,
    );
  }

  static String? _string(dynamic value) => value is String ? value : null;
  static List<String> _strings(dynamic value) => value is Iterable
      ? value.whereType<String>().where((s) => s.isNotEmpty).toList()
      : [];

  Map<String, dynamic> toMap() => {
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
        'reportCode': reportCode,
        'upvotedBy': upvotedBy ?? [],
        'upvotes': upvotes ?? 0,
      };
}
