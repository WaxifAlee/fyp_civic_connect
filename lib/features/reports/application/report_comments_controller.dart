import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/report_comments_service.dart';

class ReportCommentsController extends ChangeNotifier {
  ReportCommentsController(
      {required this.reportId, ReportCommentsService? service})
      : service = service ?? ReportCommentsService() {
    _session = this.service.sessionId;
  }
  final String reportId;
  final ReportCommentsService service;
  String? _session, _requestId;
  ReportComment? _cursor;
  List<ReportComment> _comments = [];
  List<ReportComment> get comments => List.unmodifiable(_comments);
  String draft = '';
  String? error, notice, pendingRemoval;
  bool loading = false, loadingMore = false, busy = false, uncertain = false;
  bool blocked = false, ready = false, hasMore = false, _disposed = false;
  bool get canEdit => !blocked && !busy && !uncertain && pendingRemoval == null;
  bool get canRefresh =>
      !busy &&
      !loading &&
      !loadingMore &&
      !uncertain &&
      pendingRemoval == null &&
      !blocked;
  bool get canPost =>
      ready &&
      !blocked &&
      !busy &&
      !loading &&
      !loadingMore &&
      pendingRemoval == null &&
      (uncertain ||
          (draft.trim().isNotEmpty && draft.trim().runes.length <= 1000));
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _guard() {
    if (_disposed) return false;
    if (_session == null || service.sessionId != _session) {
      blocked = true;
      ready = false;
      _comments = [];
      error = 'Your session changed. Close this report and sign in again.';
      _emit();
      return false;
    }
    return true;
  }

  void updateDraft(String value) {
    if (!canEdit) return;
    draft = value;
    _requestId = null;
    notice = null;
    _emit();
  }

  void _failure(CommentsException e) {
    error = e.message;
    if (e.forbidden) {
      blocked = true;
      ready = false;
      _comments = [];
    }
  }

  Future<void> load({bool older = false}) async {
    if (!canRefresh || !_guard() || (older && !hasMore)) return;
    loading = !older;
    loadingMore = older;
    error = null;
    _emit();
    try {
      final page = await service.list(reportId, before: older ? _cursor : null);
      if (!_guard()) return;
      final merged = <String, ReportComment>{
        if (older)
          for (final c in _comments) c.id: c
      };
      for (final c in page.comments) {
        merged[c.id] = c;
      }
      _comments = merged.values.toList();
      _cursor = page.comments.isNotEmpty ? page.comments.last : _cursor;
      hasMore = page.hasMore;
      ready = true;
    } on CommentsException catch (e) {
      if (_guard()) _failure(e);
    } finally {
      loading = false;
      loadingMore = false;
      _emit();
    }
  }

  Future<void> post() async {
    if (!_guard() || !canPost) return;
    _requestId ??= const Uuid().v4();
    busy = true;
    error = null;
    notice = null;
    _emit();
    try {
      final item = await service.add(reportId, draft, _requestId!);
      if (!_guard()) return;
      _comments = [item, ..._comments.where((c) => c.id != item.id)];
      draft = '';
      _requestId = null;
      uncertain = false;
      notice = service.isPreview
          ? 'Demo comment added in this session.'
          : 'Comment posted.';
    } on CommentsException catch (e) {
      if (!_guard()) return;
      _failure(e);
      uncertain = e.uncertain;
      if (!uncertain) _requestId = null;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> remove(ReportComment item) async {
    if (!_guard() ||
        busy ||
        loading ||
        loadingMore ||
        blocked ||
        uncertain ||
        !item.isMine ||
        (pendingRemoval != null && pendingRemoval != item.id)) {
      return;
    }
    busy = true;
    error = null;
    notice = null;
    _emit();
    try {
      await service.remove(reportId, item.id);
      if (!_guard()) return;
      _comments.removeWhere((c) => c.id == item.id);
      pendingRemoval = null;
      notice = 'Comment removed.';
    } on CommentsException catch (e) {
      if (!_guard()) return;
      _failure(e);
      pendingRemoval = e.uncertain ? item.id : null;
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
