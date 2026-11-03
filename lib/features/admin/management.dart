import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../web/catalog.dart';
import '../../web/components.dart';
import '../../web/controller.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({super.key});
  @override
  Widget build(BuildContext context) => WebPage(
    children: [
      const Intro(
        'Todo, en su lugar.',
        'Las herramientas para llevar tu negocio.',
      ),
      ...[
        (
          'Barbería',
          'Servicios, precios, barberos y horarios',
          Icons.content_cut,
          '/admin/barberia',
        ),
        (
          'Clientes',
          'Fichas e historial de visitas',
          Icons.people_outline,
          '/admin/clientes',
        ),
        (
          'Stock',
          'Productos y solicitudes de compra',
          Icons.inventory_2_outlined,
          '/admin/stock',
        ),
        (
          'Alquileres',
          'Equipos y solicitudes por fechas',
          Icons.key_outlined,
          '/admin/alquileres',
        ),
        (
          'Pagos',
          'Estado del módulo de cobros',
          Icons.account_balance_wallet_outlined,
          '/admin/pagos',
        ),
        (
          'Configuración',
          'Nombre, ubicación y condiciones',
          Icons.tune,
          '/admin/configuracion',
        ),
      ].map(
        (v) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              leading: Icon(v.$3, color: orange),
              title: Text(
                v.$1,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(v.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(v.$4),
            ),
          ),
        ),
      ),
    ],
  );
}

class AdminCatalog extends StatelessWidget {
  const AdminCatalog({
    super.key,
    required this.controller,
    required this.rentals,
  });
  final WebController controller;
  final bool rentals;
  @override
  Widget build(BuildContext context) {
    final items = rentals
        ? controller.catalog!.rentals
        : controller.catalog!.products;
    final requests = controller.managementRequests
        .where((r) => r.kind == (rentals ? 'rental' : 'product'))
        .toList();
    return WebPage(
      children: [
        Intro(
          rentals ? 'Alquileres' : 'Stock de belleza',
          rentals
              ? 'Equipos y consultas de disponibilidad.'
              : 'Catálogo disponible y solicitudes de productos.',
        ),
        if (controller.demo)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Catálogo de demostración. Las solicitudes no descuentan stock ni confirman contratos.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ...items.map(
          (x) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              child: Row(
                children: [
                  Icon(
                    rentals
                        ? Icons.chair_outlined
                        : Icons.shopping_bag_outlined,
                    color: orange,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          x.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${soles(x.priceCents)}${rentals ? ' / día' : ' · ${x.units} unidades'}',
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (!rentals && x.units <= 3)
                    const Chip(
                      label: Text('Stock bajo', style: TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SectionTitle('Solicitudes de clientes'),
        if (requests.isEmpty)
          const EmptyState(
            title: 'No hay solicitudes',
            message:
                'Aquí aparecerán las consultas enviadas desde la web pública.',
          )
        else
          ...requests.map((r) => _request(context, r)),
      ],
    );
  }

  Widget _request(BuildContext context, CustomerRequest r) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.adminStore.clientName(r.clientId),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${r.itemName} · ${r.quantity} ${r.quantity == 1 ? 'unidad' : 'unidades'}',
          ),
          const SizedBox(height: 6),
          Text(
            '${r.label} · ${soles(r.amountCents)} estimados',
            style: const TextStyle(color: muted),
          ),
          if (r.startsOn != null)
            Text(
              '${dayLabel(r.startsOn!)} a ${dayLabel(r.endsOn!)}',
              style: const TextStyle(color: muted),
            ),
          if (r.status == 'pending') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => guarded(
                    context,
                    () => controller.resolveRequest(r, 'handled'),
                  ),
                  child: const Text('Marcar atendida'),
                ),
                TextButton(
                  onPressed: () => guarded(
                    context,
                    () => controller.resolveRequest(r, 'rejected'),
                  ),
                  child: const Text('No disponible'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class AdminPayments extends StatelessWidget {
  const AdminPayments({super.key});
  @override
  Widget build(BuildContext context) => const WebPage(
    children: [
      Intro('Pagos', 'Cobros y servicios tienen estados independientes.'),
      EmptyState(
        title: 'Sin cobros registrados',
        message:
            'Esta versión no realiza pagos online ni registra transacciones. Tus citas conservan el precio acordado.',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ],
  );
}

class BusinessSettings extends StatefulWidget {
  const BusinessSettings({super.key, required this.controller});
  final WebController controller;
  @override
  State<BusinessSettings> createState() => _BusinessSettingsState();
}

class _BusinessSettingsState extends State<BusinessSettings> {
  late final TextEditingController name, address, policy;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final b = widget.controller.catalog!.business;
    name = TextEditingController(text: b.name);
    address = TextEditingController(text: b.address);
    policy = TextEditingController(text: b.policy);
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    policy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebPage(
    width: 760,
    children: [
      const Intro(
        'Los detalles de tu negocio.',
        'Esta información aparece en la web pública.',
      ),
      TextField(
        controller: name,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Nombre del negocio'),
      ),
      fieldGap,
      TextField(
        controller: address,
        maxLength: 250,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Ubicación o dirección'),
      ),
      fieldGap,
      TextField(
        controller: policy,
        maxLength: 1000,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Condiciones de reserva y solicitudes',
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(error!, style: const TextStyle(color: orange)),
        ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await widget.controller.saveBusiness(
                    BusinessInfo(
                      name: name.text.trim(),
                      address: address.text.trim(),
                      policy: policy.text.trim(),
                    ),
                  );
                  if (context.mounted) {
                    notify(context, 'La información del negocio se guardó.');
                  }
                } catch (e) {
                  if (mounted) setState(() => error = friendlyError(e));
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: Text(busy ? 'Guardando…' : 'Guardar cambios'),
      ),
    ],
  );
}
