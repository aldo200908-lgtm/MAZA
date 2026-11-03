import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/clock.dart';
import '../core/models.dart';
import '../core/repository.dart';

class DemoRepository implements MazaRepository {
  static const storageKey = 'maza.demo.v1';
  DataSnapshot? _data;
  @override
  bool get isDemo => true;
  @override
  Future<DataSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    // Un JSON corrupto no se borra silenciosamente: se muestra un error.
    _data = raw == null ? seedDemo() : DataSnapshot.fromJson(jsonDecode(raw));
    return _data!;
  }

  Future<void> _commit(DataSnapshot d) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, jsonEncode(d.toJson()))) {
      throw const DomainError('No se pudo guardar en el dispositivo.');
    }
    _data = d;
  }

  @override
  Future<Service> saveService(Service value) async {
    final d = _data!;
    await _commit(
      DataSnapshot(
        services: [...d.services.where((x) => x.id != value.id), value],
        barbers: d.barbers,
        clients: d.clients,
        appointments: d.appointments,
      ),
    );
    return value;
  }

  @override
  Future<Barber> saveBarber(Barber value) async {
    final d = _data!;
    await _commit(
      DataSnapshot(
        services: d.services,
        barbers: [...d.barbers.where((x) => x.id != value.id), value],
        clients: d.clients,
        appointments: d.appointments,
      ),
    );
    return value;
  }

  @override
  Future<Client> saveClient(Client value) async {
    final d = _data!;
    await _commit(
      DataSnapshot(
        services: d.services,
        barbers: d.barbers,
        clients: [...d.clients.where((x) => x.id != value.id), value],
        appointments: d.appointments,
      ),
    );
    return value;
  }

  @override
  Future<Appointment> saveAppointment(
    Appointment value, {
    required bool isNew,
  }) async {
    final d = _data!;
    final current = d.appointments.where((a) => a.id == value.id).firstOrNull;
    if (!isNew && current?.version != value.version) {
      throw const DomainError(
        'Esta cita cambió. Actualiza la agenda antes de continuar.',
      );
    }
    final saved = isNew ? value : value.copy(version: value.version + 1);
    await _commit(
      DataSnapshot(
        services: d.services,
        barbers: d.barbers,
        clients: d.clients,
        appointments: [...d.appointments.where((x) => x.id != saved.id), saved],
      ),
    );
    return saved;
  }
}

DataSnapshot seedDemo() {
  const services = [
    Service(
      id: '10000000-0000-4000-8000-000000000001',
      name: 'Corte clásico',
      priceCents: 2500,
      minutes: 30,
    ),
    Service(
      id: '10000000-0000-4000-8000-000000000002',
      name: 'Degradado + diseño',
      priceCents: 3500,
      minutes: 45,
    ),
    Service(
      id: '10000000-0000-4000-8000-000000000003',
      name: 'Corte + barba',
      priceCents: 4500,
      minutes: 60,
    ),
    Service(
      id: '10000000-0000-4000-8000-000000000004',
      name: 'Perfilado de barba',
      priceCents: 2000,
      minutes: 20,
    ),
  ];
  const barbers = [
    Barber(id: '20000000-0000-4000-8000-000000000001', name: 'Diego Mamani'),
    Barber(
      id: '20000000-0000-4000-8000-000000000002',
      name: 'Joaquín Flores',
      openMinute: 600,
      closeMinute: 1140,
    ),
  ];
  const clients = [
    Client(
      id: '30000000-0000-4000-8000-000000000001',
      name: 'Luis Quispe',
      phone: '999111201',
      notes: 'Prefiere degradado bajo. Cliente de Puno.',
    ),
    Client(
      id: '30000000-0000-4000-8000-000000000002',
      name: 'Marco Condori',
      phone: '999111202',
      notes: 'Corte a tijera en la parte superior.',
    ),
    Client(
      id: '30000000-0000-4000-8000-000000000003',
      name: 'André Huanca',
      phone: '999111203',
      notes: 'Avisar cambios de horario.',
    ),
    Client(
      id: '30000000-0000-4000-8000-000000000004',
      name: 'Renato Apaza',
      phone: '999111204',
    ),
  ];
  var day = peruNow();
  if (day.weekday == 7) day = day.add(const Duration(days: 1));
  DateTime at(int h, int m) =>
      peruToUtc(DateTime(day.year, day.month, day.day, h, m));
  Appointment ap(
    int index,
    int client,
    int barber,
    int service,
    DateTime t,
    AppointmentStatus status,
  ) => Appointment(
    id: '40000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
    clientId: clients[client].id,
    barberId: barbers[barber].id,
    serviceId: services[service].id,
    serviceName: services[service].name,
    priceCents: services[service].priceCents,
    minutes: services[service].minutes,
    start: t,
    status: status,
  );
  return DataSnapshot(
    services: services.toList(),
    barbers: barbers.toList(),
    clients: clients.toList(),
    appointments: [
      ap(1, 0, 0, 0, at(9, 30), AppointmentStatus.completed),
      ap(2, 1, 1, 2, at(11, 0), AppointmentStatus.confirmed),
      ap(3, 2, 0, 1, at(15, 0), AppointmentStatus.pending),
      ap(4, 3, 1, 0, at(17, 30), AppointmentStatus.confirmed),
      ap(
        5,
        0,
        0,
        2,
        at(10, 0).subtract(const Duration(days: 7)),
        AppointmentStatus.completed,
      ),
      ap(
        6,
        1,
        1,
        0,
        at(16, 0).subtract(const Duration(days: 14)),
        AppointmentStatus.completed,
      ),
    ],
  );
}
