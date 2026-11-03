import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/core/clock.dart';
import 'package:maza/core/models.dart';
import 'package:maza/core/store.dart';
import 'package:maza/core/theme.dart';
import 'package:maza/data/demo_repository.dart';
import 'package:maza/features/appointments/appointment_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('una cita se crea desde el formulario con el horario elegido', (
    t,
  ) async {
    final store = AppStore(DemoRepository());
    await store.load();
    final count = store.appointments.length;
    await t.pumpWidget(
      MaterialApp(
        theme: mazaTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () =>
                  showAppointmentEditor(ctx, store, day: DateTime(2030, 1, 7)),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Abrir'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('10:00'));
    await t.tap(find.text('10:00'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Crear cita'));
    await t.tap(find.text('Crear cita'));
    await t.pumpAndSettle();
    expect(store.appointments.length, count + 1);
    expect(peruWall(store.appointments.last.start).hour, 10);
    expect(t.takeException(), isNull);
  });
  testWidgets('un estado rechazado no queda seleccionado como guardado', (
    t,
  ) async {
    final store = AppStore(DemoRepository());
    await store.load();
    final a = await store.book(
      clientId: store.clients.first.id,
      serviceId: store.services.first.id,
      barberId: store.barbers.first.id,
      start: peruToUtc(DateTime(2030, 1, 7, 11)),
    );
    await store.changeStatus(a, AppointmentStatus.cancelled);
    await store.book(
      clientId: store.clients.first.id,
      serviceId: store.services.first.id,
      barberId: store.barbers.first.id,
      start: a.start,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: mazaTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAppointmentDetails(ctx, store, a),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Abrir'));
    await t.pumpAndSettle();
    await t.tap(
      find.byWidgetPredicate((w) => w is DropdownButton<AppointmentStatus>),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Confirmada').last);
    await t.pumpAndSettle();
    final selector = t.widget<DropdownButton<AppointmentStatus>>(
      find.byWidgetPredicate((w) => w is DropdownButton<AppointmentStatus>),
    );
    expect(selector.value, AppointmentStatus.cancelled);
  });
}
