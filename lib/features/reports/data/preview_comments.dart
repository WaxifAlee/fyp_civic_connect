import '../domain/report_comment.dart';

/// Demo discussions are session-local and never touch Supabase.
abstract final class PreviewComments {
  static final Map<String, List<ReportComment>> _items = {};
  static final Set<String> _removed = {};
  static List<ReportComment> items(String id) => _items[id] ?? const [];
  static ReportComment add(String id, String body, String requestId) {
    if (_removed.contains(requestId)) {
      throw const CommentsException(
          'This comment was removed. Write a new comment to continue.');
    }
    for (final list in _items.values) {
      for (final item in list) {
        if (item.id == requestId) {
          if (item.reportId != id || item.body != body) {
            throw const CommentsException(
                'This request has already been used. Review your comment.');
          }
          return item;
        }
      }
    }
    final item = ReportComment(
        id: requestId,
        reportId: id,
        body: body,
        authorName: 'Demo citizen',
        timestamp: DateTime.now().toUtc().toIso8601String(),
        isMine: true);
    (_items[id] ??= []).insert(0, item);
    return item;
  }

  static void remove(String id, String commentId) {
    _items[id]?.removeWhere((c) => c.id == commentId);
    _removed.add(commentId);
  }
}
