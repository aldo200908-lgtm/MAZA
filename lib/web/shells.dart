import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'controller.dart';

const publicLabels = [
  'Inicio',
  'Reservar',
  'Productos',
  'Alquileres',
  'Cuenta',
];
const publicIcons = [
  Icons.home_outlined,
  Icons.content_cut,
  Icons.shopping_bag_outlined,
  Icons.key_outlined,
  Icons.person_outline,
];

class PublicShell extends StatelessWidget {
  const PublicShell({
    super.key,
    required this.navigation,
    required this.controller,
  });
  final StatefulNavigationShell navigation;
  final WebController controller;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      appBar: AppBar(
        title: TextButton(
          onPressed: () => navigation.goBranch(0),
          style: TextButton.styleFrom(foregroundColor: ink),
          child: const Text(
            'MAZA',
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.7,
            ),
          ),
        ),
        actions: [
          if (wide)
            ...List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton(
                  onPressed: () => navigation.goBranch(i),
                  style: TextButton.styleFrom(
                    foregroundColor: navigation.currentIndex == i
                        ? orange
                        : ink,
                  ),
                  child: Text(
                    publicLabels[i],
                    style: TextStyle(
                      fontWeight: navigation.currentIndex == i
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          if (controller.demo)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'DEMO',
                style: TextStyle(
                  fontSize: 10,
                  color: muted,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(child: navigation),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: navigation.currentIndex,
              onDestinationSelected: (i) => navigation.goBranch(i),
              destinations: List.generate(
                5,
                (i) => NavigationDestination(
                  icon: Icon(publicIcons[i], size: 23),
                  label: publicLabels[i],
                ),
              ),
            ),
    );
  }
}

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.navigation,
    required this.controller,
  });
  final StatefulNavigationShell navigation;
  final WebController controller;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    final path = GoRouterState.of(context).uri.path;
    const labels = [
      'Resumen',
      'Citas',
      'Barbería',
      'Clientes',
      'Stock',
      'Alquileres',
      'Pagos',
      'Configuración',
    ];
    const routes = [
      '/admin',
      '/admin/citas',
      '/admin/barberia',
      '/admin/clientes',
      '/admin/stock',
      '/admin/alquileres',
      '/admin/pagos',
      '/admin/configuracion',
    ];
    const icons = [
      Icons.dashboard_outlined,
      Icons.calendar_today_outlined,
      Icons.content_cut,
      Icons.people_outline,
      Icons.inventory_2_outlined,
      Icons.key_outlined,
      Icons.account_balance_wallet_outlined,
      Icons.tune,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'MAZA',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                fontSize: 27,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                controller.demo ? 'Panel demo' : 'Administración',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ver web pública',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.open_in_new, size: 21),
          ),
          IconButton(
            tooltip: 'Salir del panel',
            onPressed: () => guarded(context, () async {
              await controller.leaveAdmin();
              if (context.mounted) context.go('/');
            }),
            icon: const Icon(Icons.logout, size: 21),
          ),
          const SizedBox(width: 6),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 205,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: line)),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ),
                  children: List.generate(
                    labels.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        selected:
                            path == routes[i] ||
                            (i == 3 && path.startsWith('/admin/clientes/')),
                        selectedTileColor: orange.withValues(alpha: .1),
                        selectedColor: orange,
                        leading: Icon(icons[i], size: 19),
                        title: Text(labels[i]),
                        onTap: () => context.go(routes[i]),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(child: navigation),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: navigation.currentIndex,
              onDestinationSelected: (i) => navigation.goBranch(i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Resumen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Citas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  label: 'Gestión',
                ),
              ],
            ),
    );
  }
}
