import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maza/core/models.dart';
import 'package:maza/data/demo_repository.dart';
import 'package:maza/data/supabase_repository.dart';

const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
Future<SupabaseClient> authenticatedClient(MockClient httpClient) async {
  final c = SupabaseClient(
    'https://example.supabase.co',
    'public-test-key',
    httpClient: httpClient,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await c.auth.setInitialSession(
    jsonEncode({
      'access_token': 'test-token',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': owner,
        'app_metadata': {},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
  return c;
}

http.Response response(Object? body, http.Request request) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
void main() {
  test('carga historial completo incluso si supera las 1000 filas', () async {
    final seed = seedDemo();
    final c = await authenticatedClient(
      MockClient((r) async {
        final table = r.url.pathSegments.last;
        if (table == 'app_admin') return response({'user_id': owner}, r);
        final rows = switch (table) {
          'services' => seed.services.map((x) => x.toJson()).toList(),
          'barbers' => seed.barbers.map((x) => x.toJson()).toList(),
          'clients' => seed.clients.map((x) => x.toJson()).toList(),
          _ => List.generate(
            1201,
            (i) => {
              ...seed.appointments.first.toJson(),
              'id': 'appointment-$i',
            },
          ),
        };
        final offset = int.parse(r.url.queryParameters['offset'] ?? '0');
        final limit = int.parse(r.url.queryParameters['limit'] ?? '1000');
        return response(rows.skip(offset).take(limit).toList(), r);
      }),
    );
    final snapshot = await SupabaseRepository(c).load();
    expect(snapshot.appointments.length, 1201);
    expect(snapshot.appointments.last.id, 'appointment-1200');
    await c.dispose();
  });
  test('una sesión obsoleta no sobrescribe una cita actualizada', () async {
    final a = seedDemo().appointments.first;
    final c = await authenticatedClient(
      MockClient((r) async {
        if (r.url.queryParameters['version'] == 'eq.${a.version}') {
          return response(null, r);
        }
        return response(a.toJson(), r);
      }),
    );
    await expectLater(
      SupabaseRepository(c).saveAppointment(
        a.copy(status: AppointmentStatus.confirmed),
        isNew: false,
      ),
      throwsA(isA<DomainError>()),
    );
    await c.dispose();
  });
  test('usuario ajeno no llega a cargar las tablas privadas', () async {
    final c = await authenticatedClient(
      MockClient((r) async => response(null, r)),
    );
    await expectLater(
      SupabaseRepository(c).load(),
      throwsA(isA<DomainError>()),
    );
    await c.dispose();
  });
}
