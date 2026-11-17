import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_civic_connect/app/app_session.dart';
import 'package:fyp_civic_connect/core/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('restored appearance updates the running application', () async {
    SharedPreferences.setMockInitialValues({'appearance': 'dark'});
    var changes = 0;
    void onChanged() {
      changes++;
    }

    AppSession.instance.addListener(onChanged);
    addTearDown(() => AppSession.instance.removeListener(onChanged));
    await AppSession.instance.restorePreferences();
    expect(AppSession.instance.themeMode, ThemeMode.dark);
    expect(changes, 1);
  });
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    test('${theme.brightness.name} theme has readable body and status text',
        () {
      final c = theme.colorScheme;
      for (final pair in [
        (c.onSurface, c.surface),
        (c.onSurfaceVariant, c.surface),
        (c.onSurfaceVariant, c.surfaceContainerLowest),
        (c.onPrimary, c.primary),
        (c.onPrimaryContainer, c.primaryContainer),
        (c.onSecondaryContainer, c.secondaryContainer),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    });
  }
}
