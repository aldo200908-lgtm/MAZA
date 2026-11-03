import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/app.dart';
import 'package:maza/web/shells.dart';
import 'package:maza/web/paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('retorno de login solo acepta destinos internos', () {
    expect(safeDestination('https://other.test'), '/mi-cuenta');
    expect(safeDestination('//other.test'), '/mi-cuenta');
    expect(safeDestination('/acceso?volver=/acceso'), '/mi-cuenta');
    expect(
      safeDestination('/barberia/reservar?servicio=abc'),
      '/barberia/reservar?servicio=abc',
    );
  });
  test('normaliza callbacks reales sin tratar las rutas públicas como tokens', () {
    expect(
      authCallbackDestination(Uri.parse(
        'https://example.test/MAZA/#access_token=example&refresh_token=example&type=signup',
      )),
      '/auth/retorno',
    );
    expect(
      authCallbackDestination(Uri.parse(
        'https://example.test/MAZA/?code=example',
      )),
      '/auth/retorno',
    );
    expect(
      authCallbackDestination(Uri.parse(
        'https://example.test/MAZA/#access_token=example&type=recovery',
      )),
      '/recuperar',
    );
    expect(
      authCallbackDestination(Uri.parse(
        'https://example.test/MAZA/#error=access_denied&error_code=otp_expired',
      )),
      '/acceso',
    );
    expect(
      authCallbackDestination(Uri.parse('https://example.test/MAZA/#/productos')),
      isNull,
    );
  });
  testWidgets('el fragmento de confirmación vuelve al acceso sin sesión', (
    t,
  ) async {
    await t.pumpWidget(
      const MazaApp(
        demo: true,
        initialLocation:
            '/access_token=example-only&refresh_token=example-only&type=signup',
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Esta página no existe.'), findsNothing);
    expect(find.text('Cuenta de ejemplo'), findsOneWidget);
  });
  testWidgets('un error del enlace de correo abre acceso en lugar de 404', (
    t,
  ) async {
    await t.pumpWidget(
      const MazaApp(
        demo: true,
        initialLocation: '/error=access_denied&error_description=expired',
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Esta página no existe.'), findsNothing);
    expect(find.text('Cuenta de ejemplo'), findsOneWidget);
  });
  testWidgets('acceso directo a admin exige entrada independiente', (t) async {
    await t.pumpWidget(const MazaApp(demo: true, initialLocation: '/admin'));
    await t.pumpAndSettle();
    expect(find.text('Administración de ejemplo'), findsOneWidget);
    expect(find.text('Luis Quispe'), findsNothing);
    await t.ensureVisible(
      find.widgetWithText(FilledButton, 'Abrir panel de demostración'),
    );
    await t.pumpAndSettle();
    await t.tap(
      find.widgetWithText(FilledButton, 'Abrir panel de demostración'),
    );
    await t.pumpAndSettle();
    expect(find.text('Tu negocio, en orden.'), findsOneWidget);
    await t.tap(find.text('Gestión').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Clientes'));
    await t.pumpAndSettle();
    expect(find.text('Luis Quispe'), findsOneWidget);
    final shell = t.widget<AdminShell>(
      find.byType(AdminShell, skipOffstage: false),
    );
    await shell.controller.leaveAdmin();
    await t.pumpAndSettle();
    expect(find.text('Luis Quispe'), findsNothing);
    expect(find.text('Administración de ejemplo'), findsOneWidget);
  });
  testWidgets(
    'la cuenta no muestra citas ajenas y conserva navegación pública',
    (t) async {
      await t.pumpWidget(
        const MazaApp(demo: true, initialLocation: '/mi-cuenta'),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Entrar con cuenta de ejemplo'));
      await t.pumpAndSettle();
      expect(find.text('Hola, Luis.'), findsOneWidget);
      expect(find.text('Marco Condori'), findsNothing);
      expect(find.text('Reservar'), findsOneWidget);
      expect(find.text('Tus datos'), findsNothing);
    },
  );
  testWidgets('un enlace desconocido permite regresar al inicio', (t) async {
    await t.pumpWidget(
      const MazaApp(demo: true, initialLocation: '/no-existe'),
    );
    await t.pumpAndSettle();
    expect(find.text('Esta página no existe.'), findsOneWidget);
    await t.tap(find.text('Ir al inicio'));
    await t.pumpAndSettle();
    expect(find.text('Tu estilo.\nA tu hora.'), findsOneWidget);
  });

  testWidgets('cliente con datos guardados reserva con tres elecciones', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({'maza.web.customer': true});
    await t.pumpWidget(const MazaApp(demo: true));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(
        const ValueKey('reserve-10000000-0000-4000-8000-000000000001'),
      ),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(
      find.byKey(
        const ValueKey('reserve-10000000-0000-4000-8000-000000000001'),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('booking-slots')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    final slot = find.byType(OutlinedButton).first;
    await t.ensureVisible(slot);
    await t.pumpAndSettle();
    await t.tap(slot);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Confirmar mi cita'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Confirmar mi cita'));
    await t.pumpAndSettle();
    expect(find.text('Tu cita está guardada.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('el turno elegido se conserva al pasar por el acceso', (t) async {
    final future = DateTime.now().toUtc().add(const Duration(days: 7));
    final uri = Uri(
      path: '/barberia/reservar',
      queryParameters: {
        'servicio': '10000000-0000-4000-8000-000000000001',
        'barbero': '20000000-0000-4000-8000-000000000001',
        'turno': future.toIso8601String(),
      },
    );
    await t.pumpWidget(MazaApp(demo: true, initialLocation: uri.toString()));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Usar cuenta de ejemplo'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Usar cuenta de ejemplo'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Entrar con cuenta de ejemplo'));
    await t.pumpAndSettle();
    await t.tap(find.text('Entrar con cuenta de ejemplo'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Confirmar mi cita'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(find.text('Confirmar mi cita'), findsOneWidget);
    expect(find.text('Reserva para Luis Quispe'), findsOneWidget);
  });
  testWidgets('Inicio vuelve a la portada al tocarlo desde el buscador', (
    t,
  ) async {
    await t.pumpWidget(const MazaApp(demo: true, initialLocation: '/buscar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Inicio').last);
    await t.pumpAndSettle();
    expect(find.text('Tu estilo.\nA tu hora.'), findsOneWidget);
  });
}
