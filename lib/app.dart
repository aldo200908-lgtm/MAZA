import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'web/controller.dart';
import 'web/router.dart';

class MazaApp extends StatefulWidget {
  const MazaApp({super.key, required this.demo, this.initialLocation});
  final bool demo;
  final String? initialLocation;
  @override
  State<MazaApp> createState() => _MazaAppState();
}

class _MazaAppState extends State<MazaApp> {
  late final WebController controller;
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    controller = WebController(demo: widget.demo);
    router = createWebRouter(
      controller,
      initialLocation: widget.initialLocation,
    );
    unawaited(controller.start());
  }

  @override
  void dispose() {
    router.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'MAZA · Tu estilo, a tu hora',
    debugShowCheckedModeBanner: false,
    theme: mazaTheme(),
    locale: const Locale('es', 'PE'),
    supportedLocales: const [Locale('es', 'PE')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
  );
}
