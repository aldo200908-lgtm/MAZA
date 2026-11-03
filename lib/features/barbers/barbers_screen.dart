import 'package:flutter/material.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../clients/clients_screen.dart';

class BarbersScreen extends StatefulWidget {
  const BarbersScreen({super.key, required this.store, this.onClients});
  final AppStore store;
  final VoidCallback? onClients;
  @override
  State<BarbersScreen> createState() => _BarbersScreenState();
}

class _BarbersScreenState extends State<BarbersScreen> {
  bool team = false;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      PageHeading(
        'El oficio, bien llevado.',
        'Servicios, equipo y clientes de tu barbería.',
      ),
      Surface(
        color: const Color(0xFFECEFE4),
        child: InkWell(
          onTap:
              widget.onClients ??
              () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ClientsScreen(store: widget.store),
                ),
              ),
          child: Row(
            children: [
              const Icon(Icons.people_outline, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tus clientes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${widget.store.clients.length} fichas · historial y preferencias',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
      const SizedBox(height: 22),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Servicios'),
            selected: !team,
            onSelected: (_) => setState(() => team = false),
          ),
          ChoiceChip(
            label: const Text('Barberos y horarios'),
            selected: team,
            onSelected: (_) => setState(() => team = true),
          ),
        ],
      ),
      SectionTitle(
        team ? 'El equipo' : 'Carta de servicios',
        trailing: IconButton(
          tooltip: team ? 'Añadir barbero' : 'Añadir servicio',
          onPressed: () => team
              ? showBarberEditor(context, widget.store)
              : showServiceEditor(context, widget.store),
          icon: const Icon(Icons.add_circle_outline, color: orange),
        ),
      ),
      if (team) ...[
        if (widget.store.barbers.isEmpty)
          const EmptyState(
            title: 'Forma tu equipo',
            message: 'Agrega un barbero y define sus días y horario.',
          ),
        ...widget.store.barbers.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: ink,
                        foregroundColor: Colors.white,
                        child: Text(b.name.substring(0, 1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          b.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar ${b.name}',
                        onPressed: () =>
                            showBarberEditor(context, widget.store, barber: b),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${b.weekdays.map((d) => weekdaysEs[d - 1]).join(' · ')}\n${minuteLabel(b.openMinute)}–${minuteLabel(b.closeMinute)} · Perú',
                    style: const TextStyle(color: muted, height: 1.7),
                  ),
                  if (!b.active)
                    const Text('Inactivo', style: TextStyle(color: orange)),
                ],
              ),
            ),
          ),
        ),
      ] else ...[
        if (widget.store.services.isEmpty)
          const EmptyState(
            title: 'Tu primer servicio',
            message: 'Agrega un nombre, precio y duración.',
          ),
        ...widget.store.services.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 52,
                    decoration: BoxDecoration(
                      color: s.active ? orange : line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${s.minutes} min${s.active ? '' : ' · Inactivo'}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          soles(s.priceCents),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar ${s.name}',
                    onPressed: () =>
                        showServiceEditor(context, widget.store, service: s),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
      const Text(
        'Desactiva servicios o barberos para ocultarlos al reservar. Las citas existentes conservan su historial.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );
}

Future<void> showServiceEditor(
  BuildContext context,
  AppStore store, {
  Service? service,
}) async {
  final name = TextEditingController(text: service?.name ?? ''),
      price = TextEditingController(
        text: ((service?.priceCents ?? 0) / 100).toStringAsFixed(2),
      ),
      duration = TextEditingController(text: '${service?.minutes ?? 30}');
  bool active = service?.active ?? true;
  try {
    await showMazaForm(
      context,
      title: service == null ? 'Nuevo servicio' : 'Editar servicio',
      fields: (ctx, set) => Column(
        children: [
          TextFormField(
            controller: name,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Nombre del servicio'),
            validator: requiredText,
          ),
          fieldGap,
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio en soles',
              prefixText: 'S/ ',
            ),
            validator: (v) =>
                RegExp(r'^\d{1,6}([.,]\d{1,2})?$').hasMatch(v ?? '')
                ? null
                : 'Ejemplo: 25.00',
          ),
          fieldGap,
          TextFormField(
            controller: duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duración en minutos'),
            validator: (v) {
              final n = int.tryParse(v ?? '') ?? 0;
              return n >= 5 && n <= 480 ? null : 'Entre 5 y 480 minutos';
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Servicio activo'),
            value: active,
            onChanged: (v) => set(() => active = v),
          ),
        ],
      ),
      save: () => store.saveService(
        Service(
          id: service?.id ?? store.newId,
          name: name.text.trim(),
          priceCents: (double.parse(price.text.replaceAll(',', '.')) * 100)
              .round(),
          minutes: int.parse(duration.text),
          active: active,
        ),
      ),
    );
  } finally {
    name.dispose();
    price.dispose();
    duration.dispose();
  }
}

Future<void> showBarberEditor(
  BuildContext context,
  AppStore store, {
  Barber? barber,
}) async {
  final name = TextEditingController(text: barber?.name ?? '');
  bool active = barber?.active ?? true;
  var days = [
    ...barber?.weekdays ?? [1, 2, 3, 4, 5, 6],
  ];
  var open = barber?.openMinute ?? 540, close = barber?.closeMinute ?? 1200;
  try {
    await showMazaForm(
      context,
      title: barber == null ? 'Nuevo barbero' : 'Editar barbero',
      fields: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: name,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Nombre del barbero'),
            validator: requiredText,
          ),
          fieldGap,
          const Text('Días de atención'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            children: List.generate(
              7,
              (i) => FilterChip(
                label: Text(weekdaysEs[i]),
                selected: days.contains(i + 1),
                onSelected: (v) => set(() {
                  if (v) {
                    days.add(i + 1);
                  } else {
                    days.remove(i + 1);
                  }
                  days.sort();
                }),
              ),
            ),
          ),
          fieldGap,
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text('Abre ${minuteLabel(open)}'),
            onPressed: () async {
              final t = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay(hour: open ~/ 60, minute: open % 60),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (t != null) set(() => open = t.hour * 60 + t.minute);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text('Cierra ${minuteLabel(close)}'),
            onPressed: () async {
              final t = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay(hour: close ~/ 60, minute: close % 60),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (t != null) set(() => close = t.hour * 60 + t.minute);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Un intervalo diario para los días seleccionados. Hora de Perú.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Barbero activo'),
            value: active,
            onChanged: (v) => set(() => active = v),
          ),
        ],
      ),
      save: () => store.saveBarber(
        Barber(
          id: barber?.id ?? store.newId,
          name: name.text.trim(),
          weekdays: days,
          openMinute: open,
          closeMinute: close,
          active: active,
        ),
      ),
    );
  } finally {
    name.dispose();
  }
}
