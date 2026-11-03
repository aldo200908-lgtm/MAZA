import 'package:flutter/material.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../appointments/appointment_editor.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store, required this.onAgenda});
  final AppStore store;
  final VoidCallback onAgenda;
  @override
  Widget build(BuildContext context) {
    final today = store.forDay(peruNow());
    final active = today
        .where(
          (a) =>
              a.status == AppointmentStatus.pending ||
              a.status == AppointmentStatus.confirmed,
        )
        .toList();
    final done = today
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();
    final value = done.fold(0, (int sum, a) => sum + a.priceCents);
    return PageBody(
      children: [
        PageHeading(
          'Tu día, en orden.',
          '${weekdaysEs[peruNow().weekday - 1]} ${dayLabel(peruNow())} · Perú',
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    color: Color(0xFFE4B78C),
                    size: 21,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'A TU RITMO',
                    style: TextStyle(
                      color: Color(0xFFE4B78C),
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                active.isEmpty
                    ? 'Hay espacio para\nun buen día.'
                    : '${active.length} turnos por atender.\nVamos uno a uno.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  height: 1.15,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => showAppointmentEditor(context, store),
                icon: const Icon(Icons.add),
                label: const Text('Agendar cita'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat(
                c.maxWidth,
                '${today.where((a) => a.status.blocks).length}',
                'Citas de hoy',
                Icons.calendar_today_outlined,
              ),
              _stat(
                c.maxWidth,
                '${done.length}',
                'Completadas',
                Icons.check_circle_outline,
              ),
              _stat(
                c.maxWidth,
                soles(value),
                'Valor atendido',
                Icons.content_cut,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Valor de servicios completados; no representa pagos cobrados.',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        SectionTitle(
          'En la agenda',
          trailing: TextButton.icon(
            onPressed: onAgenda,
            icon: const Icon(Icons.north_east, size: 14),
            label: const Text('Ver todas'),
          ),
        ),
        if (active.isEmpty)
          const EmptyState(
            title: 'Todo al día',
            message: 'Aquí aparecerán tus próximas citas de hoy.',
          )
        else
          ...active.map(
            (a) => AppointmentTile(
              a,
              store,
              onTap: () => showAppointmentDetails(context, store, a),
            ),
          ),
        const SizedBox(height: 12),
        Surface(
          color: const Color(0xFFECEFE4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tips_and_updates_outlined, color: ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'El detalle hace la diferencia.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${store.clients.length} clientes en tu agenda. Guarda sus preferencias para la próxima visita.',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(double width, String value, String label, IconData icon) =>
      SizedBox(
        width: width >= 600 ? (width - 24) / 3 : (width - 12) / 2,
        child: Surface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 19, color: muted),
              const SizedBox(height: 14),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 23,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      );
}
