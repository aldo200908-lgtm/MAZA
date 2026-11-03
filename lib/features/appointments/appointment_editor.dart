import 'package:flutter/material.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';
import '../clients/clients_screen.dart';

Future<void> showAppointmentEditor(
  BuildContext context,
  AppStore store, {
  DateTime? day,
  Appointment? existing,
}) async {
  if (store.clients.isEmpty ||
      store.services.where((x) => x.active).isEmpty ||
      store.barbers.where((x) => x.active).isEmpty) {
    notify(
      context,
      'Primero agrega un cliente, un servicio y un barbero activo.',
    );
    return;
  }
  final notes = TextEditingController(text: existing?.notes ?? '');
  var chosenDay = existing == null
      ? (day ?? peruNow())
      : peruWall(existing.start);
  String clientId = existing?.clientId ?? store.clients.first.id;
  String serviceId =
      existing?.serviceId ?? store.services.firstWhere((x) => x.active).id;
  String barberId =
      existing?.barberId ?? store.barbers.firstWhere((x) => x.active).id;
  TimeOfDay? time = existing == null
      ? null
      : TimeOfDay.fromDateTime(peruWall(existing.start));
  try {
    await showMazaForm(
      context,
      title: existing == null ? 'Nueva cita' : 'Reprogramar cita',
      submit: existing == null ? 'Crear cita' : 'Guardar cambios',
      fields: (ctx, update) {
        final duration =
            existing?.minutes ??
            store.services.firstWhere((x) => x.id == serviceId).minutes;
        final price =
            existing?.priceCents ??
            store.services.firstWhere((x) => x.id == serviceId).priceCents;
        final slots = <int>[];
        for (var m = 0; m < 24 * 60; m += 15) {
          final t = peruToUtc(
            DateTime(
              chosenDay.year,
              chosenDay.month,
              chosenDay.day,
              m ~/ 60,
              m % 60,
            ),
          );
          if (store.slotAvailable(
            barberId,
            t,
            duration,
            excluding: existing?.id,
          )) {
            slots.add(m);
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (existing == null) ...[
              DropdownButtonFormField<String>(
                initialValue: clientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cliente'),
                items: store.clients
                    .map(
                      (x) => DropdownMenuItem(
                        value: x.id,
                        child: Text(x.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => update(() => clientId = v!),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final id = await showClientEditor(ctx, store);
                    if (id != null && ctx.mounted) update(() => clientId = id);
                  },
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Nuevo cliente'),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: serviceId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Servicio'),
                items: store.services
                    .where((x) => x.active)
                    .map(
                      (x) => DropdownMenuItem(
                        value: x.id,
                        child: Text(x.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => update(() {
                  serviceId = v!;
                  time = null;
                }),
              ),
              fieldGap,
              DropdownButtonFormField<String>(
                initialValue: barberId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Barbero'),
                items: store.barbers
                    .where((x) => x.active)
                    .map(
                      (x) => DropdownMenuItem(value: x.id, child: Text(x.name)),
                    )
                    .toList(),
                onChanged: (v) => update(() {
                  barberId = v!;
                  time = null;
                }),
              ),
            ] else
              Text(
                '${store.clientName(existing.clientId)} · ${existing.serviceName}\n${store.barberName(existing.barberId)}',
              ),
            fieldGap,
            Text('${soles(price)} · $duration minutos'),
            fieldGap,
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: ctx,
                  initialDate: chosenDay,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected != null) {
                  update(() {
                    chosenDay = selected;
                    time = null;
                  });
                }
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(dayLabel(chosenDay)),
            ),
            fieldGap,
            Text(
              'Horarios disponibles · hora de Perú',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (slots.isEmpty)
              const Text(
                'No quedan horarios para este servicio. Elige otro día o barbero.',
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 4,
                children: slots
                    .map(
                      (m) => ChoiceChip(
                        label: Text(minuteLabel(m)),
                        selected:
                            time?.hour == m ~/ 60 && time?.minute == m % 60,
                        onSelected: (_) => update(
                          () => time = TimeOfDay(hour: m ~/ 60, minute: m % 60),
                        ),
                      ),
                    )
                    .toList(),
              ),
            fieldGap,
            TextFormField(
              controller: notes,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
          ],
        );
      },
      save: () async {
        if (time == null) {
          throw const DomainError('Selecciona un horario disponible.');
        }
        final start = peruToUtc(
          DateTime(
            chosenDay.year,
            chosenDay.month,
            chosenDay.day,
            time!.hour,
            time!.minute,
          ),
        );
        if (existing == null) {
          await store.book(
            clientId: clientId,
            serviceId: serviceId,
            barberId: barberId,
            start: start,
            notes: notes.text,
          );
        } else {
          await store.reschedule(existing, start, notes.text);
        }
      },
    );
  } finally {
    notes.dispose();
  }
}

Future<void> showAppointmentDetails(
  BuildContext context,
  AppStore store,
  Appointment a,
) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: store,
      builder: (ctx, _) {
        final current = store.appointments.firstWhere((x) => x.id == a.id);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.clientName(a.clientId),
                      style: Theme.of(ctx).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('${current.serviceName} · ${soles(current.priceCents)}'),
              const SizedBox(height: 8),
              Text(
                '${dayLabel(peruWall(current.start))} · ${hm(peruWall(current.start))}–${hm(peruWall(current.end))}',
              ),
              const SizedBox(height: 8),
              Text('Con ${store.barberName(a.barberId)}'),
              if (current.notes.isNotEmpty) ...[fieldGap, Text(current.notes)],
              fieldGap,
              StatusPill(current.status),
              fieldGap,
              const Text('Estado de la cita'),
              DropdownButton<AppointmentStatus>(
                value: current.status,
                isExpanded: true,
                items: AppointmentStatus.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    )
                    .toList(),
                onChanged: (v) =>
                    guarded(ctx, () => store.changeStatus(current, v!)),
              ),
              fieldGap,
              if (current.status != AppointmentStatus.completed)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showAppointmentEditor(context, store, existing: current);
                  },
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Reprogramar / editar notas'),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ),
  );
}
