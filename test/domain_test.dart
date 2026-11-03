import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/core/clock.dart';
import 'package:maza/core/models.dart';
import 'package:maza/core/store.dart';
import 'package:maza/data/demo_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(DemoRepository());
    await store.load();
  });
  DateTime start(int hour, [int minute = 0]) =>
      peruToUtc(DateTime(2030, 1, 7, hour, minute));
  test('moneda exacta y reloj Perú independiente del sistema', () {
    expect(soles(2590), 'S/ 25.90');
    expect(peruWall(DateTime.utc(2030, 1, 8, 2)).day, 7);
    expect(peruToUtc(DateTime(2030, 1, 7, 21)), DateTime.utc(2030, 1, 8, 2));
  });
  test(
    'rechaza solapamiento pero permite el siguiente turno contiguo',
    () async {
      final s = store.services.first;
      final b = store.barbers.first;
      final c = store.clients.first;
      await store.book(
        clientId: c.id,
        serviceId: s.id,
        barberId: b.id,
        start: start(10),
      );
      await expectLater(
        () => store.book(
          clientId: c.id,
          serviceId: s.id,
          barberId: b.id,
          start: start(10, 15),
        ),
        throwsA(isA<DomainError>()),
      );
      await store.book(
        clientId: c.id,
        serviceId: s.id,
        barberId: b.id,
        start: start(10).add(Duration(minutes: s.minutes)),
      );
    },
  );
  test(
    'rechaza servicio que termina fuera del horario y día cerrado',
    () async {
      final s = store.services.first;
      final b = store.barbers.first;
      final c = store.clients.first;
      await expectLater(
        () => store.book(
          clientId: c.id,
          serviceId: s.id,
          barberId: b.id,
          start: start(19, 50),
        ),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        () => store.book(
          clientId: c.id,
          serviceId: s.id,
          barberId: b.id,
          start: peruToUtc(DateTime(2030, 1, 6, 10)),
        ),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'cancelar libera turno y reactivar vuelve a comprobar conflicto',
    () async {
      final s = store.services.first;
      final b = store.barbers.first;
      final c = store.clients.first;
      final a = await store.book(
        clientId: c.id,
        serviceId: s.id,
        barberId: b.id,
        start: start(11),
      );
      await store.changeStatus(a, AppointmentStatus.cancelled);
      await store.book(
        clientId: c.id,
        serviceId: s.id,
        barberId: b.id,
        start: start(11),
      );
      await expectLater(
        () => store.changeStatus(
          store.appointments.firstWhere((x) => x.id == a.id),
          AppointmentStatus.confirmed,
        ),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test('historial conserva precio y duración tras editar catálogo', () async {
    final s = store.services.first;
    final b = store.barbers.first;
    final c = store.clients.first;
    final a = await store.book(
      clientId: c.id,
      serviceId: s.id,
      barberId: b.id,
      start: start(12),
    );
    await store.saveService(
      Service(id: s.id, name: s.name, priceCents: 9900, minutes: 90),
    );
    final saved = store.appointments.firstWhere((x) => x.id == a.id);
    expect(saved.priceCents, s.priceCents);
    expect(saved.minutes, s.minutes);
  });
  test('persistencia demo sobrevive a un nuevo repositorio', () async {
    await store.saveClient(
      Client(
        id: 'new-client',
        name: 'Lucía Quispe',
        phone: '987654321',
        notes: 'Puno',
      ),
    );
    final reloaded = AppStore(DemoRepository());
    await reloaded.load();
    expect(reloaded.clients.any((x) => x.name == 'Lucía Quispe'), true);
  });
  test('barbero inactivo no admite reservas nuevas', () async {
    final b = store.barbers.first;
    await store.saveBarber(
      Barber(
        id: b.id,
        name: b.name,
        active: false,
        weekdays: b.weekdays,
        openMinute: b.openMinute,
        closeMinute: b.closeMinute,
      ),
    );
    await expectLater(
      () => store.book(
        clientId: store.clients.first.id,
        serviceId: store.services.first.id,
        barberId: b.id,
        start: start(13),
      ),
      throwsA(isA<DomainError>()),
    );
  });
}
