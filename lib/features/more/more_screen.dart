import 'package:flutter/material.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../clients/clients_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.store, required this.onExit});
  final AppStore store;
  final Future<void> Function() onExit;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageHeading(
        'Todo en su lugar.',
        'MAZA crece contigo, módulo a módulo.',
      ),
      Surface(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('Clientes e historial'),
          subtitle: const Text('Tu relación con cada cliente'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ClientsScreen(store: store),
            ),
          ),
        ),
      ),
      const SectionTitle('Lo que viene'),
      _module(
        context,
        'Stock de belleza',
        'Productos, existencias y movimientos',
        Icons.inventory_2_outlined,
      ),
      _module(
        context,
        'Alquileres',
        'Bienes, contratos y reservas',
        Icons.key_outlined,
      ),
      _module(
        context,
        'Pagos',
        'Cuentas, abonos y devoluciones',
        Icons.account_balance_wallet_outlined,
      ),
      const SizedBox(height: 20),
      Surface(
        color: ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MAZA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              store.isDemo
                  ? 'Demo local · Versión 1.0\nDatos ficticios. Sin transacciones reales.'
                  : 'Un administrador · Versión 1.0\nDatos conectados a Supabase.',
              style: const TextStyle(color: Colors.white70, height: 1.6),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => guarded(context, onExit),
        icon: const Icon(Icons.logout),
        label: Text(store.isDemo ? 'Salir de la demo' : 'Cerrar sesión'),
      ),
    ],
  );
  Widget _module(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Surface(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: muted),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: EmptyState(
                      icon: icon,
                      title: 'Próximamente',
                      message:
                          '$title tendrá su propio espacio. En esta versión el módulo está vacío.',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
