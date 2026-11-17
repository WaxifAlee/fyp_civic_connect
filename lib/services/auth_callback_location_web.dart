import 'package:web/web.dart' as web;

void replaceAuthCallbackLocation(Uri uri) {
  web.window.history.replaceState(null, '', uri.toString());
}
