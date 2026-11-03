import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models.dart';
import 'paths.dart';

typedef FacebookLauncher = Future<bool> Function(String redirectTo);

/// No contiene secretos de Meta. El proveedor se configura únicamente en Supabase.
class FacebookAuth {
  FacebookAuth({
    required this.settingsUri,
    required this.publishableKey,
    required this.redirectTo,
    required this.launch,
    this.httpClient,
  });
  factory FacebookAuth.forClient(SupabaseClient client) => FacebookAuth(
    settingsUri: Uri.parse(
      '${const String.fromEnvironment('SUPABASE_URL')}/auth/v1/settings',
    ),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    redirectTo: const String.fromEnvironment('AUTH_REDIRECT_URL'),
    launch: (redirect) => client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: redirect,
      scopes: 'email',
    ),
  );
  final Uri settingsUri;
  final String publishableKey, redirectTo;
  final FacebookLauncher launch;
  final http.Client? httpClient;
  bool enabled = false;
  String? returnTo;
  static const _pending = 'maza.web.facebook.pending';

  Future<void> initialize() async {
    enabled = false;
    returnTo = null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pending);
    await prefs.remove(_pending);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final age =
            DateTime.now().millisecondsSinceEpoch - (data['created'] as int);
        if (age >= 0 && age < const Duration(minutes: 15).inMilliseconds) {
          returnTo = safeDestination(data['path'] as String?);
        }
      } catch (_) {
        /* Un intento antiguo no impide entrar por correo. */
      }
    }
    final transport = httpClient ?? http.Client();
    try {
      if (!settingsUri.hasAuthority ||
          publishableKey.isEmpty ||
          redirectTo.isEmpty) {
        return;
      }
      final response = await transport
          .get(settingsUri, headers: {'apikey': publishableKey})
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        enabled = (data['external'] as Map?)?['facebook'] == true;
      }
    } catch (_) {
      enabled = false;
    } finally {
      if (httpClient == null) transport.close();
    }
  }

  Future<void> signIn(String destination) async {
    if (!enabled) {
      throw const DomainError(
        'El acceso con Facebook todavía no está habilitado. Puedes ingresar con tu correo.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pending,
      jsonEncode({
        'path': safeDestination(destination),
        'created': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    try {
      if (!await launch(redirectTo)) {
        throw const DomainError(
          'No se pudo abrir Facebook. Inténtalo de nuevo o ingresa con tu correo.',
        );
      }
      // Abrir el proveedor no significa que haya una sesión: la valida Supabase al volver.
    } catch (_) {
      await prefs.remove(_pending);
      rethrow;
    }
  }
}
