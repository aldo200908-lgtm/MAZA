import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clock.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

String friendlyError(Object error) {
  if (error is DomainError) return error.message;
  if (error is AuthException) {
    if (error.code == 'email_not_confirmed') {
      return 'Confirma tu correo antes de ingresar. Revisa también la carpeta de spam.';
    }
    if (error.code == 'invalid_credentials') {
      return 'El correo o la contraseña no coinciden. Si ya confirmaste tu cuenta, usa Recuperar contraseña.';
    }
    if (error.code == 'over_email_send_rate_limit') {
      return 'Se enviaron varios correos seguidos. Espera unos minutos antes de solicitar otro.';
    }
    return 'No se pudo completar el acceso. Revisa tus datos o solicita recuperar la contraseña.';
  }
  if (error is PostgrestException) {
    if (error.code == '23P01') {
      return 'Ese horario acaba de ocuparse. Actualiza la agenda y elige otro.';
    }
    if (error.code == '23505') return 'Ya existe un registro con esos datos.';
    if (error.code == '23514') {
      return error.message.startsWith('MAZA:')
          ? error.message.substring(5).trim()
          : 'Revisa los datos y el horario seleccionado.';
    }
    if (error.code == '42501') {
      return 'Esta cuenta no tiene acceso a los datos de MAZA.';
    }
  }
  return 'No se pudo completar la operación. Comprueba tu conexión e inténtalo de nuevo.';
}

void notify(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
Future<void> guarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) notify(context, friendlyError(e));
  }
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: children,
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: muted)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: line),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.event_available_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      children: [
        const SizedBox(height: 14),
        Icon(icon, size: 42, color: orange),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
        const SizedBox(height: 14),
      ],
    ),
  );
}

Color statusColor(AppointmentStatus s) => switch (s) {
  AppointmentStatus.pending => const Color(0xFF936016),
  AppointmentStatus.confirmed => const Color(0xFF36644B),
  AppointmentStatus.completed => const Color(0xFF4E5A8A),
  AppointmentStatus.cancelled => const Color(0xFF9A463B),
  AppointmentStatus.noShow => muted,
};

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final AppointmentStatus status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: statusColor(status).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        color: statusColor(status),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class AppointmentTile extends StatelessWidget {
  const AppointmentTile(this.a, this.store, {super.key, this.onTap});
  final Appointment a;
  final AppStore store;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      hm(peruWall(a.start)),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a.minutes} min',
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.clientName(a.clientId),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(a.serviceName),
                    const SizedBox(height: 6),
                    Text(
                      '${store.barberName(a.barberId)} · ${soles(a.priceCents)}',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 8),
                    StatusPill(a.status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: muted, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> showMazaForm(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext, StateSetter) fields,
  required Future<void> Function() save,
  String submit = 'Guardar',
}) async {
  var busy = false;
  String? error;
  final formKey = GlobalKey<FormState>();
  final navigator = Navigator.of(context);
  final route = ModalBottomSheetRoute<bool>(
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: paper,
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setState) => PopScope(
        canPop: !busy,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(ctx).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AbsorbPointer(
                      absorbing: busy,
                      child: fields(ctx, setState),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: orange),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() {
                                busy = true;
                                error = null;
                              });
                              try {
                                await save();
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                if (ctx.mounted) {
                                  setState(() {
                                    busy = false;
                                    error = friendlyError(e);
                                  });
                                }
                              }
                            },
                      child: Text(busy ? 'Guardando…' : submit),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final result = await navigator.push(route);
  // Un pop resuelve push antes de que termine la animación de salida.
  // Los controladores del formulario se liberan solo al desmontar la ruta.
  await route.completed;
  return result ?? false;
}

String? requiredText(String? v) =>
    v == null || v.trim().isEmpty ? 'Completa este campo' : null;
const fieldGap = SizedBox(height: 16);
