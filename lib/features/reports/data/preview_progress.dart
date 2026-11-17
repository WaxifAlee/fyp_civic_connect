import '../domain/report_progress.dart';

/// Public demo updates are session-local and never sent to a server.
abstract final class PreviewProgress {
  static final Map<String, List<ReportProgress>> _history = {};
  static List<ReportProgress> history(String id) =>
      List.unmodifiable(_history[id] ?? []);
  static void add(String id, ReportProgress item) =>
      (_history[id] ??= []).insert(0, item);
}
