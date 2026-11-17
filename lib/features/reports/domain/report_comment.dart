/// Public discussion data deliberately excludes account/contact identifiers.
class ReportComment {
  const ReportComment(
      {required this.id,
      required this.reportId,
      required this.body,
      required this.authorName,
      required this.timestamp,
      required this.isMine});
  final String id, reportId, body, authorName;
  // Keep PostgreSQL's full cursor precision, including on Flutter web.
  final String timestamp;
  final bool isMine;
  DateTime get createdAt => DateTime.parse(timestamp);

  factory ReportComment.fromMap(Map<String, dynamic> map) {
    for (final key in ['id', 'reportId', 'body', 'authorName', 'createdAt']) {
      if (map[key] is! String || (map[key] as String).isEmpty) {
        throw const FormatException('Incomplete comment');
      }
    }
    final body = map['body'] as String;
    if (map['isMine'] is! bool ||
        DateTime.tryParse(map['createdAt']) == null ||
        body != body.trim() ||
        body.runes.length > 1000) {
      throw const FormatException('Invalid comment');
    }
    return ReportComment(
        id: map['id'],
        reportId: map['reportId'],
        body: body,
        authorName: map['authorName'],
        timestamp: map['createdAt'],
        isMine: map['isMine']);
  }
}

class CommentsPage {
  const CommentsPage({required this.comments, required this.hasMore});
  final List<ReportComment> comments;
  final bool hasMore;
}

class CommentsException implements Exception {
  const CommentsException(this.message,
      {this.forbidden = false, this.uncertain = false});
  final String message;
  final bool forbidden, uncertain;
  @override
  String toString() => message;
}
