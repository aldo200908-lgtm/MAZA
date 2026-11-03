import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maza/app.dart';
import 'package:maza/web/shells.dart';

void main() {
  const preview = bool.fromEnvironment('DESIGN_PREVIEW');
  testWidgets('la vista de diseño abre admin y cliente sin Supabase ni login', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(const MazaApp(demo: true, initialLocation: '/admin'));
    await t.pumpAndSettle();
    expect(find.text('Tu negocio, en orden.'), findsOneWidget);
    expect(find.text('Abrir panel de demostración'), findsNothing);
    final shell = t.widget<AdminShell>(find.byType(AdminShell));
    expect(shell.controller.adminAllowed, isTrue);
    expect(shell.controller.signedIn, isTrue);
    expect(shell.controller.customer?.name, 'Luis Quispe');
    expect(t.takeException(), isNull);
  }, skip: !preview);
}
