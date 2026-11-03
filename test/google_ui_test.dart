import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maza/core/store.dart';
import 'package:maza/core/theme.dart';
import 'package:maza/data/demo_repository.dart';
import 'package:maza/features/admin/design_store.dart';
import 'package:maza/features/public/account.dart';
import 'package:maza/web/controller.dart';
import 'package:maza/web/gateway.dart';

class GoogleGateway extends DemoCustomerGateway {
  GoogleGateway(super.store, {required this.active});
  final bool active;
  String? destination;
  @override
  bool get googleEnabled => active;
  @override
  Future<void> signInWithGoogle(String next) async {
    destination = next;
  }
}

void main() {
  for (final enabled in [true, false]) {
    testWidgets(
      'Google ${enabled ? 'habilitado' : 'deshabilitado'} conserva el acceso por correo',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final store = AppStore(DemoRepository());
        final gateway = GoogleGateway(store, active: enabled);
        final c = WebController(
          demo: false,
          store: store,
          customerGateway: gateway,
          adminOperations: DesignOperations(empty: true),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: mazaTheme(),
            home: WebAccess(
              controller: c,
              returnTo: '/barberia/reservar?servicio=corte',
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Correo electrónico'), findsOneWidget);
        expect(
          find.text('Continuar con Google'),
          enabled ? findsOneWidget : findsNothing,
        );
        if (enabled) {
          await t.tap(find.text('Continuar con Google'));
          await t.pumpAndSettle();
          expect(gateway.destination, '/barberia/reservar?servicio=corte');
          // No valida ni exige contraseña del formulario de correo.
          expect(find.text('Escribe tu contraseña'), findsNothing);
          expect(c.adminAllowed, isFalse);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
}
