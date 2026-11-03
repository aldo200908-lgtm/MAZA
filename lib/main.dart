import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/theme.dart';
import 'web/paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  final callback = demo ? null : authCallbackDestination(Uri.base);
  try {
    if (!demo) {
      if (url.isEmpty || key.isEmpty) {
        throw StateError(
          'Faltan SUPABASE_URL y SUPABASE_ANON_KEY. Revisa README.md o ejecuta con DEMO_MODE=true.',
        );
      }
      await Supabase.initialize(url: url, anonKey: key);
    }
    runApp(MazaApp(demo: demo, initialLocation: callback));
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: mazaTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                e is StateError
                    ? e.message.toString()
                    : 'No se pudo iniciar MAZA. Revisa la configuración y tu conexión.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
