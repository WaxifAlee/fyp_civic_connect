/// Resolve an owned avatar URL only within this deployment's public bucket.
String? ownedAvatarStoragePath(
    String? reference, String storageUrl, String owner) {
  final base = Uri.tryParse(storageUrl);
  final uri = reference == null ? null : Uri.tryParse(reference);
  const marker = '/storage/v1/object/public/profile-pictures/';
  if (base == null ||
      uri == null ||
      !base.hasAuthority ||
      !uri.hasAuthority ||
      uri.origin != base.origin ||
      !uri.path.startsWith(marker)) {
    return null;
  }
  final path = uri.path.substring(marker.length);
  final pattern =
      RegExp('^${RegExp.escape(owner)}/[0-9a-f-]{36}\\.(jpg|jpeg|png|webp)\$');
  return pattern.hasMatch(path) ? path : null;
}

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
