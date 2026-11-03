import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/app.dart';
import 'package:maza/core/models.dart';
import 'package:maza/features/admin/design_store.dart';
import 'package:maza/web/controller.dart';
import 'package:maza/web/shells.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('un ajuste actualiza catálogo y movimientos, sin permitir stock negativo', () async {
    final c = WebController(demo: true);
    await c.start();
    final ops = c.operations!;
    final product = ops.products.first;
    ops.adjustStock(product, 4, 'Ingreso de ejemplo');
    expect(c.catalog!.products.first.units, product.units + 4);
    expect(ops.movements.first.delta, 4);
    expect(() => ops.adjustStock(product, -100000, 'Retiro'), throwsA(isA<DomainError>()));
    expect(c.catalog!.products.first.units, product.units + 4);
    c.dispose();
  });
  test('un producto añadido queda disponible en el catálogo público de ejemplo', () async {
    final c = WebController(demo: true);
    await c.start();
    c.operations!.saveItem(rental: false, name: 'Cera de peinado', category: 'Peinado',
      description: 'Acabado natural', price: 2900, units: 8, deposit: 0);
    expect(c.catalog!.products.first.name, 'Cera de peinado');
    expect(c.catalog!.products.first.units, 8);
    c.dispose();
  });
  test('los abonos parciales cambian saldo y resumen sin aceptar sobrepago', () {
    final ops = DesignOperations();
    final charge = ops.charges.firstWhere((c) => c.paid == 0);
    final collected = ops.collected;
    ops.recordPayment(charge, 1000, 'Yape');
    expect(charge.status, 'Parcial');
    expect(charge.balance, charge.total - 1000);
    expect(ops.collected, collected + 1000);
    expect(() => ops.recordPayment(charge, charge.total, 'Yape'), throwsA(isA<DomainError>()));
    ops.recordPayment(charge, charge.balance, 'Efectivo');
    expect(charge.status, 'Pagado');
    ops.dispose();
  });
  test('reservas de equipos rechazan cruces y permiten fechas contiguas', () {
    final ops = DesignOperations();
    final previous = ops.rentals.first;
    final item = ops.rentalItems.first;
    expect(() => ops.reserve(item, 'Cliente de ejemplo', previous.start, previous.end),
      throwsA(isA<DomainError>()));
    ops.reserve(item, 'Cliente de ejemplo', previous.end, previous.end.add(const Duration(days: 1)));
    final created = ops.rentals.first;
    expect(created.status, 'Reservado');
    ops.changeRental(created, 'Entregado');
    expect(created.status, 'Entregado');
    ops.changeRental(created, 'Devuelto');
    expect(created.status, 'Devuelto');
    expect(ops.isAvailable(item.id, created.start, created.end), isTrue);
    ops.dispose();
  });
  testWidgets('paneles completos caben a 360px con texto al 130%', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MazaApp(demo: true, initialLocation: '/admin/acceso'));
    await t.pumpAndSettle();
    await t.tap(find.text('Abrir panel de demostración'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    for (final route in ['/admin/stock', '/admin/alquileres', '/admin/pagos',
        '/admin/reportes', '/admin/avisos', '/admin/configuracion']) {
      final ctx = t.element(find.byType(AdminShell));
      GoRouter.of(ctx).go(route);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: route);
    }
  });
  testWidgets('ajustar stock abre un formulario utilizable y actualiza unidades', (t) async {
    await t.pumpWidget(const MazaApp(demo: true, initialLocation: '/admin/acceso'));
    await t.pumpAndSettle();
    await t.tap(find.text('Abrir panel de demostración'));
    await t.pumpAndSettle();
    final shell = t.widget<AdminShell>(find.byType(AdminShell));
    final before = shell.controller.operations!.products.first.units;
    GoRouter.of(t.element(find.byType(AdminShell))).go('/admin/stock');
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Ajustar stock').first);
    await t.tap(find.text('Ajustar stock').first);
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Cantidad de unidades'), '3');
    await t.enterText(find.widgetWithText(TextFormField, 'Motivo del movimiento'), 'Entrada de prueba');
    await t.ensureVisible(find.text('Guardar en la demo'));
    await t.tap(find.text('Guardar en la demo'));
    await t.pumpAndSettle();
    expect(shell.controller.operations!.products.first.units, before + 3);
    expect(t.takeException(), isNull);
  });
}
