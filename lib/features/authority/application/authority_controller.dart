import 'package:flutter/foundation.dart';
import '../data/authority_service.dart';
import '../domain/authority_models.dart';

class AuthorityController extends ChangeNotifier {
  AuthorityController({AuthorityService? service})
      : service = service ?? AuthorityService();
  final AuthorityService service;
  AuthorityAccess? access;
  AuthorityPage? page;
  String query = '';
  String? status;
  String? category;
  String sort = 'oldest';
  int pageIndex = 0;
  bool loading = true;
  bool retainingPage = false;
  bool get refreshing => loading && retainingPage;
  bool denied = false;
  String? error;
  DateTime? lastLoaded;
  bool _disposed = false;
  int _generation = 0;
  String? _pageSession;
  (String, String?, String?, String, int)? _pageCriteria;
  (String, String?, String?, String, int) get _criteria =>
      (query, status, category, sort, pageIndex);

  Future<void> load(
      {String? query, int? pageIndex, bool retainPage = false}) async {
    if (query != null) {
      this.query = query;
      this.pageIndex = 0;
    }
    if (pageIndex != null) this.pageIndex = pageIndex;
    final generation = ++_generation;
    final uid = service.sessionId;
    retainingPage = retainPage &&
        page != null &&
        uid == _pageSession &&
        _pageCriteria == _criteria;
    loading = true;
    error = null;
    denied = false;
    _notify();
    try {
      final membership = await service.access();
      if (_disposed || generation != _generation) return;
      if (uid != service.sessionId) {
        access = null;
        page = null;
        denied = true;
        return;
      }
      final scopeChanged = access?.role != membership?.role ||
          access?.department != membership?.department;
      if (scopeChanged) {
        page = null;
        retainingPage = false;
      }
      access = membership;
      if (membership == null) {
        page = null;
        denied = true;
        return;
      }
      if (!membership.isAdmin) category = null;
      if (scopeChanged) _notify();
      final criteria = _criteria;
      final result = await service.queue(
          query: this.query,
          status: status,
          category: category,
          sort: sort,
          page: this.pageIndex);
      if (_disposed || generation != _generation) return;
      if (uid != service.sessionId) {
        access = null;
        page = null;
        denied = true;
        return;
      }
      page = result;
      _pageSession = uid;
      _pageCriteria = criteria;
      // Deletions can empty the final page between requests.
      if (this.pageIndex > 0 &&
          result.reports.isEmpty &&
          result.total <= this.pageIndex * 20) {
        this.pageIndex = result.total == 0 ? 0 : (result.total - 1) ~/ 20;
        await load();
        return;
      }
      lastLoaded = DateTime.now();
    } on AuthorityException catch (e) {
      if (_disposed || generation != _generation) return;
      error = e.message;
      if (e.forbidden || uid != service.sessionId) {
        access = null;
        page = null;
        denied = true;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void setStatus(String? value) {
    status = value;
    pageIndex = 0;
    load();
  }

  void setCategory(String? value) {
    category = value;
    pageIndex = 0;
    load();
  }

  void setSort(String value) {
    sort = value;
    pageIndex = 0;
    load();
  }

  void reset() {
    query = '';
    status = null;
    category = null;
    sort = 'oldest';
    pageIndex = 0;
    load();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
