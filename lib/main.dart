import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app/civic_connect_app.dart';

export 'app/civic_connect_app.dart' show CivicConnectApp;
export 'features/auth/welcome_screen.dart' show WelcomeScreen;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Public Sans'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const CivicConnectApp());
}
