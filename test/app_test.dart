import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('demo navega por módulos sin credenciales', (tester) async {
    await tester.pumpWidget(const MazaApp(demo: true));
    await tester.pumpAndSettle();
    expect(find.text('MAZA'), findsWidgets);
    await tester.ensureVisible(find.text('Explorar demo'));
    await tester.tap(find.text('Explorar demo'));
    await tester.pumpAndSettle();
    expect(find.text('Tu día, en orden.'), findsOneWidget);
    await tester.tap(find.text('Citas').last);
    await tester.pumpAndSettle();
    expect(find.text('Tu agenda'), findsOneWidget);
    await tester.tap(find.text('Barbería').last);
    await tester.pumpAndSettle();
    expect(find.text('Corte clásico'), findsOneWidget);
    await tester.tap(find.text('Más').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock de belleza'));
    await tester.pumpAndSettle();
    expect(find.text('Próximamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pantalla pequeña y texto ampliado no desbordan', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MazaApp(demo: true));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explorar demo'));
    await tester.tap(find.text('Explorar demo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Citas').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
