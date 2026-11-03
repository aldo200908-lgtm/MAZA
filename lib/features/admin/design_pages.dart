import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../web/catalog.dart';
import '../../web/components.dart';
import '../../web/controller.dart';
import '../appointments/appointment_editor.dart';
import 'design_store.dart';

const _sage = Color(0xFFE8EDDF);
const _peach = Color(0xFFF4E4D9);
const _blue = Color(0xFFE8EDF2);

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 20),
    child: Row(children: [
      Icon(Icons.science_outlined, size: 17, color: muted),
      SizedBox(width: 8),
      Expanded(child: Text('Demo interactiva · datos de ejemplo. Los cobros y contratos son simulados.',
          style: TextStyle(color: muted, fontSize: 12))),
    ]),
  );
}
class StudioMetrics extends StatelessWidget {
  const StudioMetrics(this.values, {super.key});
  final List<(String, String, IconData)> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, b) {
    final columns = b.maxWidth >= 860 ? 4 : b.maxWidth >= 300 ? 2 : 1;
    return Wrap(spacing: 12, runSpacing: 12, children: values.map((v) => SizedBox(
      width: (b.maxWidth - 12 * (columns - 1)) / columns,
      child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(v.$3, size: 19, color: muted), const Spacer(),
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: orange, shape: BoxShape.circle))]),
        const SizedBox(height: 18),
        SizedBox(height: 36, child: FittedBox(alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown, child: Text(v.$1,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)))),
        const SizedBox(height: 6),
        Text(v.$2, style: const TextStyle(color: muted, fontSize: 12)),
      ])),
    )).toList());
  });
}
class StudioTabs extends StatelessWidget {
  const StudioTabs(this.labels, this.selected, this.onSelect, {super.key});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: SingleChildScrollView(scrollDirection: Axis.horizontal,
      child: Row(children: List.generate(labels.length, (i) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(labels[i]), selected: selected == i,
          onSelected: (_) => onSelect(i)),
      )))),
  );
}
class StudioBadge extends StatelessWidget {
  const StudioBadge(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: warning ? _peach : _sage,
      borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
      color: warning ? orange : const Color(0xFF4F6242))),
  );
}
class StudioOverview extends StatelessWidget {
  const StudioOverview({super.key, required this.controller});
  final WebController controller;
  @override
  Widget build(BuildContext context) {
    final ops = controller.operations!;
    final store = controller.adminStore;
    final appointments = store.forDay(peruNow());
    final upcoming = appointments.where((a) =>
      [AppointmentStatus.pending, AppointmentStatus.confirmed].contains(a.status)).toList();
    return AnimatedBuilder(animation: ops, builder: (ctx, _) => WebPage(children: [
      Intro('Tu negocio, en orden.', '${dayLabel(peruNow())} · Una mirada a lo que sigue.',
        action: FilledButton.icon(onPressed: () => showAppointmentEditor(context, store),
          icon: const Icon(Icons.add, size: 19), label: const Text('Nueva cita'))),
      const DemoNotice(),
      StudioMetrics([
        (appointments.length.toString(), 'Citas de hoy', Icons.calendar_today_outlined),
        (soles(ops.collected), 'Cobros de ejemplo', Icons.account_balance_wallet_outlined),
        (ops.openRentals.toString(), 'Equipos entregados', Icons.key_outlined),
        (ops.lowStock.toString(), 'Productos por reponer', Icons.inventory_2_outlined),
      ]),
      const SizedBox(height: 22),
      Surface(color: ink, padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('El día, bajo control.', style: TextStyle(color: paper, fontSize: 26,
          fontWeight: FontWeight.w800, letterSpacing: -.7)),
        const SizedBox(height: 10),
        Text(upcoming.isEmpty ? 'Tu agenda está al día. Puedes preparar los próximos turnos.'
          : 'Tienes ${upcoming.length} turnos por atender. Revisa la agenda y confirma lo pendiente.',
          style: const TextStyle(color: Colors.white70, height: 1.6)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton(onPressed: () => context.go('/admin/citas'), child: const Text('Abrir agenda')),
          TextButton(onPressed: () => context.go('/admin/reportes'),
            style: TextButton.styleFrom(foregroundColor: paper),
            child: const Text('Ver reportes ↗')),
        ]),
      ])),
      SectionTitle('Lo que necesita tu atención', trailing: IconButton(
        tooltip: 'Ver avisos', onPressed: () => context.go('/admin/avisos'),
        icon: const Icon(Icons.notifications_none))),
      Surface(padding: EdgeInsets.zero, child: Column(children: [
        _attention(context, Icons.inventory_2_outlined, '${ops.lowStock} productos con pocas unidades',
          'Revisa existencias y registra una entrada.', '/admin/stock'),
        const Divider(height: 1),
        _attention(context, Icons.event_repeat_outlined, 'Una devolución por coordinar',
          'Consulta fechas, garantías y entrega de equipos.', '/admin/alquileres'),
        const Divider(height: 1),
        _attention(context, Icons.payments_outlined, '${soles(ops.outstanding)} por cobrar en el ejemplo',
          'Distingue los abonos del saldo pendiente.', '/admin/pagos'),
      ])),
      SectionTitle('Próximas citas', trailing: TextButton(
        onPressed: () => context.go('/admin/citas'), child: const Text('Ver agenda'))),
      if (upcoming.isEmpty)
        const EmptyState(title: 'Tienes espacio para nuevas visitas',
          message: 'Crea una cita o explora los demás módulos.')
      else ...upcoming.map((a) => AppointmentTile(a, store,
        onTap: () => showAppointmentDetails(context, store, a))),
      const SectionTitle('Un acceso para cada tarea'),
      _links(context, [
        ('Servicios y equipo', 'Precios, duración y horarios', Icons.content_cut, '/admin/barberia'),
        ('Clientes', 'Historial y preferencias', Icons.people_outline, '/admin/clientes'),
        ('Tu catálogo', 'Lo que ven tus clientes', Icons.storefront_outlined, '/productos'),
      ]),
    ]));
  }
  Widget _attention(BuildContext ctx, IconData icon, String title, String text, String route) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    leading: Icon(icon, color: orange), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(text, style: const TextStyle(fontSize: 12)), trailing: const Icon(Icons.chevron_right),
    onTap: () => ctx.go(route));
}
Widget _links(BuildContext context, List<(String, String, IconData, String)> links) =>
  Column(children: links.map((x) => Padding(padding: const EdgeInsets.only(bottom: 10),
    child: Surface(padding: EdgeInsets.zero, child: ListTile(
      contentPadding: const EdgeInsets.all(16), leading: Icon(x.$3, color: orange),
      title: Text(x.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(x.$2), trailing: const Icon(Icons.north_east, size: 18),
      onTap: () => context.go(x.$4))))).toList());

class StudioInventory extends StatefulWidget {
  const StudioInventory({super.key, required this.controller, this.rentals = false});
  final WebController controller;
  final bool rentals;
  @override
  State<StudioInventory> createState() => _StudioInventoryState();
}
class _StudioInventoryState extends State<StudioInventory> {
  int tab = 0;
  String query = '', category = 'Todos';
  DesignOperations get ops => widget.controller.operations!;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: ops, builder: (ctx, _) {
    final rental = widget.rentals;
    final items = rental ? ops.rentalItems : ops.products;
    final categories = ['Todos', ...items.map((i) => i.category).toSet()];
    final shown = items.where((i) => i.name.toLowerCase().contains(query.toLowerCase()) &&
      (category == 'Todos' || category == i.category)).toList();
    return WebPage(children: [
      Intro(rental ? 'El equipo sigue en movimiento.' : 'Cada producto, en su lugar.',
        rental ? 'Reservas, entregas y devoluciones, sin perder el hilo.'
          : 'Tu inventario de belleza. Existencias claras, decisiones simples.',
        action: FilledButton.icon(onPressed: () => _openForm(context, ops, 'item',
          rental: rental), icon: const Icon(Icons.add, size: 19),
          label: Text(rental ? 'Añadir equipo' : 'Añadir producto'))),
      const DemoNotice(),
      StudioMetrics(rental ? [
        (items.length.toString(), 'Equipos en catálogo', Icons.chair_outlined),
        (ops.openRentals.toString(), 'En uso', Icons.key_outlined),
        (ops.rentals.where((r) => r.status == 'Reservado').length.toString(),
          'Reservas previstas', Icons.event_available_outlined),
        (ops.rentals.where((r) => r.status == 'Devuelto').length.toString(),
          'Devoluciones completas', Icons.assignment_turned_in_outlined),
      ] : [
        (items.length.toString(), 'Productos', Icons.shopping_bag_outlined),
        (items.fold(0, (int sum, p) => sum + p.units).toString(), 'Unidades disponibles', Icons.inventory_2_outlined),
        (ops.lowStock.toString(), 'Por reponer', Icons.priority_high),
        (soles(ops.inventoryValue), 'Valor de venta del stock', Icons.sell_outlined),
      ]),
      StudioTabs(rental ? ['Equipos', 'Reservas', 'Solicitudes'] :
        ['Productos', 'Movimientos', 'Solicitudes'], tab, (i) => setState(() => tab = i)),
      if (tab == 0) ...[
        TextField(onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
            hintText: rental ? 'Buscar un equipo' : 'Buscar un producto')),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
          children: categories.map((s) => Padding(padding: const EdgeInsets.only(right: 7),
            child: FilterChip(label: Text(s), selected: category == s,
              onSelected: (_) => setState(() => category = s)))).toList())),
        const SizedBox(height: 20),
        if (shown.isEmpty) const EmptyState(title: 'No encontramos coincidencias',
          message: 'Prueba otro nombre o cambia la categoría.', icon: Icons.search_off)
        else LayoutBuilder(builder: (ctx, b) {
          final cols = b.maxWidth >= 850 ? 3 : b.maxWidth >= 560 ? 2 : 1;
          return Wrap(spacing: 14, runSpacing: 14, children: shown.map((item) => SizedBox(
            width: (b.maxWidth - 14 * (cols - 1)) / cols,
            child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ItemArtwork(item, height: 135),
              const SizedBox(height: 15),
              Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 10, color: muted, letterSpacing: 1)),
              const SizedBox(height: 7),
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 7),
              Text(soles(item.priceCents) + (rental ? ' / día' : ' por unidad'),
                style: const TextStyle(color: muted)),
              const SizedBox(height: 12),
              StudioBadge(rental ? 'Consultar fechas' : '${item.units} en stock',
                warning: !rental && item.units <= 3),
              if (rental) ...[
                const SizedBox(height: 8),
                Text('Garantía: ${soles(item.depositCents)}', style: const TextStyle(fontSize: 12, color: muted)),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 6, runSpacing: 6, children: [
                OutlinedButton(onPressed: () => _openForm(context, ops,
                  rental ? 'rental' : 'stock', item: item),
                  child: Text(rental ? 'Reservar equipo' : 'Ajustar stock')),
                TextButton(onPressed: () => _openForm(context, ops, 'item',
                  item: item, rental: rental), child: const Text('Editar')),
              ]),
            ])),
          )).toList());
        }),
      ],
      if (tab == 1 && !rental) ...[
        const Text('Cada entrada y salida queda visible en esta sesión.',
          style: TextStyle(color: muted)),
        const SizedBox(height: 14),
        ...ops.movements.map((m) => Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Surface(child: Row(children: [
            CircleAvatar(backgroundColor: m.delta > 0 ? _sage : _peach,
              child: Icon(m.delta > 0 ? Icons.south_west : Icons.north_east, color: ink, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.item, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(m.reason, style: const TextStyle(fontSize: 12, color: muted)),
              Text(dayLabel(m.when), style: const TextStyle(fontSize: 11, color: muted)),
            ])),
            Text((m.delta > 0 ? '+' : '') + m.delta.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.delta > 0 ? const Color(0xFF4F6242) : orange)),
          ])))),
      ],
      if (tab == 1 && rental) ...[
        Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
          onPressed: () => _openForm(context, ops, 'rental'),
          icon: const Icon(Icons.add), label: const Text('Nueva reserva de equipo'))),
        const SizedBox(height: 18),
        ...ops.rentals.map((r) => _rentalCard(context, r)),
      ],
      if (tab == 2) _requests(context),
    ]);
  });
  Widget _rentalCard(BuildContext context, RentalDemo r) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
        children: [Text(r.id, style: const TextStyle(fontWeight: FontWeight.w800)),
          StudioBadge(r.status, warning: r.status == 'Entregado')]),
      const SizedBox(height: 14),
      Text(r.asset, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 5),
      Text(r.client, style: const TextStyle(color: muted)),
      const SizedBox(height: 14),
      Row(children: [
        const Icon(Icons.date_range_outlined, size: 18, color: orange),
        const SizedBox(width: 8),
        Expanded(child: Text('${dayLabel(r.start)} → ${dayLabel(r.end)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
      const Divider(height: 28),
      Text('Alquiler ${soles(r.amount)} · Garantía ${soles(r.deposit)}',
        style: const TextStyle(fontSize: 12, color: muted)),
      if (r.status == 'Reservado' || r.status == 'Entregado') ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: () {
            ops.changeRental(r, r.status == 'Reservado' ? 'Entregado' : 'Devuelto');
            notify(context, 'Estado de ejemplo actualizado.');
          }, child: Text(r.status == 'Reservado' ? 'Registrar entrega' : 'Registrar devolución')),
          if (r.status == 'Reservado') TextButton(onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('¿Cancelar esta reserva?'),
              content: const Text('El equipo volverá a estar disponible para esas fechas en la demo.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Conservar')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar reserva'))]));
            if (ok == true) ops.changeRental(r, 'Cancelado');
          }, child: const Text('Cancelar')),
        ]),
      ],
    ])),
  );
  Widget _requests(BuildContext context) {
    final requests = widget.controller.managementRequests.where((r) =>
      r.kind == (widget.rentals ? 'rental' : 'product')).toList();
    if (requests.isEmpty) { return EmptyState(
      title: 'Tu bandeja está al día', message: 'Las solicitudes de la web aparecerán aquí.',
      icon: Icons.mark_email_read_outlined,
      action: TextButton(onPressed: () => context.go(widget.rentals ? '/alquileres' : '/productos'),
        child: const Text('Explorar como cliente'))); }
    return Column(children: requests.map((r) => Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StudioBadge(r.label), const SizedBox(height: 12),
        Text(r.itemName, style: Theme.of(context).textTheme.titleLarge),
        Text(widget.controller.adminStore.clientName(r.clientId)),
        Text('${r.quantity} unidad(es) · ${soles(r.amountCents)}',
          style: const TextStyle(color: muted)),
        if (r.status == 'pending') ...[const SizedBox(height: 12),
          OutlinedButton(onPressed: () => guarded(context,
            () => widget.controller.resolveRequest(r, 'handled')),
            child: const Text('Marcar atendida'))],
      ])))).toList());
  }
}

class StudioPayments extends StatefulWidget {
  const StudioPayments({super.key, required this.controller});
  final WebController controller;
  @override
  State<StudioPayments> createState() => _StudioPaymentsState();
}
class _StudioPaymentsState extends State<StudioPayments> {
  int filter = 0;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final ops = widget.controller.operations!;
    return AnimatedBuilder(animation: ops, builder: (ctx, _) {
      const filters = ['Todos', 'Pendiente', 'Parcial', 'Pagado'];
      final shown = ops.charges.where((c) =>
        (filter == 0 || c.status == filters[filter]) &&
        (c.client + c.detail).toLowerCase().contains(query.toLowerCase())).toList();
      return WebPage(children: [
        const Intro('Las cuentas, claras.', 'Abonos, saldos y métodos, en una sola vista.'),
        const DemoNotice(),
        StudioMetrics([
          (soles(ops.collected), 'Abonos de ejemplo', Icons.payments_outlined),
          (soles(ops.outstanding), 'Saldo pendiente', Icons.schedule),
          (ops.charges.where((c) => c.balance > 0).length.toString(), 'Cuentas abiertas', Icons.receipt_long_outlined),
          (ops.charges.where((c) => c.balance == 0).length.toString(), 'Cuentas completas', Icons.check_circle_outline),
        ]),
        const SizedBox(height: 24),
        Surface(color: _blue, child: const Row(children: [
          Icon(Icons.lock_outline, color: ink), SizedBox(width: 12),
          Expanded(child: Text('Puedes simular un abono para recorrer el flujo. Esta demo no procesa dinero ni se conecta a Yape, Plin o bancos.',
            style: TextStyle(fontSize: 12, height: 1.6))),
        ])),
        StudioTabs(filters, filter, (i) => setState(() => filter = i)),
        TextField(onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar cliente o concepto')),
        const SizedBox(height: 20),
        if (shown.isEmpty) const EmptyState(title: 'No hay cuentas en esta vista',
          message: 'Cambia el filtro o prueba otro nombre.', icon: Icons.receipt_long_outlined),
        ...shown.map((c) => Padding(padding: const EdgeInsets.only(bottom: 14),
          child: Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
              children: [Text(c.id, style: const TextStyle(color: muted, fontSize: 12)),
                StudioBadge(c.status, warning: c.balance > 0)]),
            const SizedBox(height: 12),
            Text(c.client, style: Theme.of(context).textTheme.titleLarge),
            Text(c.detail, style: const TextStyle(color: muted)),
            const Divider(height: 28),
            Wrap(spacing: 24, runSpacing: 12, children: [
              _amount('Total', c.total), _amount('Abonado', c.paid), _amount('Saldo', c.balance),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (c.balance > 0) FilledButton.icon(onPressed: () => _openForm(context, ops, 'payment', charge: c),
                icon: const Icon(Icons.add, size: 17), label: const Text('Simular abono')),
              TextButton(onPressed: () => _chargeDetails(context, c), child: const Text('Ver detalle')),
            ]),
          ])))),
      ]);
    });
  }
  Widget _amount(String label, int cents) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: muted, fontSize: 11)),
    const SizedBox(height: 4),
    Text(soles(cents), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
  ]);
}
Future<void> _chargeDetails(BuildContext context, ChargeDemo c) => showModalBottomSheet<void>(
  context: context, isScrollControlled: true, showDragHandle: true,
  builder: (ctx) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.receipt_long_outlined, size: 42, color: orange),
      const SizedBox(height: 18),
      Text('Detalle de abono', style: Theme.of(ctx).textTheme.headlineMedium, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text('Simulación · no es un cobro real', textAlign: TextAlign.center, style: TextStyle(color: muted)),
      const Divider(height: 36),
      Text(c.client, style: Theme.of(ctx).textTheme.titleLarge), Text(c.detail),
      const SizedBox(height: 16),
      Text('Total: ${soles(c.total)}'), Text('Abonado: ${soles(c.paid)}'),
      Text('Saldo: ${soles(c.balance)}'), Text('Método: ${c.method.isEmpty ? 'Sin abonos' : c.method}'),
      const SizedBox(height: 24),
      OutlinedButton.icon(onPressed: () async {
        await Clipboard.setData(ClipboardData(text: 'MAZA · EJEMPLO\n${c.id}\n${c.client}\n${c.detail}\nAbonado: ${soles(c.paid)}\nSaldo: ${soles(c.balance)}'));
        if (ctx.mounted) notify(ctx, 'Resumen de ejemplo copiado.');
      }, icon: const Icon(Icons.copy_outlined), label: const Text('Copiar resumen')),
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
    ]))),
);

class StudioReports extends StatelessWidget {
  const StudioReports({super.key, required this.controller});
  final WebController controller;
  @override
  Widget build(BuildContext context) {
    final ops = controller.operations!;
    return AnimatedBuilder(animation: ops, builder: (ctx, _) => WebPage(children: [
      const Intro('Una mirada más amplia.', 'Entiende qué se mueve y dónde poner tu atención.'),
      const DemoNotice(),
      StudioMetrics([
        (soles(ops.collected), 'Abonos simulados', Icons.trending_up),
        (controller.adminStore.clients.length.toString(), 'Clientes de ejemplo', Icons.people_outline),
        (controller.adminStore.services.where((s) => s.active).length.toString(), 'Servicios activos', Icons.content_cut),
        (soles(ops.outstanding), 'Saldo por atender', Icons.schedule),
      ]),
      const SectionTitle('Abonos por actividad'),
      Surface(child: Column(children: ['Barbería', 'Productos', 'Alquileres'].map((name) {
        final amount = ops.charges.where((c) => c.category == name).fold(0, (int a, c) => a + c.paid);
        final ratio = ops.collected == 0 ? 0.0 : amount / ops.collected;
        return Padding(padding: const EdgeInsets.only(bottom: 22), child: Column(children: [
          Row(children: [Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(soles(amount), style: const TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: ratio, minHeight: 12,
              color: name == 'Barbería' ? orange : name == 'Productos' ? const Color(0xFF81936F) : ink,
              backgroundColor: line)),
        ]));
      }).toList())),
      const SectionTitle('El catálogo, al detalle'),
      Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Productos por reponer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 14),
        ...ops.products.where((p) => p.units <= 3).map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
            Expanded(child: Text(p.name)), StudioBadge('${p.units} uds.', warning: true),
          ]))),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: () => context.go('/admin/stock'), child: const Text('Revisar inventario')),
      ])),
      const SectionTitle('Servicios disponibles'),
      ...controller.adminStore.services.map((s) => Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Surface(child: Row(children: [
          const Icon(Icons.content_cut, color: orange), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${s.minutes} minutos', style: const TextStyle(color: muted, fontSize: 12)),
          ])), Text(soles(s.priceCents), style: const TextStyle(fontWeight: FontWeight.w800)),
        ])))),
    ]));
  }
}
class StudioNotices extends StatelessWidget {
  const StudioNotices({super.key, required this.controller});
  final WebController controller;
  @override
  Widget build(BuildContext context) {
    final ops = controller.operations!;
    return AnimatedBuilder(animation: ops, builder: (ctx, _) => WebPage(children: [
      Intro('Lo importante, a tiempo.', 'Avisos de ejemplo para organizar tu día.',
        action: OutlinedButton.icon(onPressed: ops.notificationsRead ? null : ops.markRead,
          icon: const Icon(Icons.done_all), label: Text(ops.notificationsRead ? 'Todo revisado' : 'Marcar como revisados'))),
      const DemoNotice(),
      _links(context, [
        ('Reponer inventario', '${ops.lowStock} productos con pocas unidades', Icons.inventory_2_outlined, '/admin/stock'),
        ('Coordinar una devolución', 'Revisa el equipo entregado y su garantía', Icons.key_outlined, '/admin/alquileres'),
        ('Consultar saldos', '${soles(ops.outstanding)} pendientes en la simulación', Icons.payments_outlined, '/admin/pagos'),
        ('Preparar la siguiente visita', 'Consulta los turnos y el historial del cliente', Icons.calendar_month_outlined, '/admin/citas'),
      ]),
    ]));
  }
}

Future<void> _openForm(BuildContext context, DesignOperations ops, String kind,
    {ShopItem? item, bool rental = false, ChargeDemo? charge}) => showModalBottomSheet<void>(
  context: context, isScrollControlled: true, showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => _StudioForm(ops: ops, kind: kind, item: item, rental: rental, charge: charge),
);
class _StudioForm extends StatefulWidget {
  const _StudioForm({required this.ops, required this.kind, this.item, this.rental = false, this.charge});
  final DesignOperations ops;
  final String kind;
  final ShopItem? item;
  final bool rental;
  final ChargeDemo? charge;
  @override
  State<_StudioForm> createState() => _StudioFormState();
}
class _StudioFormState extends State<_StudioForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, price, units, detail, category, deposit;
  late String asset;
  String method = 'Efectivo', movement = 'Entrada';
  String? error;
  late DateTimeRange range;
  @override
  void initState() {
    super.initState();
    final item = widget.item;
    name = TextEditingController(text: item?.name ?? '');
    price = TextEditingController(text: ((widget.charge?.balance ?? item?.priceCents ?? 0) / 100).toStringAsFixed(2));
    units = TextEditingController(text: item == null ? '0' : item.units.toString());
    detail = TextEditingController(text: item?.description ?? '');
    category = TextEditingController(text: item?.category ?? (widget.rental ? 'Equipamiento' : 'Cuidado'));
    deposit = TextEditingController(text: ((item?.depositCents ?? 0) / 100).toStringAsFixed(2));
    asset = item != null && item.rental ? item.id : widget.ops.rentalItems.first.id;
    final now = peruNow();
    final day = DateTime(now.year, now.month, now.day);
    range = DateTimeRange(start: day, end: day.add(const Duration(days: 1)));
    if (widget.kind == 'stock') { units.text = '1'; detail.text = ''; }
    if (widget.kind == 'rental') name.text = '';
  }
  @override
  void dispose() {
    for (final c in [name, price, units, detail, category, deposit]) { c.dispose(); }
    super.dispose();
  }
  int _cents(String raw) {
    final n = double.tryParse(raw.trim().replaceAll(',', '.'));
    return n == null || !n.isFinite || n < 0 ? -1 : (n * 100).round();
  }
  Widget _text(TextEditingController c, String label, {bool numeric = false, int lines = 1}) =>
    Padding(padding: const EdgeInsets.only(bottom: 14), child: TextFormField(
      controller: c, maxLines: lines,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (s) => s == null || s.trim().isEmpty ? 'Completa este campo' : null,
    ));
  void submit() {
    if (!form.currentState!.validate()) return;
    try {
      switch (widget.kind) {
        case 'item':
          widget.ops.saveItem(original: widget.item, rental: widget.rental,
            name: name.text, category: category.text, description: detail.text,
            price: _cents(price.text), units: int.tryParse(units.text) ?? -1,
            deposit: _cents(deposit.text));
        case 'stock':
          final value = int.tryParse(units.text) ?? 0;
          if (value <= 0) throw const DomainError('Escribe una cantidad entera mayor a cero.');
          widget.ops.adjustStock(widget.item!, movement == 'Entrada' ? value : -value, detail.text);
        case 'rental':
          widget.ops.reserve(widget.ops.rentalItems.firstWhere((i) => i.id == asset), name.text, range.start, range.end);
        case 'payment':
          widget.ops.recordPayment(widget.charge!, _cents(price.text), method);
      }
      Navigator.pop(context);
    } catch (e) { setState(() => error = friendlyError(e)); }
  }
  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final item = widget.ops.rentalItems.firstWhere((p) => p.id == asset);
    final title = kind == 'item' ? (widget.item == null ? 'Añadir ' : 'Editar ') +
        (widget.rental ? 'equipo' : 'producto')
      : kind == 'stock' ? 'Ajustar stock'
      : kind == 'rental' ? 'Reserva de equipo' : 'Simular abono';
    return SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Solo cambia la demostración visual de esta sesión.',
          style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 24),
        if (kind == 'item') ...[
          _text(name, widget.rental ? 'Nombre del equipo' : 'Nombre del producto'),
          _text(category, 'Categoría'),
          _text(detail, 'Descripción', lines: 2),
          _text(price, widget.rental ? 'Precio por día (S/)' : 'Precio de venta (S/)', numeric: true),
          if (!widget.rental && widget.item == null) _text(units, 'Unidades iniciales', numeric: true),
          if (widget.rental) _text(deposit, 'Garantía (S/)', numeric: true),
        ],
        if (kind == 'stock') ...[
          Text(widget.item!.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('${widget.item!.units} unidades disponibles', style: const TextStyle(color: muted)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: movement, decoration: const InputDecoration(labelText: 'Movimiento'),
            items: ['Entrada', 'Salida'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => movement = v!)),
          const SizedBox(height: 14),
          _text(units, 'Cantidad de unidades', numeric: true),
          _text(detail, 'Motivo del movimiento'),
        ],
        if (kind == 'rental') ...[
          DropdownButtonFormField<String>(initialValue: asset, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Equipo'),
            items: widget.ops.rentalItems.map((i) => DropdownMenuItem(value: i.id,
              child: Text(i.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => asset = v!)),
          const SizedBox(height: 14),
          _text(name, 'Nombre del cliente'),
          OutlinedButton.icon(onPressed: () async {
            final now = peruNow();
            final chosen = await showDateRangePicker(context: context, initialDateRange: range,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: DateTime(now.year + 1), helpText: 'Fechas del alquiler');
            if (chosen != null && mounted) setState(() => range = chosen);
          }, icon: const Icon(Icons.date_range),
            label: Text('${dayLabel(range.start)} → ${dayLabel(range.end)}')),
          const SizedBox(height: 16),
          Surface(color: _sage, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${range.duration.inDays} día(s) · ${soles(item.priceCents)} por día'),
            const SizedBox(height: 8),
            Text('Total: ${soles(item.priceCents * range.duration.inDays)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('Garantía aparte: ${soles(item.depositCents)}', style: const TextStyle(fontSize: 12, color: muted)),
          ])),
        ],
        if (kind == 'payment') ...[
          Text(widget.charge!.client, style: Theme.of(context).textTheme.titleLarge),
          Text(widget.charge!.detail, style: const TextStyle(color: muted)),
          const SizedBox(height: 14),
          Text('Saldo: ${soles(widget.charge!.balance)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          _text(price, 'Importe del abono (S/)', numeric: true),
          DropdownButtonFormField<String>(initialValue: method,
            decoration: const InputDecoration(labelText: 'Método de ejemplo'),
            items: ['Efectivo', 'Yape', 'Plin', 'Transferencia'].map((s) =>
              DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => method = v!)),
        ],
        if (error != null) Padding(padding: const EdgeInsets.only(top: 16),
          child: Text(error!, style: const TextStyle(color: orange))),
        const SizedBox(height: 24),
        FilledButton(onPressed: submit, child: Text(kind == 'payment' ? 'Guardar abono de ejemplo' : 'Guardar en la demo')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver sin guardar')),
      ])),
    ));
  }
}
