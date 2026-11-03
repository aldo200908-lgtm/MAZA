import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../web/components.dart';
import '../../web/controller.dart';
import '../appointments/appointment_editor.dart';
import 'design_pages.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.controller});
  final WebController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.demo) return StudioOverview(controller: controller);
    final store = controller.adminStore;
    final today = store.forDay(peruNow());
    final pending = today
        .where(
          (a) => [
            AppointmentStatus.pending,
            AppointmentStatus.confirmed,
          ].contains(a.status),
        )
        .toList();
    final requests = controller.managementRequests
        .where((r) => r.status == 'pending' && r.kind == 'rental')
        .length;
    final productRequests = controller.managementRequests
        .where((r) => r.status == 'pending' && r.kind == 'product')
        .length;
    final low =
        controller.catalog?.products.where((p) => p.units <= 3).length ?? 0;
    return WebPage(
      children: [
        Intro(
          'Tu negocio, en orden.',
          '${weekdaysEs[peruNow().weekday - 1]} ${dayLabel(peruNow())} · Resumen de hoy',
          action: FilledButton.icon(
            onPressed: () => showAppointmentEditor(context, store),
            icon: const Icon(Icons.add),
            label: const Text('Nueva cita'),
          ),
        ),
        LayoutBuilder(
          builder: (ctx, b) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric(
                b.maxWidth,
                '${today.where((a) => a.status.blocks).length}',
                'Citas de hoy',
                Icons.calendar_today_outlined,
              ),
              _metric(
                b.maxWidth,
                '${pending.length}',
                'Por atender',
                Icons.content_cut,
              ),
              _metric(
                b.maxWidth,
                'Sin registros',
                'Cobros',
                Icons.account_balance_wallet_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Los servicios completados no se cuentan como dinero cobrado. Pagos todavía no registra transacciones.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SectionTitle('Requiere atención'),
        Surface(
          color: const Color(0xFFECEFE4),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.mark_chat_unread_outlined,
                  color: orange,
                ),
                title: Text('$requests solicitudes de alquiler'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/alquileres'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined, color: orange),
                title: Text('$productRequests solicitudes de productos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/stock'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: orange),
                title: Text('$low productos con stock bajo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/stock'),
              ),
            ],
          ),
        ),
        SectionTitle(
          'Próximas citas',
          trailing: TextButton(
            onPressed: () => context.go('/admin/citas'),
            child: const Text('Ver agenda'),
          ),
        ),
        if (pending.isEmpty)
          const EmptyState(
            title: 'Todo al día',
            message: 'No hay citas pendientes para hoy.',
          )
        else
          ...pending.map(
            (a) => AppointmentTile(
              a,
              store,
              onTap: () => showAppointmentDetails(context, store, a),
            ),
          ),
      ],
    );
  }

  Widget _metric(double width, String value, String label, IconData icon) {
    final cols = width >= 700
        ? 3
        : width >= 350
        ? 2
        : 1;
    return SizedBox(
      width: (width - 12 * (cols - 1)) / cols,
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: muted, size: 20),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: value.length > 8 ? 20 : 30,
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
