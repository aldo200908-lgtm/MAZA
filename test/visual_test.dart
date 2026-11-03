// QA visual opcional: flutter test test/visual_test.dart --dart-define=VISUAL_OUTPUT=/tmp/maza-qa
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/app.dart';

void main() {
  const output = String.fromEnvironment('VISUAL_OUTPUT');
  testWidgets(
    'captura pantallas con fuentes reales para revisión visual',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final roboto = FontLoader('Roboto');
      for (final file in [
        'Roboto-Regular.ttf',
        'Roboto-Bold.ttf',
        'Roboto-Black.ttf',
      ]) {
        roboto.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await roboto.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
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

      await capture('01-acceso');
      await t.ensureVisible(find.text('Explorar demo'));
      await t.tap(find.text('Explorar demo'));
      await t.pumpAndSettle();
      await capture('02-inicio');
      await t.tap(find.text('Citas').last);
      await t.pumpAndSettle();
      await capture('03-agenda');
      await t.tap(find.text('Barbería').last);
      await t.pumpAndSettle();
      await capture('04-barberia');
      await t.tap(find.text('Más').last);
      await t.pumpAndSettle();
      await capture('05-modulos');
      t.view.physicalSize = const Size(1440, 900);
      await t.pumpAndSettle();
      await t.tap(find.text('Inicio').last);
      await t.pumpAndSettle();
      await capture('06-escritorio');
      expect(t.takeException(), isNull);
    },
    skip: output.isEmpty,
  );
}
