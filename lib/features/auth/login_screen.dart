import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.demo, required this.onDemo});
  final bool demo;
  final Future<void> Function() onDemo;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final key = GlobalKey<FormState>();
  bool busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!widget.demo && !key.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.demo) {
        await widget.onDemo();
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reset() async {
    if (!email.text.contains('@')) {
      notify(context, 'Escribe tu correo para recuperar el acceso.');
      return;
    }
    setState(() => busy = true);
    try {
      const redirect = String.fromEnvironment('AUTH_REDIRECT_URL');
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.text.trim(),
        redirectTo: redirect.isEmpty ? null : redirect,
      );
      if (mounted) {
        notify(
          context,
          'Si el correo está registrado, recibirás un enlace de recuperación.',
        );
      }
    } catch (e) {
      if (mounted) notify(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'MAZA',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -3,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.north_east, color: orange, size: 36),
                  ],
                ),
                const SizedBox(height: 44),
                Container(width: 48, height: 5, color: orange),
                const SizedBox(height: 22),
                Text(
                  'Menos pendientes.\nMás a tu ritmo.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tu agenda y tu barbería,\nen un mismo lugar.',
                  style: TextStyle(color: muted, fontSize: 17, height: 1.5),
                ),
                const SizedBox(height: 36),
                if (widget.demo)
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Conoce MAZA',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Datos ficticios de Perú. Puedes crear citas y editar tu negocio. Los cambios se guardan en este dispositivo.',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: busy ? null : submit,
                            child: Text(busy ? 'Abriendo…' : 'Explorar demo'),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Form(
                    key: key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Correo del administrador',
                          ),
                          validator: (v) => v != null && v.contains('@')
                              ? null
                              : 'Ingresa un correo válido',
                        ),
                        fieldGap,
                        TextFormField(
                          controller: password,
                          obscureText: hidden,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            suffixIcon: IconButton(
                              tooltip: hidden
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () => setState(() => hidden = !hidden),
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: requiredText,
                          onFieldSubmitted: (_) => busy ? null : submit(),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: Text(busy ? 'Ingresando…' : 'Ingresar'),
                        ),
                        TextButton(
                          onPressed: busy ? null : reset,
                          child: const Text('Olvidé mi contraseña'),
                        ),
                      ],
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(error!, style: const TextStyle(color: orange)),
                  ),
                const SizedBox(height: 30),
                Text(
                  widget.demo
                      ? 'DEMO · SIN COBROS REALES'
                      : 'ACCESO PRIVADO · UN ADMINISTRADOR',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.7,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar acceso')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              children: [
                Text(
                  'Elige una nueva contraseña',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                  ),
                  validator: (v) => (v?.length ?? 0) >= 8
                      ? null
                      : 'Usa al menos 8 caracteres',
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: orange)),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          setState(() => busy = true);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(password: password.text),
                            );
                            widget.onDone();
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                busy = false;
                                error = friendlyError(e);
                              });
                            }
                          }
                        },
                  child: Text(busy ? 'Guardando…' : 'Guardar contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
