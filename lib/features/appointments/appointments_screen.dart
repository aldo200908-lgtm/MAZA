import 'package:flutter/material.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'appointment_editor.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime day = peruNow();
  bool week = false;
  String? barber;
  AppointmentStatus? status;
  @override
  Widget build(BuildContext context) {
    final monday = DateTime(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(days: day.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final shownDays = week ? days : [day];
    return PageBody(
      children: [
        PageHeading(
          'Tu agenda',
          'Cada turno tiene su lugar. Hora de Perú.',
          action: FilledButton.icon(
            onPressed: () =>
                showAppointmentEditor(context, widget.store, day: day),
            icon: const Icon(Icons.add, size: 19),
            label: const Text('Nueva cita'),
          ),
        ),
        Surface(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Anterior',
                    onPressed: () => setState(
                      () => day = day.subtract(Duration(days: week ? 7 : 1)),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: day,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => day = d);
                      },
                      child: Text(
                        '${dayLabel(day)} ${day.year}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Siguiente',
                    onPressed: () => setState(
                      () => day = day.add(Duration(days: week ? 7 : 1)),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: days
                    .map(
                      (d) => Expanded(
                        child: Semantics(
                          label: '${weekdaysEs[d.weekday - 1]} ${dayLabel(d)}',
                          selected: sameDay(d, day),
                          button: true,
                          child: InkWell(
                            onTap: () => setState(() => day = d),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: sameDay(d, day)
                                    ? ink
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    weekdaysEs[d.weekday - 1],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: sameDay(d, day)
                                          ? Colors.white70
                                          : muted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${d.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: sameDay(d, day)
                                          ? Colors.white
                                          : ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Día'),
                    selected: !week,
                    onSelected: (_) => setState(() => week = false),
                  ),
                  ChoiceChip(
                    label: const Text('Semana'),
                    selected: week,
                    onSelected: (_) => setState(() => week = true),
                  ),
                  TextButton(
                    onPressed: () => setState(() => day = peruNow()),
                    child: const Text('Hoy'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: barber ?? '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Barbero'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Todos los barberos'),
            ),
            ...widget.store.barbers.map(
              (x) => DropdownMenuItem(value: x.id, child: Text(x.name)),
            ),
          ],
          onChanged: (v) => setState(() => barber = v == '' ? null : v),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: FilterChip(
                  label: const Text('Todos'),
                  selected: status == null,
                  onSelected: (_) => setState(() => status = null),
                ),
              ),
              ...AppointmentStatus.values.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: FilterChip(
                    label: Text(s.label),
                    selected: status == s,
                    onSelected: (_) =>
                        setState(() => status = status == s ? null : s),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...shownDays.expand((d) {
          final appointments = widget.store
              .forDay(d)
              .where(
                (a) =>
                    (barber == null || a.barberId == barber) &&
                    (status == null || a.status == status),
              )
              .toList();
          return <Widget>[
            SectionTitle(
              '${weekdaysEs[d.weekday - 1]} ${dayLabel(d)}',
              trailing: Text(
                '${appointments.length} citas',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
            if (appointments.isEmpty)
              const EmptyState(
                title: 'Un espacio libre',
                message:
                    'No hay citas con estos filtros. Puedes crear una nueva.',
              )
            else
              ...appointments.map(
                (a) => AppointmentTile(
                  a,
                  widget.store,
                  onTap: () => showAppointmentDetails(context, widget.store, a),
                ),
              ),
          ];
        }),
      ],
    );
  }
}
