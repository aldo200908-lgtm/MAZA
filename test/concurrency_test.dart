import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/core/models.dart';
import 'package:maza/core/store.dart';
import 'package:maza/data/demo_repository.dart';

class DelayedRepository extends DemoRepository {
  Completer<DataSnapshot>? delayed;
  @override
  Future<DataSnapshot> load() => delayed?.future ?? super.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'limpiar la sesión descarta una carga administrativa en vuelo',
    () async {
      final repo = DelayedRepository();
      repo.delayed = Completer<DataSnapshot>();
      final store = AppStore(repo);
      final load = store.load();
      store.clear();
      repo.delayed!.complete(seedDemo());
      await load;
      expect(store.clients, isEmpty);
      expect(store.appointments, isEmpty);
      store.dispose();
    },
  );
  test(
    'una actualización pendiente no puede pisar una escritura nueva',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = DelayedRepository();
      final app = AppStore(repo);
      await app.load();
      repo.delayed = Completer<DataSnapshot>();
      final refresh = app.load();
      await expectLater(
        app.saveClient(
          const Client(id: 'fresh', name: 'Nuevo', phone: '999111299'),
        ),
        throwsA(isA<DomainError>()),
      );
      repo.delayed!.complete(seedDemo());
      await refresh;
      expect(app.clients.any((x) => x.id == 'fresh'), false);
      app.dispose();
    },
  );
}
