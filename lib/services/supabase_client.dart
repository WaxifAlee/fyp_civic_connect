import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_callback_uri.dart';
import 'auth_callback_location.dart';

enum AuthNavigation { confirmed, recovery, signedOut, failed }

/// Public application configuration. Database administration stays in the CLI.
abstract final class SupabaseService {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'));
  static const _nativeRedirect = 'io.supabase.civicconnect://auth-callback/';
  static String get authRedirectUrl =>
      kIsWeb ? '${Uri.base.origin}/' : _nativeRedirect;
  static bool _initialized = false;
  static bool recoveryActive = false;
  static Future<void>? _initialization;
  static final navigation = ValueNotifier<AuthNavigation?>(null);
  static final _handledLinks = <String>{};
  static Future<void> _linkQueue = Future.value();
  static bool get isConfigured => _initialized;
  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Account services are not initialized.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initialization ??=
        _initialize().whenComplete(() => _initialization = null);
  }

  static Future<void> _initialize() async {
    final endpoint = Uri.tryParse(url);
    if (endpoint == null ||
        endpoint.host.isEmpty ||
        !isPublicClientKey(anonKey) ||
        (endpoint.scheme != 'https' && endpoint.scheme != 'http')) {
      throw StateError('Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
          'in your local backend configuration.');
    }
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: false,
      // Listen before exchanging the initial link so cold-start recovery is retained.
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    _initialized = true;
    client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        recoveryActive = true;
        navigation.value = AuthNavigation.recovery;
      } else if (state.event == AuthChangeEvent.signedOut) {
        recoveryActive = false;
        navigation.value = AuthNavigation.signedOut;
      }
    }, onError: (Object error) {
      // A transient refresh failure must not replace a valid screen or session.
      debugPrint('Authentication refresh unavailable: ${error.runtimeType}');
    });
    if (kIsWeb) {
      await _handleLink(Uri.base);
    } else {
      final links = AppLinks();
      links.uriLinkStream.listen(_enqueueLink,
          onError: (Object error) => navigation.value = AuthNavigation.failed);
      final initial = await links.getInitialLink();
      if (initial != null) _enqueueLink(initial);
    }
  }

  static void _enqueueLink(Uri uri) {
    _linkQueue = _linkQueue.then((_) => _handleLink(uri));
  }

  static Future<void> _handleLink(Uri uri) async {
    if (!isAuthCallback(uri,
        isWeb: kIsWeb, webOrigin: kIsWeb ? Uri.base.origin : null)) {
      return;
    }
    final key = uri.toString();
    if (!_handledLinks.add(key)) return;
    try {
      final result = kIsWeb
          ? await consumeBrowserAuthCallback(
              uri,
              () => client.auth.getSessionFromUrl(uri),
              replaceAuthCallbackLocation)
          : await client.auth.getSessionFromUrl(uri);
      if (!recoveryActive &&
          result.session.user.emailConfirmedAt != null &&
          result.redirectType != 'recovery') {
        navigation.value = AuthNavigation.confirmed;
      }
    } catch (_) {
      _handledLinks.remove(key);
      navigation.value = AuthNavigation.failed;
    }
  }

  @visibleForTesting
  static bool isPublicClientKey(String key) {
    if (key.startsWith('sb_publishable_')) return key.length > 20;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static bool isAuthCallback(Uri uri,
      {required bool isWeb, String? webOrigin}) {
    final allowed = isWeb
        ? (uri.hasAuthority && uri.origin == webOrigin)
        : uri.scheme == 'io.supabase.civicconnect' &&
            uri.host == 'auth-callback';
    return allowed &&
        (uri.queryParameters.containsKey('code') ||
            uri.fragment.contains('access_token=') ||
            uri.fragment.contains('error_description='));
  }
}
