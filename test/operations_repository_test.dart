import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maza/features/admin/supabase_operations.dart';
import 'package:maza/web/catalog.dart';
import 'supabase_repository_test.dart' show authenticatedClient, response;

Map<String, dynamic> snapshot({int units = 0}) => {
  'products': [
    {
      'id': 'p',
      'name': 'Pomada',
      'description': '',
      'kind': 'product',
      'category': 'Peinado',
      'price_cents': 3500,
      'units': units,
    },
  ],
  'rental_items': [],
  'rentals': [],
  'charges': [],
  'movements': [],
  'payment_history': [],
};
void main() {
  test(
    'comandos envían una clave estable y reconstruyen stock desde el servidor',
    () async {
      var stock = 3;
      final applied = <String>{};
      final calls = <Map<String, dynamic>>[];
      final c = await authenticatedClient(
        MockClient((r) async {
          if (r.url.path.endsWith('admin_operate')) {
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            calls.add(body);
            if (applied.add(body['p_key'])) {
              stock += (body['p_data']['delta'] as int);
            }
          }
          return response(snapshot(units: stock), r);
        }),
      );
      final ops = SupabaseOperations(c);
      await ops.load();
      final product = ops.products.single;
      await ops.adjustStock(product, 2, 'Compra', key: 'misma-clave');
      await ops.adjustStock(product, 2, 'Compra', key: 'misma-clave');
      expect(stock, 5);
      expect(ops.products.single.units, 5);
      expect(calls.map((x) => x['p_key']), everyElement('misma-clave'));
      final second = SupabaseOperations(c);
      await second.load();
      expect(second.products.single.units, 5);
      second.dispose();
      ops.dispose();
      await c.dispose();
    },
  );
  test(
    'una lectura en vuelo no restaura datos privados después de limpiar la sesión',
    () async {
      final waiting = Completer<http.Response>();
      final started = Completer<void>();
      late http.Request pending;
      final c = await authenticatedClient(
        MockClient((r) async {
          pending = r;
          started.complete();
          return waiting.future;
        }),
      );
      final ops = SupabaseOperations(c);
      final load = ops.load();
      await started.future;
      ops.clear();
      waiting.complete(response(snapshot(units: 8), pending));
      await load;
      expect(ops.products, isEmpty);
      ops.dispose();
      await c.dispose();
    },
  );
  test(
    'fechas de alquiler usan días peruanos y el saldo vuelve del servidor',
    () async {
      Map<String, dynamic>? body;
      final c = await authenticatedClient(
        MockClient((r) async {
          body = jsonDecode(r.body);
          return response(snapshot(), r);
        }),
      );
      final ops = SupabaseOperations(c);
      await ops.reserve(
        demoRentals.first,
        'cliente',
        DateTime(2026, 12, 5),
        DateTime(2026, 12, 7),
        key: 'reserva',
      );
      expect(body!['p_data']['start'], '2026-12-05');
      expect(body!['p_data']['end'], '2026-12-07');
      expect(body!['p_action'], 'rental_create');
      ops.dispose();
      await c.dispose();
    },
  );
}
