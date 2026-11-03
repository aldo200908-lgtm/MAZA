import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets.dart';
import '../features/admin/dashboard.dart';
import '../features/admin/design_pages.dart';
import '../features/admin/management.dart';
import '../features/appointments/appointments_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/barbers/barbers_screen.dart';
import '../features/clients/clients_screen.dart';
import '../features/public/account.dart';
import '../features/public/booking.dart';
import '../features/public/home.dart';
import '../features/public/shop.dart';
import 'components.dart';
import 'controller.dart';
import 'paths.dart';
import 'shells.dart';

GoRouter createWebRouter(WebController c, {String? initialLocation}) {
  Widget page(Widget Function() build) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (c.loading || c.catalog == null) {
        return LoadingOrError(error: c.error, retry: () => c.start());
      }
      return build();
    },
  );
  final root = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: root,
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: initialLocation != null,
    refreshListenable: c,
    redirect: (context, state) {
      final callback = authCallbackDestination(state.uri);
      if (callback != null) return callback;
      if (c.loading) return null;
      final path = state.uri.path;
      if (c.recovering && path != '/recuperar') return '/recuperar';
      if (path == '/auth/retorno') {
        if (c.identityLoading) return null;
        if (!c.signedIn) return '/acceso';
        final next = safeDestination(
          c.oauthReturnTo,
          fallback: c.adminAllowed ? '/admin' : '/mi-cuenta',
        );
        if ((next == '/admin' || next.startsWith('/admin/')) && !c.adminAllowed) {
          return '/mi-cuenta';
        }
        return next;
      }
      if (path == '/recuperar' && !c.signedIn) return '/acceso';
      final adminPath = path == '/admin' || path.startsWith('/admin/');
      if (adminPath && path != '/admin/acceso' && !c.adminAllowed) {
        return Uri(
          path: '/admin/acceso',
          queryParameters: {'volver': state.uri.toString()},
        ).toString();
      }
      if (path == '/admin/acceso' && c.adminAllowed) {
        return safeDestination(
          state.uri.queryParameters['volver'],
          fallback: '/admin',
        );
      }
      if (path.startsWith('/mi-cuenta') && !c.signedIn) {
        return Uri(
          path: '/acceso',
          queryParameters: {'volver': state.uri.toString()},
        ).toString();
      }
      if (path.startsWith('/barberia/confirmacion/') && !c.signedIn) {
        return Uri(
          path: '/acceso',
          queryParameters: {'volver': state.uri.toString()},
        ).toString();
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: WebPage(
        children: [
          const Intro(
            'Esta página no existe.',
            'Vuelve al inicio para encontrar lo que buscas.',
          ),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    ),
    routes: [
      GoRoute(
        path: '/auth/retorno',
        builder: (ctx, s) => page(() => const SizedBox.shrink()),
      ),
      GoRoute(
        path: '/acceso',
        builder: (ctx, s) =>
            WebAccess(controller: c, returnTo: s.uri.queryParameters['volver']),
      ),
      GoRoute(
        path: '/admin/acceso',
        builder: (ctx, s) => WebAccess(
          controller: c,
          admin: true,
          returnTo: s.uri.queryParameters['volver'],
        ),
      ),
      GoRoute(
        path: '/recuperar',
        builder: (ctx, s) => PasswordScreen(
          onDone: () {
            c.finishRecovery();
            ctx.go('/mi-cuenta');
          },
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (ctx, s, n) => PublicShell(navigation: n, controller: c),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (ctx, s) => page(() => PublicHome(controller: c)),
              ),
              GoRoute(
                path: '/buscar',
                builder: (ctx, s) => page(() => SearchPage(controller: c)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/barberia',
                builder: (ctx, s) => page(() => BarberLanding(controller: c)),
                routes: [
                  GoRoute(
                    path: 'reservar',
                    builder: (ctx, s) =>
                        page(() => BookingScreen(controller: c, uri: s.uri)),
                  ),
                  GoRoute(
                    path: 'confirmacion/:id',
                    builder: (ctx, s) => page(
                      () => BookingConfirmation(
                        controller: c,
                        id: s.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/productos',
                builder: (ctx, s) =>
                    page(() => ShopPage(controller: c, rentals: false)),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (ctx, s) => page(
                      () => ItemDetail(
                        controller: c,
                        id: s.pathParameters['id']!,
                        rental: false,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alquileres',
                builder: (ctx, s) =>
                    page(() => ShopPage(controller: c, rentals: true)),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (ctx, s) => page(
                      () => ItemDetail(
                        controller: c,
                        id: s.pathParameters['id']!,
                        rental: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mi-cuenta',
                builder: (ctx, s) => page(
                  () => AccountPage(
                    controller: c,
                    returnTo: s.uri.queryParameters['volver'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'citas',
                    builder: (ctx, s) => page(
                      () => AccountPage(controller: c, section: 'citas'),
                    ),
                  ),
                  GoRoute(
                    path: 'solicitudes',
                    builder: (ctx, s) => page(
                      () => AccountPage(controller: c, section: 'solicitudes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (ctx, s, n) => AdminShell(navigation: n, controller: c),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (ctx, s) => page(() => AdminDashboard(controller: c)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/citas',
                builder: (ctx, s) =>
                    page(() => AppointmentsScreen(store: c.adminStore)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/gestion',
                builder: (ctx, s) => page(() => const ManagementPage()),
              ),
              GoRoute(
                path: '/admin/barberia',
                builder: (ctx, s) => page(
                  () => BarbersScreen(
                    store: c.adminStore,
                    onClients: () => ctx.go('/admin/clientes'),
                  ),
                ),
              ),
              GoRoute(
                path: '/admin/clientes',
                builder: (ctx, s) => page(
                  () => ClientsScreen(
                    store: c.adminStore,
                    onOpen: (id) => ctx.go('/admin/clientes/$id'),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (ctx, s) => page(
                      () =>
                          c.adminStore.clients.any(
                            (x) => x.id == s.pathParameters['id'],
                          )
                          ? ClientHistoryScreen(
                              store: c.adminStore,
                              clientId: s.pathParameters['id']!,
                            )
                          : const WebPage(
                              children: [
                                EmptyState(
                                  title: 'Cliente no encontrado',
                                  message:
                                      'Vuelve al listado para seleccionar una ficha.',
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/admin/stock',
                builder: (ctx, s) =>
                    page(() => AdminCatalog(controller: c, rentals: false)),
              ),
              GoRoute(
                path: '/admin/alquileres',
                builder: (ctx, s) =>
                    page(() => AdminCatalog(controller: c, rentals: true)),
              ),
              GoRoute(
                path: '/admin/pagos',
                builder: (ctx, s) => page(() => StudioPayments(controller: c)),
              ),
              GoRoute(
                path: '/admin/reportes',
                builder: (ctx, s) => page(() => StudioReports(controller: c)),
              ),
              GoRoute(
                path: '/admin/avisos',
                builder: (ctx, s) => page(() => StudioNotices(controller: c)),
              ),
              GoRoute(
                path: '/admin/configuracion',
                builder: (ctx, s) =>
                    page(() => BusinessSettings(controller: c)),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
