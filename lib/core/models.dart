enum AppointmentStatus {
  pending('pending', 'Pendiente'),
  confirmed('confirmed', 'Confirmada'),
  completed('completed', 'Completada'),
  cancelled('cancelled', 'Cancelada'),
  noShow('no_show', 'No asistió');

  const AppointmentStatus(this.code, this.label);
  final String code, label;
  bool get blocks => this != cancelled && this != noShow;
  static AppointmentStatus parse(String value) =>
      values.firstWhere((s) => s.code == value);
}

class DomainError implements Exception {
  const DomainError(this.message);
  final String message;
  @override
  String toString() => message;
}

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.minutes,
    this.active = true,
  });
  final String id, name;
  final int priceCents, minutes;
  final bool active;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price_cents': priceCents,
    'duration_minutes': minutes,
    'active': active,
  };
  factory Service.fromJson(Map<String, dynamic> j) => Service(
    id: j['id'],
    name: j['name'],
    priceCents: j['price_cents'],
    minutes: j['duration_minutes'],
    active: j['active'],
  );
}

class Barber {
  const Barber({
    required this.id,
    required this.name,
    this.active = true,
    this.weekdays = const [1, 2, 3, 4, 5, 6],
    this.openMinute = 540,
    this.closeMinute = 1200,
  });
  final String id, name;
  final bool active;
  final List<int> weekdays;
  final int openMinute, closeMinute;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'active': active,
    'weekdays': weekdays,
    'open_minute': openMinute,
    'close_minute': closeMinute,
  };
  factory Barber.fromJson(Map<String, dynamic> j) => Barber(
    id: j['id'],
    name: j['name'],
    active: j['active'],
    weekdays: List<int>.from(j['weekdays']),
    openMinute: j['open_minute'],
    closeMinute: j['close_minute'],
  );
}

class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    this.notes = '',
  });
  final String id, name, phone, notes;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'notes': notes,
  };
  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'],
    name: j['name'],
    phone: j['phone'],
    notes: j['notes'] ?? '',
  );
}

class Appointment {
  const Appointment({
    required this.id,
    required this.clientId,
    required this.barberId,
    required this.serviceId,
    required this.serviceName,
    required this.priceCents,
    required this.minutes,
    required this.start,
    this.status = AppointmentStatus.pending,
    this.notes = '',
    this.version = 1,
  });
  final String id, clientId, barberId, serviceId, serviceName, notes;
  final int priceCents, minutes, version;
  final DateTime start;
  final AppointmentStatus status;
  DateTime get end => start.add(Duration(minutes: minutes));
  bool overlaps(DateTime other, int duration) =>
      status.blocks &&
      start.isBefore(other.add(Duration(minutes: duration))) &&
      end.isAfter(other);
  Appointment copy({
    DateTime? start,
    AppointmentStatus? status,
    String? notes,
    int? version,
  }) => Appointment(
    version: version ?? this.version,
    id: id,
    clientId: clientId,
    barberId: barberId,
    serviceId: serviceId,
    serviceName: serviceName,
    priceCents: priceCents,
    minutes: minutes,
    start: start ?? this.start,
    status: status ?? this.status,
    notes: notes ?? this.notes,
  );
  Map<String, dynamic> toJson() => {
    'version': version,
    'id': id,
    'client_id': clientId,
    'barber_id': barberId,
    'service_id': serviceId,
    'service_name': serviceName,
    'price_cents': priceCents,
    'duration_minutes': minutes,
    'starts_at': start.toUtc().toIso8601String(),
    'status': status.code,
    'notes': notes,
  };
  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
    version: j['version'] ?? 1,
    id: j['id'],
    clientId: j['client_id'],
    barberId: j['barber_id'],
    serviceId: j['service_id'],
    serviceName: j['service_name'],
    priceCents: j['price_cents'],
    minutes: j['duration_minutes'],
    start: DateTime.parse(j['starts_at']).toUtc(),
    status: AppointmentStatus.parse(j['status']),
    notes: j['notes'] ?? '',
  );
}

class DataSnapshot {
  const DataSnapshot({
    required this.services,
    required this.barbers,
    required this.clients,
    required this.appointments,
  });
  final List<Service> services;
  final List<Barber> barbers;
  final List<Client> clients;
  final List<Appointment> appointments;
  Map<String, dynamic> toJson() => {
    'services': services.map((x) => x.toJson()).toList(),
    'barbers': barbers.map((x) => x.toJson()).toList(),
    'clients': clients.map((x) => x.toJson()).toList(),
    'appointments': appointments.map((x) => x.toJson()).toList(),
  };
  factory DataSnapshot.fromJson(Map<String, dynamic> j) => DataSnapshot(
    services: (j['services'] as List)
        .map((x) => Service.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    barbers: (j['barbers'] as List)
        .map((x) => Barber.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    clients: (j['clients'] as List)
        .map((x) => Client.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    appointments: (j['appointments'] as List)
        .map((x) => Appointment.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
  );
}
