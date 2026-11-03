import 'package:flutter/material.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../appointments/appointment_editor.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String search = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final clients =
          widget.store.clients
              .where(
                (c) => '${c.name} ${c.phone}'.toLowerCase().contains(
                  search.toLowerCase(),
                ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return Scaffold(
        appBar: AppBar(title: const Text('Clientes')),
        body: PageBody(
          children: [
            PageHeading(
              'Cada cliente cuenta.',
              'Sus visitas y preferencias, a mano.',
              action: FilledButton.icon(
                onPressed: () => showClientEditor(context, widget.store),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Nuevo cliente'),
              ),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o celular',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
            const SizedBox(height: 18),
            if (clients.isEmpty)
              const EmptyState(
                title: 'Sin resultados',
                message: 'Prueba otro nombre o agrega un cliente.',
                icon: Icons.people_outline,
              )
            else
              ...clients.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Surface(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: paper,
                        child: Text(
                          c.name.substring(0, 1),
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(c.phone),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ClientHistoryScreen(
                            store: widget.store,
                            clientId: c.id,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class ClientHistoryScreen extends StatelessWidget {
  const ClientHistoryScreen({
    super.key,
    required this.store,
    required this.clientId,
  });
  final AppStore store;
  final String clientId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final c = store.clients.firstWhere((x) => x.id == clientId),
          history = store.history(clientId);
      final done = history
          .where((a) => a.status == AppointmentStatus.completed)
          .length;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Historial del cliente'),
          actions: [
            IconButton(
              tooltip: 'Editar cliente',
              onPressed: () => showClientEditor(context, store, client: c),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: PageBody(
          children: [
            PageHeading(c.name, c.phone),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$done visitas completadas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    c.notes.isEmpty ? 'Sin preferencias registradas.' : c.notes,
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            const SectionTitle('Historial de citas'),
            if (history.isEmpty)
              const EmptyState(
                title: 'La primera visita está por llegar',
                message: 'Aquí quedarán sus servicios, precios y estados.',
              )
            else
              ...history.expand(
                (a) => [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                    child: Text(
                      '${dayLabel(peruWall(a.start))} ${peruWall(a.start).year}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  AppointmentTile(
                    a,
                    store,
                    onTap: () => showAppointmentDetails(context, store, a),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

Future<String?> showClientEditor(
  BuildContext context,
  AppStore store, {
  Client? client,
}) async {
  final name = TextEditingController(text: client?.name ?? ''),
      phone = TextEditingController(text: client?.phone ?? ''),
      notes = TextEditingController(text: client?.notes ?? '');
  final id = client?.id ?? store.newId;
  try {
    final saved = await showMazaForm(
      context,
      title: client == null ? 'Nuevo cliente' : 'Editar cliente',
      fields: (ctx, _) => Column(
        children: [
          TextFormField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Nombre y apellidos'),
            validator: requiredText,
          ),
          fieldGap,
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Celular',
              hintText: '987654321',
            ),
            validator: (v) =>
                RegExp(r'^(\+51\s?)?9\d{8}$').hasMatch(v?.trim() ?? '')
                ? null
                : 'Celular peruano de 9 dígitos',
          ),
          fieldGap,
          TextFormField(
            controller: notes,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Preferencias y notas (opcional)',
            ),
          ),
        ],
      ),
      save: () => store.saveClient(
        Client(
          id: id,
          name: name.text.trim(),
          phone: phone.text.trim(),
          notes: notes.text.trim(),
        ),
      ),
    );
    return saved ? id : null;
  } finally {
    name.dispose();
    phone.dispose();
    notes.dispose();
  }
}
