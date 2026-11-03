import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('la web abre públicamente y separa sus cinco destinos', (
    t,
  ) async {
    await t.pumpWidget(const MazaApp(demo: true));
    await t.pumpAndSettle();
    expect(find.text('Tu estilo.\nA tu hora.'), findsOneWidget);
    expect(find.text('Luis Quispe'), findsNothing);
    await t.tap(find.text('Productos').last);
    await t.pumpAndSettle();
    expect(find.text('Pomada mate'), findsOneWidget);
    await t.tap(find.text('Alquileres').last);
    await t.pumpAndSettle();
    expect(find.text('Sillón de barbería'), findsOneWidget);
    await t.tap(find.text('Cuenta').last);
    await t.pumpAndSettle();
    expect(find.text('Cuenta de ejemplo'), findsOneWidget);
  });
  testWidgets('360px y texto al 130% no desbordan', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MazaApp(demo: true));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    for (final text in ['Reservar', 'Productos', 'Alquileres', 'Cuenta']) {
      await t.tap(find.text(text).last);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      if (text == 'Cuenta') break;
    }
  });
}
