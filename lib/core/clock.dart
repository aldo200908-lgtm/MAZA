// Perú usa UTC−05 todo el año. Los DateTime de pared nunca se convierten
// usando la zona del dispositivo: solo se leen sus componentes.
DateTime peruWall(DateTime instant) {
  final p = instant.toUtc().subtract(const Duration(hours: 5));
  return DateTime(p.year, p.month, p.day, p.hour, p.minute);
}

DateTime peruToUtc(DateTime wall) => DateTime.utc(
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
).add(const Duration(hours: 5));
DateTime peruNow() => peruWall(DateTime.now());
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String soles(int cents) => 'S/ ${(cents / 100).toStringAsFixed(2)}';
String hm(DateTime wall) =>
    '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
String minuteLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
const weekdaysEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const monthsEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
String dayLabel(DateTime day) => '${day.day} de ${monthsEs[day.month - 1]}';
