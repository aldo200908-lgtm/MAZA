import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/core/models.dart';
import 'package:maza/web/google_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  GoogleAuth service({required bool enabled, GoogleLauncher? launcher}) =>
      GoogleAuth(
        settingsUri: Uri.parse('https://example.supabase.co/auth/v1/settings'),
        publishableKey: 'public-test-key',
        redirectTo: 'https://example.test/MAZA/',
        httpClient: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'external': {'google': enabled},
            }),
            200,
          ),
        ),
        launch: launcher ?? ((redirect) async => true),
      );
  test('no ofrece Google si el proveedor está desactivado', () async {
    final auth = service(enabled: false);
    await auth.initialize();
    expect(auth.enabled, isFalse);
    await expectLater(auth.signIn('/admin'), throwsA(isA<DomainError>()));
  });
  test(
    'usa el retorno fijo y conserva el servicio elegido al volver de Google',
    () async {
      String? redirect;
      final auth = service(
        enabled: true,
        launcher: (url) async {
          redirect = url;
          return true;
        },
      );
      await auth.initialize();
      await auth.signIn('/barberia/reservar?servicio=corte');
      expect(redirect, 'https://example.test/MAZA/');
      final callback = service(enabled: true);
      await callback.initialize();
      expect(callback.returnTo, '/barberia/reservar?servicio=corte');
      final again = service(enabled: true);
      await again.initialize();
      expect(again.returnTo, isNull);
    },
  );
  test(
    'rechaza retornos externos y borra el intento si no abre Google',
    () async {
      final auth = service(enabled: true, launcher: (_) async => false);
      await auth.initialize();
      await expectLater(
        auth.signIn('https://evil.test'),
        throwsA(isA<DomainError>()),
      );
      final callback = service(enabled: true);
      await callback.initialize();
      expect(callback.returnTo, isNull);
      final valid = service(enabled: true);
      await valid.initialize();
      await valid.signIn('//evil.test');
      final result = service(enabled: true);
      await result.initialize();
      expect(result.returnTo, '/mi-cuenta');
    },
  );
  test(
    'si falla la consulta de proveedores no bloquea el acceso por correo',
    () async {
      final auth = GoogleAuth(
        settingsUri: Uri.parse('https://example.test/settings'),
        publishableKey: 'public-test-key',
        redirectTo: 'https://example.test/',
        httpClient: MockClient((_) async => throw Exception('Sin conexión')),
        launch: (_) async => true,
      );
      await auth.initialize();
      expect(auth.enabled, isFalse);
    },
  );
}
