/// Only remove objects belonging to this application's configured public bucket.
/// Legacy relative paths and malformed URLs are deliberately left untouched.
List<String> reportImageStoragePaths(
    List<String> references, String storageUrl) {
  final base = Uri.tryParse(storageUrl);
  if (base == null ||
      !base.hasAuthority ||
      !['https', 'http'].contains(base.scheme)) {
    return [];
  }
  const marker = '/storage/v1/object/public/reports-images/';
  return references
      .map(Uri.tryParse)
      .whereType<Uri>()
      .where((uri) =>
          ['https', 'http'].contains(uri.scheme) &&
          uri.hasAuthority &&
          uri.origin == base.origin &&
          uri.path.startsWith(marker))
      .map((uri) => uri.path.substring(marker.length))
      .where((path) => path.isNotEmpty)
      .toList();
}
