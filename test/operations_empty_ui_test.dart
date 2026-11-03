import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/core/theme.dart';
import 'package:maza/features/admin/design_pages.dart';
import 'package:maza/features/admin/design_store.dart';
import 'package:maza/web/catalog.dart';
import 'package:maza/web/controller.dart';

class EmptyOperations extends DesignOperations {
  EmptyOperations() : super(empty: true);
  @override
  bool get real => true;
  final submitted = Completer<void>();
  final finished = Completer<void>();
  @override
  Future<void> saveItem({
    ShopItem? original,
    required bool rental,
    required String name,
    required String category,
    required String description,
    required int price,
    required int units,
    required int deposit,
    String? key,
  }) async {
    submitted.complete();
    await finished.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'catálogo vacío abre primer producto sin equipos y bloquea doble envío',
    (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final ops = EmptyOperations();
      final controller = WebController(demo: true, adminOperations: ops);
      await controller.start();
      await t.pumpWidget(
        MaterialApp(
          theme: mazaTheme(),
          home: Scaffold(body: StudioInventory(controller: controller)),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Añadir producto'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nombre del producto'),
        'Pomada',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Pomada mate',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Precio de venta (S/)'),
        '35',
      );
      await t.ensureVisible(find.text('Guardar'));
      await t.tap(find.text('Guardar'));
      await t.pump();
      expect(ops.submitted.isCompleted, isTrue);
      expect(find.text('Guardando…'), findsOneWidget);
      final button = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardando…'),
      );
      expect(button.onPressed, isNull);
      ops.finished.complete();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Nombre del producto'), findsNothing);
      await t.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
