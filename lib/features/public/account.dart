import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../web/components.dart';
import '../../web/controller.dart';
import '../../web/paths.dart';

class WebAccess extends StatefulWidget {
  const WebAccess({
    super.key,
    required this.controller,
    this.admin = false,
    this.returnTo,
  });
  final WebController controller;
  final bool admin;
  final String? returnTo;
  @override
  State<WebAccess> createState() => _WebAccessState();
}

class _WebAccessState extends State<WebAccess> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, register = false, hide = true;
  String? error, message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.controller.demo && !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      if (widget.admin && widget.controller.demo) {
        await widget.controller.enterDemoAdmin();
      } else if (register) {
        final result = await widget.controller.register(
          email.text,
          password.text,
        );
        if (result != null) {
          if (mounted) setState(() => message = result);
          return;
        }
      } else {
        await widget.controller.login(email.text, password.text);
      }
      if (widget.admin && !widget.controller.adminAllowed) {
        throw const DomainError(
          'Esta cuenta no tiene acceso a la administración.',
        );
      }
      if (mounted) {
        context.go(
          widget.admin
              ? safeDestination(widget.returnTo, fallback: '/admin')
              : safeDestination(widget.returnTo),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Volver a la web',
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text(
        'MAZA',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1),
      ),
    ),
    body: WebPage(
      width: 510,
      children: [
        const SizedBox(height: 22),
        Intro(
          widget.admin ? 'Tu negocio, en orden.' : 'Tu espacio en MAZA.',
          widget.admin
              ? 'Acceso exclusivo de administración.'
              : 'Tus citas, solicitudes y datos, en un mismo lugar.',
        ),
        if (widget.controller.demo)
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  widget.admin
                      ? Icons.dashboard_outlined
                      : Icons.person_outline,
                  color: orange,
                  size: 34,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.admin
                      ? 'Administración de ejemplo'
                      : 'Cuenta de ejemplo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.admin
                      ? 'Este panel contiene solo datos ficticios. Es una demostración pública; no protege información real.'
                      : 'Entra como Luis Quispe para probar una reserva y consultar sus visitas. No ingreses datos personales reales.',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: Text(
                    busy
                        ? 'Abriendo…'
                        : widget.admin
                        ? 'Abrir panel de demostración'
                        : 'Entrar con cuenta de ejemplo',
                  ),
                ),
              ],
            ),
          )
        else
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                  validator: (s) =>
                      s != null &&
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                      ? null
                      : 'Escribe un correo válido',
                ),
                fieldGap,
                TextFormField(
                  controller: password,
                  obscureText: hide,
                  autofillHints: [
                    register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    suffixIcon: IconButton(
                      tooltip: hide
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () => setState(() => hide = !hide),
                      icon: Icon(
                        hide
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) >= (register ? 8 : 1)
                      ? null
                      : register
                      ? 'Usa al menos 8 caracteres'
                      : 'Escribe tu contraseña',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: Text(
                    busy
                        ? 'Procesando…'
                        : register
                        ? 'Crear mi cuenta'
                        : 'Ingresar',
                  ),
                ),
                if (!widget.admin)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => register = !register),
                    child: Text(
                      register ? 'Ya tengo una cuenta' : 'Crear cuenta',
                    ),
                  ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!email.text.contains('@')) {
                            notify(
                              context,
                              'Escribe tu correo para recuperar el acceso.',
                            );
                            return;
                          }
                          setState(() => busy = true);
                          try {
                            const redirect = String.fromEnvironment(
                              'AUTH_REDIRECT_URL',
                            );
                            await Supabase.instance.client.auth
                                .resetPasswordForEmail(
                                  email.text.trim(),
                                  redirectTo: redirect.isEmpty
                                      ? null
                                      : redirect,
                                );
                            if (context.mounted) {
                              notify(
                                context,
                                'Si el correo existe, recibirás un enlace de recuperación.',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              notify(context, friendlyError(e));
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: const Text('Olvidé mi contraseña'),
                ),
              ],
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(error!, style: const TextStyle(color: orange)),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(message!, style: const TextStyle(color: muted)),
          ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Seguir explorando'),
        ),
      ],
    ),
  );
}

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.controller,
    this.returnTo,
    this.section,
  });
  final WebController controller;
  final String? returnTo, section;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final name = TextEditingController(), phone = TextEditingController();
  String? loadedId;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final p = c.customer;
    if (p?.id != loadedId) {
      loadedId = p?.id;
      name.text = p?.name ?? '';
      phone.text = p?.phone ?? '';
    }
    if (!c.signedIn) {
      return WebPage(
        children: [
          const Intro(
            'Tus planes, a mano.',
            'Ingresa para guardar una cita y consultar tus solicitudes.',
          ),
          FilledButton(
            onPressed: () => context.go('/acceso'),
            child: const Text('Ingresar'),
          ),
        ],
      );
    }
    return WebPage(
      width: 850,
      children: [
        Intro(
          p == null
              ? 'Completemos tus datos.'
              : 'Hola, ${p.name.split(' ').first}.',
          p == null
              ? 'Solo necesitamos tu nombre y celular para identificar tu reserva.'
              : 'Aquí están tus próximas visitas y lo que has solicitado.',
        ),
        if (c.demo)
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              'Cuenta de ejemplo · los cambios se guardan en este navegador.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        if (widget.returnTo != null && p != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: FilledButton.icon(
              onPressed: () => context.go(safeDestination(widget.returnTo)),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continuar con mi solicitud'),
            ),
          ),
        if (widget.section != 'solicitudes') ...[
          const SectionTitle('Mis citas'),
          if (c.appointments.isEmpty)
            EmptyState(
              title: 'Tu primera visita está por llegar',
              message: 'Encuentra un servicio y elige un turno.',
              action: TextButton(
                onPressed: () => context.go('/barberia'),
                child: const Text('Ver servicios'),
              ),
            )
          else
            ...c.appointments.map((a) => _customerAppointment(context, c, a)),
        ],
        if (widget.section != 'citas') ...[
          const SectionTitle('Mis solicitudes'),
          if (c.requests.isEmpty)
            const EmptyState(
              title: 'Todavía no hay solicitudes',
              message: 'Aquí aparecerán tus productos y alquileres.',
              icon: Icons.shopping_bag_outlined,
            )
          else
            ...c.requests.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.itemName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${r.label} · ${soles(r.amountCents)} estimados',
                        style: const TextStyle(color: muted),
                      ),
                      if (r.startsOn != null)
                        Text(
                          '${dayLabel(r.startsOn!)} a ${dayLabel(r.endsOn!)}',
                          style: const TextStyle(color: muted),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sin cobro online.',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        const SectionTitle('Mis datos'),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Nombre y apellidos',
                ),
              ),
              fieldGap,
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular peruano',
                  hintText: '987654321',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: const TextStyle(color: orange)),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          if (name.text.trim().isEmpty ||
                              !RegExp(
                                r'^(\+51\s?)?9\d{8}$',
                              ).hasMatch(phone.text.trim())) {
                            throw const DomainError(
                              'Completa tu nombre y un celular peruano de 9 dígitos.',
                            );
                          }
                          await c.saveProfile(name.text, phone.text);
                          if (context.mounted) {
                            if (widget.returnTo != null) {
                              context.go(safeDestination(widget.returnTo));
                            } else {
                              notify(context, 'Tus datos se guardaron.');
                            }
                          }
                        } catch (e) {
                          if (mounted) setState(() => error = friendlyError(e));
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Guardando…' : 'Guardar mis datos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => guarded(context, () async {
            await c.logout();
            if (context.mounted) context.go('/');
          }),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar mi sesión'),
        ),
      ],
    );
  }

  Widget _customerAppointment(
    BuildContext context,
    WebController c,
    Appointment a,
  ) {
    final changeable =
        a.start.isAfter(DateTime.now().toUtc()) &&
        [
          AppointmentStatus.pending,
          AppointmentStatus.confirmed,
        ].contains(a.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(a.status),
            const SizedBox(height: 14),
            Text(a.serviceName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('${dayLabel(peruWall(a.start))} · ${hm(peruWall(a.start))}'),
            const SizedBox(height: 5),
            Text(
              '${c.barberName(a.barberId)} · ${soles(a.priceCents)}',
              style: const TextStyle(color: muted),
            ),
            if (changeable) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go(
                      Uri(
                        path: '/barberia/reservar',
                        queryParameters: {
                          'servicio': a.serviceId,
                          'cita': a.id,
                        },
                      ).toString(),
                    ),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 17),
                    label: const Text('Reprogramar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¿Cancelar esta cita?'),
                          content: Text(
                            '${a.serviceName} · ${dayLabel(peruWall(a.start))} a las ${hm(peruWall(a.start))}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Conservar cita'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Cancelar cita'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true && context.mounted) {
                        await guarded(
                          context,
                          () => c.changeBooking(a, cancel: true),
                        );
                      }
                    },
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
