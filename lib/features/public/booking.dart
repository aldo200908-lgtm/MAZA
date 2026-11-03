import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../web/catalog.dart';
import '../../web/components.dart';
import '../../web/controller.dart';

class BarberLanding extends StatelessWidget {
  const BarberLanding({super.key, required this.controller});
  final WebController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller.catalog;
    if (c == null) {
      return LoadingOrError(
        error: controller.error,
        retry: () => controller.start(),
      );
    }
    return WebPage(
      children: [
        const Intro(
          'Un corte. Tu momento.',
          'Servicios con precio y duración claros. Elige el tuyo y encuentra un turno.',
        ),
        ...c.services.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const Icon(Icons.content_cut, color: orange),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${soles(s.priceCents)} · ${s.minutes} minutos',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () =>
                        context.go('/barberia/reservar?servicio=${s.id}'),
                    icon: const Icon(Icons.north_east, size: 17),
                    label: const Text('Elegir turno'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionTitle('Manos que conocen el oficio'),
        ...c.barbers.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: ink,
              child: Text(b.name.substring(0, 1), style: const TextStyle(
                color: paper, fontSize: 24, fontWeight: FontWeight.w800))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(b.weekdays.map((d) => weekdaysEs[d - 1]).join(' · '),
                style: const TextStyle(color: muted, fontSize: 11)),
              Text('${minuteLabel(b.openMinute)} a ${minuteLabel(b.closeMinute)}',
                style: const TextStyle(color: muted, fontSize: 12)),
            ])),
            const Icon(Icons.verified_outlined, color: orange, size: 22),
          ])),
        )),
        const SizedBox(height: 24),
        Text(c.business.address, style: const TextStyle(color: muted)),
        const SizedBox(height: 8),
        Text(
          c.business.policy,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.controller, required this.uri});
  final WebController controller;
  final Uri uri;
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime day = peruNow();
  String? filter;
  Future<List<BookingSlot>>? slots;
  String? _loadedService;
  int _slotGeneration = 0;
  final notes = TextEditingController();
  bool busy = false;
  String? error;
  String? get serviceId => widget.uri.queryParameters['servicio'];
  Appointment? get editing {
    final id = widget.uri.queryParameters['cita'];
    return id == null
        ? null
        : widget.controller.appointments.where((a) => a.id == id).firstOrNull;
  }

  Service? get service {
    final current = widget.controller.catalog?.services
        .where((s) => s.id == serviceId)
        .firstOrNull;
    final old = editing;
    return current ??
        (old == null
            ? null
            : Service(
                id: old.serviceId,
                name: old.serviceName,
                priceCents: old.priceCents,
                minutes: old.minutes,
              ));
  }

  BookingSlot? get selected {
    final start = DateTime.tryParse(widget.uri.queryParameters['turno'] ?? '');
    final barber = widget.uri.queryParameters['barbero'];
    return start == null || barber == null
        ? null
        : BookingSlot(barber, start.toUtc());
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant BookingScreen old) {
    super.didUpdateWidget(old);
    if (old.uri.queryParameters['servicio'] != serviceId ||
        old.uri.queryParameters['cita'] != widget.uri.queryParameters['cita'] ||
        (_loadedService == null && service != null)) {
      _prepare();
    }
  }

  void _prepare() {
    if (service != null) {
      _loadedService = serviceId;
      final t = selected;
      if (t != null) day = peruWall(t.start);
      if (editing != null) filter = editing!.barberId;
      slots = selected == null
          ? _nextAvailable(++_slotGeneration)
          : widget.controller.gateway.slots(
              serviceId!,
              day,
              barberId: filter,
              appointment: editing,
            );
    }
  }

  Future<List<BookingSlot>> _nextAvailable(int generation) async {
    final start = DateTime(day.year, day.month, day.day);
    for (var i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      final result = await widget.controller.gateway.slots(
        serviceId!,
        date,
        barberId: filter,
        appointment: editing,
      );
      if (result.isNotEmpty) {
        if (mounted && generation == _slotGeneration) {
          setState(() => day = date);
        }
        return result;
      }
    }
    return [];
  }

  void _reload() {
    _slotGeneration++;
    setState(() {
      error = null;
      slots = widget.controller.gateway.slots(
        serviceId!,
        day,
        barberId: filter,
        appointment: editing,
      );
    });
  }

  String _path({BookingSlot? slot}) => Uri(
    path: '/barberia/reservar',
    queryParameters: {
      'servicio': serviceId!,
      if (editing != null) 'cita': editing!.id,
      if (slot != null) 'barbero': slot.barberId,
      if (slot != null) 'turno': slot.start.toUtc().toIso8601String(),
    },
  ).toString();
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller.catalog;
    if (c == null) {
      return LoadingOrError(
        error: widget.controller.error,
        retry: () => widget.controller.start(),
      );
    }
    if (service == null) {
      return WebPage(
        children: [
          const Intro(
            'Elige tu servicio',
            'Empieza por el corte o cuidado que necesitas.',
          ),
          ...c.services.map(
            (s) => ListTile(
              title: Text(s.name),
              subtitle: Text('${soles(s.priceCents)} · ${s.minutes} min'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => context.go('/barberia/reservar?servicio=${s.id}'),
            ),
          ),
        ],
      );
    }
    if (widget.uri.queryParameters.containsKey('cita') && editing == null) {
      return const WebPage(
        children: [
          EmptyState(
            title: 'Cita no disponible',
            message:
                'Actualiza tu cuenta y selecciona una de tus citas futuras.',
          ),
        ],
      );
    }
    final s = service!, slot = selected;
    final a = editing;
    final days = List.generate(
      7,
      (i) => DateTime(
        peruNow().year,
        peruNow().month,
        peruNow().day,
      ).add(Duration(days: i)),
    );
    return WebPage(
      width: 760,
      children: [
        Intro(
          a == null ? 'Tu próximo buen corte.' : 'Cambiemos el horario.',
          '${a?.serviceName ?? s.name} · ${soles(a?.priceCents ?? s.priceCents)} · ${a?.minutes ?? s.minutes} minutos',
        ),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Text('1 Servicio'),
            Text('·'),
            Text('2 Horario'),
            Text('·'),
            Text('3 Confirmar'),
          ],
        ),
        const SizedBox(height: 22),
        if (slot == null) ...[
          if (a == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/barberia'),
                icon: const Icon(Icons.arrow_back, size: 17),
                label: const Text('Cambiar servicio'),
              ),
            ),
          if (a == null)
            DropdownButtonFormField<String>(
              initialValue: filter ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '¿Con quién te atiendes?',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Cualquiera disponible'),
                ),
                ...c.barbers.map(
                  (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                ),
              ],
              onChanged: (v) {
                filter = v == '' ? null : v;
                _reload();
              },
            ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: days
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${weekdaysEs[d.weekday - 1]} ${d.day}'),
                        selected: sameDay(day, d),
                        onSelected: (_) {
                          day = d;
                          _reload();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final now = peruNow();
                final first = DateTime(now.year, now.month, now.day);
                final date = await showDatePicker(
                  context: context,
                  initialDate: day.isBefore(first) ? first : day,
                  firstDate: first,
                  lastDate: first.add(const Duration(days: 90)),
                );
                if (date != null) {
                  day = date;
                  _reload();
                }
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text('Otra fecha · ${dayLabel(day)}'),
            ),
          ),
          const SectionTitle('Elige tu turno'),
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Hora de Perú. El precio no cambia por elegir un barbero.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          FutureBuilder<List<BookingSlot>>(
            key: const ValueKey('booking-slots'),
            future: slots,
            builder: (ctx, snapshot) {
              if (snapshot.hasError) {
                return EmptyState(
                  title: 'No pudimos consultar los turnos',
                  message: friendlyError(snapshot.error!),
                  action: TextButton(
                    onPressed: _reload,
                    child: const Text('Reintentar'),
                  ),
                );
              }
              if (snapshot.connectionState != ConnectionState.done ||
                  !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final list = snapshot.data!;
              if (list.isEmpty) {
                return const EmptyState(
                  title: 'Este día está completo',
                  message: 'Prueba otra fecha o selecciona otro barbero.',
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: list
                    .map(
                      (slot) => Semantics(
                        button: true,
                        label:
                            '${hm(peruWall(slot.start))} con ${widget.controller.barberName(slot.barberId)}',
                        child: OutlinedButton(
                          onPressed: () => context.go(_path(slot: slot)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(15),
                            side: const BorderSide(color: line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                hm(peruWall(slot.start)),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.controller
                                    .barberName(slot.barberId)
                                    .split(' ')
                                    .first,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ] else ...[
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todo listo para tu visita',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Text(
                  a?.serviceName ?? s.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${weekdaysEs[peruWall(slot.start).weekday - 1]} ${dayLabel(peruWall(slot.start))} · ${hm(peruWall(slot.start))}',
                ),
                const SizedBox(height: 8),
                Text('Con ${widget.controller.barberName(slot.barberId)}'),
                const SizedBox(height: 8),
                Text(c.business.address),
                const Divider(height: 32),
                Text(
                  '${soles(a?.priceCents ?? s.priceCents)} · ${a?.minutes ?? s.minutes} min',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sin pago online. El horario se comprueba de nuevo al confirmar.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!widget.controller.signedIn)
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Identifícate para guardar tu cita',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Conservaremos el servicio y el turno que elegiste.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => context.go(
                      Uri(
                        path: '/acceso',
                        queryParameters: {'volver': _path(slot: slot)},
                      ).toString(),
                    ),
                    child: Text(
                      widget.controller.demo
                          ? 'Usar cuenta de ejemplo'
                          : 'Ingresar o crear cuenta',
                    ),
                  ),
                ],
              ),
            )
          else if (widget.controller.customer == null)
            FilledButton(
              onPressed: () => context.go(
                Uri(
                  path: '/mi-cuenta',
                  queryParameters: {'volver': _path(slot: slot)},
                ).toString(),
              ),
              child: const Text('Completar mis datos'),
            )
          else ...[
            Text(
              'Reserva para ${widget.controller.customer!.name}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            if (a == null)
              TextField(
                controller: notes,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Algo que debamos saber (opcional)',
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(error!, style: const TextStyle(color: orange)),
              ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        String id;
                        if (a == null) {
                          final result = await widget.controller.book(
                            s.id,
                            slot,
                            notes.text,
                          );
                          id = result.id;
                        } else {
                          await widget.controller.changeBooking(
                            a,
                            start: slot.start,
                          );
                          id = a.id;
                        }
                        if (context.mounted) {
                          context.go('/barberia/confirmacion/$id');
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            busy = false;
                            error = friendlyError(e);
                          });
                        }
                      }
                    },
              child: Text(
                busy
                    ? 'Comprobando turno…'
                    : a == null
                    ? 'Confirmar mi cita'
                    : 'Guardar nuevo horario',
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: busy ? null : () => context.go(_path()),
            child: const Text('Elegir otro horario'),
          ),
        ],
      ],
    );
  }
}

class BookingConfirmation extends StatelessWidget {
  const BookingConfirmation({
    super.key,
    required this.controller,
    required this.id,
  });
  final WebController controller;
  final String id;
  @override
  Widget build(BuildContext context) {
    final a = controller.appointments.where((x) => x.id == id).firstOrNull;
    if (a == null) {
      return WebPage(
        children: [
          const Intro(
            'No encontramos esta cita',
            'Consulta tus reservas desde tu cuenta.',
          ),
          FilledButton(
            onPressed: () => context.go('/mi-cuenta'),
            child: const Text('Ir a mi cuenta'),
          ),
        ],
      );
    }
    return WebPage(
      width: 640,
      children: [
        const SizedBox(height: 18),
        const Icon(Icons.check_circle_outline, size: 60, color: orange),
        const SizedBox(height: 24),
        Intro(
          'Tu cita está guardada.',
          'Código ${a.id.substring(0, 8).toUpperCase()}',
        ),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(a.status),
              const SizedBox(height: 20),
              Text(
                a.serviceName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('${dayLabel(peruWall(a.start))} · ${hm(peruWall(a.start))}'),
              const SizedBox(height: 8),
              Text(
                '${controller.barberName(a.barberId)} · ${soles(a.priceCents)}',
              ),
              const SizedBox(height: 16),
              Text(
                controller.catalog!.business.address,
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/mi-cuenta/citas'),
          child: const Text('Ver mis citas'),
        ),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}
