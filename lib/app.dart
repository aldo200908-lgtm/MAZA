import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'core/store.dart';
import 'data/demo_repository.dart';
import 'data/supabase_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/appointments/appointments_screen.dart';
import 'features/barbers/barbers_screen.dart';
import 'features/more/more_screen.dart';

class MazaApp extends StatelessWidget {
  const MazaApp({super.key, required this.demo});
  final bool demo;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MAZA · Tu día, en orden',
    debugShowCheckedModeBanner: false,
    theme: mazaTheme(),
    locale: const Locale('es', 'PE'),
    supportedLocales: const [Locale('es', 'PE')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: SessionGate(demo: demo),
  );
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.demo});
  final bool demo;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  StreamSubscription<AuthState>? _auth;
  AppStore? _store;
  bool _loading = false, _recovery = false;
  String? _error, _userId;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    if (!widget.demo) {
      final auth = Supabase.instance.client.auth;
      _userId = auth.currentUser?.id;
      _auth = auth.onAuthStateChange.listen((event) {
        if (!mounted) return;
        if (event.event == AuthChangeEvent.passwordRecovery) {
          setState(() => _recovery = true);
          return;
        }
        final id = event.session?.user.id;
        if (id != _userId) {
          _userId = id;
          _generation++;
          _store?.dispose();
          setState(() {
            _store = null;
            _error = null;
            _loading = false;
            _recovery = false;
          });
          if (id != null) _load();
        }
      });
      if (_userId != null) _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    final store = AppStore(
      widget.demo
          ? DemoRepository()
          : SupabaseRepository(Supabase.instance.client),
    );
    try {
      await store.load();
      if (!mounted || generation != _generation) {
        store.dispose();
        return;
      }
      _store?.dispose();
      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (e) {
      store.dispose();
      if (mounted && generation == _generation) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _exit() async {
    if (widget.demo) {
      _generation++;
      _store?.dispose();
      setState(() {
        _store = null;
        _error = null;
        _loading = false;
      });
    } else {
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recovery) {
      return PasswordScreen(onDone: () => setState(() => _recovery = false));
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40, color: orange),
                const SizedBox(height: 20),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: _load, child: const Text('Reintentar')),
                TextButton(
                  onPressed: () => guarded(context, _exit),
                  child: const Text('Volver al acceso'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_store == null) return LoginScreen(demo: widget.demo, onDemo: _load);
    return Navigator(
      key: ValueKey(_store),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => MazaShell(store: _store!, onExit: _exit),
      ),
    );
  }
}

class MazaShell extends StatefulWidget {
  const MazaShell({super.key, required this.store, required this.onExit});
  final AppStore store;
  final Future<void> Function() onExit;
  @override
  State<MazaShell> createState() => _MazaShellState();
}

class _MazaShellState extends State<MazaShell> {
  int index = 0;
  final labels = ['Inicio', 'Citas', 'Barbería', 'Más'];
  final icons = [
    Icons.space_dashboard_outlined,
    Icons.calendar_month_outlined,
    Icons.content_cut,
    Icons.grid_view_outlined,
  ];
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final pages = [
        HomeScreen(
          store: widget.store,
          onAgenda: () => setState(() => index = 1),
        ),
        AppointmentsScreen(store: widget.store),
        BarbersScreen(store: widget.store),
        MoreScreen(store: widget.store, onExit: widget.onExit),
      ];
      final wide = MediaQuery.sizeOf(context).width >= 900;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'MAZA',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.8,
              fontSize: 29,
            ),
          ),
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.store.isDemo ? 'DEMO LOCAL' : 'ADMIN',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar datos',
              onPressed: () => guarded(context, widget.store.load),
              icon: const Icon(Icons.refresh, size: 20),
            ),
            const SizedBox(width: 8),
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
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (v) => setState(() => index = v),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: paper,
                  destinations: List.generate(
                    4,
                    (i) => NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                  ),
                ),
              if (wide) const VerticalDivider(width: 1),
              Expanded(
                child: IndexedStack(index: index, children: pages),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (v) => setState(() => index = v),
                destinations: List.generate(
                  4,
                  (i) => NavigationDestination(
                    icon: Icon(icons[i]),
                    label: labels[i],
                  ),
                ),
              ),
      );
    },
  );
}
