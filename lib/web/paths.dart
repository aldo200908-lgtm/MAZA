/// Supabase procesa la sesión antes de entregar estas URLs al router.
/// Nunca se interpreta un token ni se usa como prueba de autorización aquí.
String? authCallbackDestination(Uri uri) {
  try {
    final params = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty && !uri.fragment.startsWith('/')) {
      params.addAll(Uri.splitQueryString(uri.fragment));
    }
    // HashUrlStrategy puede presentar el fragmento como ruta inicial.
    final path = uri.path.replaceFirst(RegExp(r'^/'), '');
    if (path.startsWith('access_token=') ||
        path.startsWith('error=') ||
        path.startsWith('error_code=')) {
      params.addAll(Uri.splitQueryString(path));
    }
    if (params.containsKey('error') ||
        params.containsKey('error_code') ||
        params.containsKey('error_description')) {
      return '/acceso';
    }
    if (params.containsKey('access_token') || params.containsKey('code')) {
      return params['type'] == 'recovery' ? '/recuperar' : '/auth/retorno';
    }
  } on FormatException {
    return null;
  }
  return null;
}

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
