/// Remove one-time authentication material while preserving application routes.
Uri cleanAuthCallbackUri(Uri uri) {
  final query = Map<String, dynamic>.from(uri.queryParametersAll);
  for (final key in const [
    'code',
    'state',
    'error',
    'error_code',
    'error_description',
    'token_hash',
    'access_token',
    'refresh_token',
    'expires_in',
    'expires_at',
    'token_type',
    'type'
  ]) {
    query.remove(key);
  }
  final authFragment = uri.fragment.contains('access_token=') ||
      uri.fragment.contains('error_description=');
  return uri.replace(
      queryParameters: query.isEmpty ? null : query,
      query: query.isEmpty ? '' : null,
      fragment: authFragment ? '' : uri.fragment);
}

Future<T> consumeBrowserAuthCallback<T>(Uri uri, Future<T> Function() exchange,
    void Function(Uri) replaceLocation) async {
  try {
    return await exchange();
  } finally {
    // Codes cannot be replayed. Also clean failed/expired links on reload.
    replaceLocation(cleanAuthCallbackUri(uri));
  }
}
