import 'package:maza/core/clock.dart';
import 'package:maza/core/models.dart';

void main() {
  if (soles(2590) != 'S/ 25.90') throw StateError('Formato PEN');
  if (peruWall(DateTime.utc(2030, 1, 8, 2)).day != 7) {
    throw StateError('Fecha Perú');
  }
  final a = Appointment(
    id: 'a',
    clientId: 'c',
    barberId: 'b',
    serviceId: 's',
    serviceName: 'Corte',
    priceCents: 2500,
    minutes: 30,
    start: DateTime.utc(2030, 1, 7, 15),
    status: AppointmentStatus.confirmed,
  );
  if (!a.overlaps(DateTime.utc(2030, 1, 7, 15, 15), 30)) {
    throw StateError('Conflicto');
  }
  if (a.overlaps(DateTime.utc(2030, 1, 7, 15, 30), 30)) {
    throw StateError('Límite contiguo');
  }
  if (Appointment.fromJson(a.toJson()).priceCents != 2500) {
    throw StateError('Serialización');
  }
  // Comprobaciones finalizadas sin excepciones.
}
