class ReportProgress {
  const ReportProgress(
      {required this.id,
      required this.fromStatus,
      required this.toStatus,
      required this.note,
      required this.createdAt,
      required this.version});
  final String id;
  final String fromStatus;
  final String toStatus;
  final String note;
  final DateTime createdAt;
  final int version;
  factory ReportProgress.fromMap(Map<String, dynamic> map) {
    final date = DateTime.tryParse(map['createdAt']?.toString() ?? '');
    if (map['id'] is! String ||
        map['note'] is! String ||
        map['fromStatus'] is! String ||
        map['toStatus'] is! String ||
        map['version'] is! int ||
        date == null) {
      throw const FormatException('Invalid progress response');
    }
    return ReportProgress(
        id: map['id'],
        fromStatus: map['fromStatus'],
        toStatus: map['toStatus'],
        note: map['note'],
        createdAt: date,
        version: map['version']);
  }
}
