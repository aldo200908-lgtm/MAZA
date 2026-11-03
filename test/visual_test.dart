import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/app.dart';
import 'package:maza/web/shells.dart';

void main() {
  const output = String.fromEnvironment('VISUAL_OUTPUT');
  testWidgets('QA visual web pública y administrativa', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final f = FontLoader('Roboto');
    for (final x in [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
    ]) {
      f.addFont(rootBundle.load('assets/fonts/$x'));
    }
    await f.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    const key = ValueKey('capture');
    await t.pumpWidget(
      const RepaintBoundary(key: key, child: MazaApp(demo: true)),
    );
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File(
          '$output/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('01-inicio-publico');
    await t.tap(find.text('Productos').last);
    await t.pumpAndSettle();
    await capture('02-productos');
    await t.ensureVisible(find.text('Pomada mate'));
    await t.tap(find.text('Pomada mate'));
    await t.pumpAndSettle();
    await capture('03-ficha-producto');
    final shell = t.widget<PublicShell>(find.byType(PublicShell));
    final ctx = t.element(find.byType(PublicShell));
    GoRouter.of(ctx).go('/admin/acceso');
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Abrir panel de demostración'));
    await t.tap(find.text('Abrir panel de demostración'));
    await t.pumpAndSettle();
    await capture('04-resumen-admin');
    t.view.physicalSize = const Size(1440, 1000);
    await t.pumpAndSettle();
    await capture('05-admin-escritorio');
    final adminCtx = t.element(find.byType(AdminShell));
    GoRouter.of(adminCtx).go('/');
    await t.pumpAndSettle();
    await capture('06-inicio-escritorio');
    expect(shell.controller.catalog, isNotNull);
    expect(t.takeException(), isNull);
  }, skip: output.isEmpty);
}
