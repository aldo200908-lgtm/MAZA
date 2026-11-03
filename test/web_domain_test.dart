import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/core/store.dart';
import 'package:maza/core/clock.dart';
import 'package:maza/core/models.dart';
import 'package:maza/data/demo_repository.dart';
import 'package:maza/web/gateway.dart';
import 'package:maza/web/catalog.dart';
import 'package:maza/web/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  late DemoCustomerGateway gateway;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(DemoRepository());
    await store.load();
    gateway = DemoCustomerGateway(store);
    await gateway.initialize();
  });
  test('un visitante no puede reservar ni ver el historial', () async {
    expect(await gateway.profile(), isNull);
    expect(await gateway.myAppointments(), isEmpty);
    final slots = await gateway.slots(
      store.services.first.id,
      DateTime(2030, 1, 7),
    );
    expect(slots, isNotEmpty);
    await expectLater(
      gateway.book(store.services.first.id, slots.first, ''),
      throwsA(isA<DomainError>()),
    );
  });
  test(
    'la cuenta de ejemplo solo recibe sus citas y reserva con su identidad',
    () async {
      await gateway.signIn('', '');
      final profile = (await gateway.profile())!;
      expect(
        (await gateway.myAppointments()).every((a) => a.clientId == profile.id),
        true,
      );
      final slots = await gateway.slots(
        store.services.first.id,
        DateTime(2030, 1, 7),
      );
      final booked = await gateway.book(
        store.services.first.id,
        slots.first,
        '',
      );
      expect(booked.clientId, profile.id);
      await expectLater(
        gateway.book(store.services.first.id, slots.first, ''),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test('no se puede cancelar ni mover una cita ajena o completada', () async {
    await gateway.signIn('', '');
    final other = store.appointments.firstWhere(
      (a) => a.clientId != store.clients.first.id,
    );
    await expectLater(
      gateway.changeBooking(other, cancel: true),
      throwsA(isA<DomainError>()),
    );
    final done = (await gateway.myAppointments()).firstWhere(
      (a) => a.status == AppointmentStatus.completed,
    );
    await expectLater(
      gateway.changeBooking(done, cancel: true),
      throwsA(isA<DomainError>()),
    );
  });
  test(
    'solicitudes conservan producto y fechas y sobreviven a una recarga',
    () async {
      await gateway.signIn('', '');
      final catalog = await gateway.catalog();
      final item = catalog.rentals.first;
      final start = peruNow().add(const Duration(days: 1));
      final end = start.add(const Duration(days: 2));
      final req = await gateway.requestItem(item, 1, start: start, end: end);
      expect(req.itemName, item.name);
      expect(req.amountCents, item.priceCents * 2);
      final next = DemoCustomerGateway(store);
      await next.initialize();
      expect((await next.myRequests()).single.id, req.id);
    },
  );
  test(
    'una solicitud confirmada no se presenta como fallida por error al refrescar',
    () async {
      final failing = FailedRefreshGateway(store);
      final controller = WebController(
        demo: true,
        store: store,
        customerGateway: failing,
      );
      await controller.start();
      await controller.login('', '');
      final item = controller.catalog!.products.first;
      final saved = await controller.requestItem(item, 1);
      expect(controller.requests.any((r) => r.id == saved.id), true);
      expect(
        (await failing.myRequests()).where((r) => r.id == saved.id).length,
        1,
      );
      controller.dispose();
    },
  );
}

class FailedRefreshGateway extends DemoCustomerGateway {
  FailedRefreshGateway(super.store);
  bool fail = false;
  @override
  Future<Client?> profile() async {
    if (fail) {
      throw const DomainError('Conexión interrumpida después de guardar');
    }
    return super.profile();
  }

  @override
  Future<CustomerRequest> requestItem(
    ShopItem item,
    int quantity, {
    DateTime? start,
    DateTime? end,
  }) async {
    final r = await super.requestItem(item, quantity, start: start, end: end);
    fail = true;
    return r;
  }
}
