String safeDestination(String? raw, {String fallback = '/mi-cuenta'}) {
  if (raw == null) return fallback;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !raw.startsWith('/') ||
      raw.startsWith('//') ||
      uri.hasScheme ||
      uri.hasAuthority ||
      ['/acceso', '/admin/acceso', '/recuperar'].contains(uri.path)) {
    return fallback;
  }
  return uri.toString();
}
