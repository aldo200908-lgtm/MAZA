import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/core/models.dart';
import 'package:maza/core/store.dart';
import 'package:maza/core/theme.dart';
import 'package:maza/data/demo_repository.dart';
import 'package:maza/web/catalog.dart';
import 'package:maza/web/controller.dart';
import 'package:maza/web/gateway.dart';
import 'package:maza/features/public/booking.dart';

class DelayedGateway extends DemoCustomerGateway {
  DelayedGateway(super.store);
  Completer<List<BookingSlot>>? waiting;
  @override
  Future<List<BookingSlot>> slots(
    String id,
    DateTime day, {
    String? barberId,
    Appointment? appointment,
  }) =>
      waiting?.future ??
      super.slots(id, day, barberId: barberId, appointment: appointment);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('cambiar fecha oculta turnos viejos hasta terminar la consulta', (
    t,
  ) async {
    final store = AppStore(DemoRepository());
    final gateway = DelayedGateway(store);
    final controller = WebController(
      demo: true,
      store: store,
      customerGateway: gateway,
    );
    await controller.start();
    await t.pumpWidget(
      MaterialApp(
        theme: mazaTheme(),
        home: Scaffold(
          body: BookingScreen(
            controller: controller,
            uri: Uri.parse(
              '/barberia/reservar?servicio=10000000-0000-4000-8000-000000000001',
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final dateChoice = t.widgetList<ChoiceChip>(find.byType(ChoiceChip)).first;
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('booking-slots')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsWidgets);
    gateway.waiting = Completer<List<BookingSlot>>();
    dateChoice.onSelected!(true);
    await t.pump();
    expect(find.byType(OutlinedButton), findsNothing);
    gateway.waiting!.complete([]);
    await t.pumpAndSettle();
    expect(find.text('Este día está completo'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    controller.dispose();
  });
  test(
    'una edición de catálogo notifica a la web sin recargar el repositorio en bucle',
    () async {
      final controller = WebController(demo: true);
      await controller.start();
      final s = controller.adminStore.services.first;
      final changed = Completer<void>();
      var notices = 0;
      controller.addListener(() {
        notices++;
        if (controller.catalog!.services.any(
              (x) => x.id == s.id && x.priceCents == 5550,
            ) &&
            !changed.isCompleted) {
          changed.complete();
        }
      });
      await controller.adminStore.saveService(
        Service(id: s.id, name: s.name, priceCents: 5550, minutes: s.minutes),
      );
      await changed.future.timeout(const Duration(seconds: 2));
      expect(notices, lessThan(15));
      controller.dispose();
    },
  );
}
