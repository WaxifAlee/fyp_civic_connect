import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Explicit preview state keeps sample data and writes separate from real sessions.
class AppSession extends ChangeNotifier {
  AppSession._();
  static final instance = AppSession._();
  bool _isPreview = const bool.fromEnvironment('PREVIEW_MODE');
  ThemeMode _themeMode = ThemeMode.system;
  bool get isPreview => _isPreview;
  ThemeMode get themeMode => _themeMode;

  Future<void> restorePreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final name = preferences.getString('appearance');
      _themeMode = ThemeMode.values.firstWhere((mode) => mode.name == name,
          orElse: () => ThemeMode.system);
      notifyListeners();
    } catch (_) {/* Platform storage can be unavailable in private sessions. */}
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((preferences) => preferences.setString('appearance', mode.name))
        .catchError((_) => false);
  }

  void enterPreview() {
    _isPreview = true;
    notifyListeners();
  }

  void leavePreview() {
    _isPreview = false;
    notifyListeners();
  }
}
