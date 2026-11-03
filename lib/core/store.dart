import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'clock.dart';
import 'models.dart';
import 'repository.dart';

class AppStore extends ChangeNotifier {
  AppStore(this.repository);
  final MazaRepository repository;
  bool get isDemo => repository.isDemo;
  List<Service> _services = [];
  List<Barber> _barbers = [];
  List<Client> _clients = [];
  List<Appointment> _appointments = [];
  List<Service> get services => List.unmodifiable(_services);
  List<Barber> get barbers => List.unmodifiable(_barbers);
  List<Client> get clients => List.unmodifiable(_clients);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  int _epoch = 0;
  void clear() {
    _epoch++;
    _services = [];
    _barbers = [];
    _clients = [];
    _appointments = [];
  }

  bool _writing = false;
  bool _loading = false;
  Future<void> load() async {
    if (_writing || _loading) {
      throw const DomainError('Hay una operación en curso. Espera un momento.');
    }
    _loading = true;
    final epoch = _epoch;
    try {
      final d = await repository.load();
      if (epoch != _epoch) return;
      _services = d.services;
      _barbers = d.barbers;
      _clients = d.clients;
      _appointments = d.appointments;
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  String get newId => const Uuid().v4();
  String clientName(String id) =>
      _clients.where((x) => x.id == id).firstOrNull?.name ?? 'Cliente';
  String barberName(String id) =>
      _barbers.where((x) => x.id == id).firstOrNull?.name ?? 'Barbero';
  List<Appointment> forDay(DateTime day) =>
      _appointments.where((a) => sameDay(peruWall(a.start), day)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  List<Appointment> history(String clientId) =>
      _appointments.where((a) => a.clientId == clientId).toList()
        ..sort((a, b) => b.start.compareTo(a.start));
  void _validateSlot(Appointment a, {bool checkActive = true}) {
    final b = _barbers.where((b) => b.id == a.barberId).firstOrNull;
    if (b == null || (checkActive && !b.active)) {
      throw const DomainError('Selecciona un barbero activo.');
    }
    final w = peruWall(a.start), e = peruWall(a.end);
    if (!b.weekdays.contains(w.weekday) ||
        !sameDay(w, e) ||
        w.hour * 60 + w.minute < b.openMinute ||
        e.hour * 60 + e.minute > b.closeMinute) {
      throw const DomainError(
        'La cita debe quedar completa dentro del horario del barbero.',
      );
    }
    if (_appointments.any(
      (x) =>
          x.id != a.id &&
          x.barberId == a.barberId &&
          x.overlaps(a.start, a.minutes),
    )) {
      throw const DomainError('Ese barbero ya tiene una cita en ese horario.');
    }
  }

  bool slotAvailable(
    String barberId,
    DateTime start,
    int minutes, {
    String? excluding,
  }) {
    try {
      _validateSlot(
        Appointment(
          id: excluding ?? '',
          clientId: '',
          barberId: barberId,
          serviceId: '',
          serviceName: '',
          priceCents: 0,
          minutes: minutes,
          start: start,
        ),
      );
      return true;
    } on DomainError {
      return false;
    }
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    if (_writing || _loading) {
      throw const DomainError('Hay un cambio en curso. Espera un momento.');
    }
    _writing = true;
    final epoch = _epoch;
    try {
      final result = await action();
      if (epoch != _epoch) {
        clear();
        throw const DomainError('Tu sesión cambió. Ingresa de nuevo.');
      }
      notifyListeners();
      return result;
    } finally {
      _writing = false;
    }
  }

  Future<Appointment> book({
    required String clientId,
    required String serviceId,
    required String barberId,
    required DateTime start,
    String notes = '',
  }) => _write(() async {
    final s = _services.where((s) => s.id == serviceId && s.active).firstOrNull;
    if (s == null) throw const DomainError('Selecciona un servicio activo.');
    if (!_clients.any((c) => c.id == clientId)) {
      throw const DomainError('Selecciona un cliente.');
    }
    final a = Appointment(
      id: newId,
      clientId: clientId,
      serviceId: s.id,
      barberId: barberId,
      serviceName: s.name,
      priceCents: s.priceCents,
      minutes: s.minutes,
      start: start.toUtc(),
      notes: notes.trim(),
    );
    _validateSlot(a);
    final saved = await repository.saveAppointment(a, isNew: true);
    _appointments = [..._appointments, saved];
    return saved;
  });
  Future<void> changeStatus(Appointment a, AppointmentStatus status) =>
      _write(() async {
        final current = _appointments.firstWhere((x) => x.id == a.id);
        final updated = current.copy(status: status);
        if (status.blocks && !current.status.blocks) _validateSlot(updated);
        final saved = await repository.saveAppointment(updated, isNew: false);
        _appointments = _appointments
            .map((x) => x.id == saved.id ? saved : x)
            .toList();
      });
  Future<void> reschedule(Appointment a, DateTime start, String notes) =>
      _write(() async {
        final current = _appointments.firstWhere((x) => x.id == a.id);
        if (current.status == AppointmentStatus.completed) {
          throw const DomainError(
            'Una cita completada conserva su fecha histórica.',
          );
        }
        final updated = current.copy(start: start.toUtc(), notes: notes.trim());
        _validateSlot(updated);
        final saved = await repository.saveAppointment(updated, isNew: false);
        _appointments = _appointments
            .map((x) => x.id == saved.id ? saved : x)
            .toList();
      });
  Future<void> saveService(Service s) => _write(() async {
    if (s.name.trim().isEmpty ||
        s.priceCents < 0 ||
        s.minutes < 5 ||
        s.minutes > 480) {
      throw const DomainError('Revisa nombre, precio y duración (5–480 min).');
    }
    final v = await repository.saveService(s);
    _services = [..._services.where((x) => x.id != v.id), v];
  });
  Future<void> saveBarber(Barber b) => _write(() async {
    if (b.name.trim().isEmpty ||
        b.weekdays.isEmpty ||
        b.openMinute < 0 ||
        b.closeMinute > 1439 ||
        b.closeMinute <= b.openMinute) {
      throw const DomainError('Revisa los días y el horario del barbero.');
    }
    final v = await repository.saveBarber(b);
    _barbers = [..._barbers.where((x) => x.id != v.id), v];
  });
  Future<void> saveClient(Client c) => _write(() async {
    if (c.name.trim().isEmpty ||
        !RegExp(r'^(\+51\s?)?9\d{8}$').hasMatch(c.phone.trim())) {
      throw const DomainError(
        'Ingresa un nombre y un celular peruano de 9 dígitos.',
      );
    }
    if (_clients.any(
      (x) =>
          x.id != c.id &&
          x.phone
                  .replaceAll(RegExp(r'\D'), '')
                  .replaceFirst(RegExp(r'^51'), '') ==
              c.phone
                  .replaceAll(RegExp(r'\D'), '')
                  .replaceFirst(RegExp(r'^51'), ''),
    )) {
      throw const DomainError('Ya existe un cliente con ese celular.');
    }
    final v = await repository.saveClient(c);
    _clients = [..._clients.where((x) => x.id != v.id), v];
  });
}
