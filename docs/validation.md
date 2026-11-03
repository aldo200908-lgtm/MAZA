# Verificación — MAZA Web v2

Alcance: solo web, dos interfaces separadas (cliente/administración), celular y computadora. La app móvil queda para otro proyecto.

- Flutter 3.35.7, Dart 3.9.2, go_router 16.2.4 y dependencias fijadas en pubspec.lock.
- `flutter test --dart-define=VISUAL_OUTPUT=/tmp/maza-web-qa`: 30 pruebas correctas; incluye una prueba visual opcional. En CI se omite esa captura y se ejecutan las otras 29.
- `flutter analyze`: sin incidencias.
- Compilación release para GitHub Pages con `/MAZA/`, modo demo explícito y recursos/fuentes locales y `--no-tree-shake-icons` (el optimizador de iconos del SDK falló al leer su artefacto; la compilación Dart se verificó sin ese recorte).
- PostgreSQL embebido/PGlite: ambas migraciones, semillas, integridad, horarios, exclusión de solapamientos, instantáneas, versiones, RLS, catálogo anónimo sin datos internos, no apropiación de ficha por teléfono y dos clientes con historiales aislados.
- QA visual: inicio, productos, ficha, resumen administrativo y escritorio; interfaz pública a 360×800 con texto al 130 % sin desbordamientos.

Pruebas de producto: navegar los cinco destinos públicos, acceso independiente al panel, cierre de acceso con clientes abiertos, reserva con tres elecciones para cuenta con datos guardados, retorno al turno después del acceso, solicitud persistente, error de recarga posterior al guardado, ocultación de horarios anteriores mientras se consulta otra fecha y propagación de cambios de catálogo sin bucle de recarga.

La revisión independiente detectó tres problemas importantes y dos menores: horarios anteriores aún seleccionables, cambios del panel conectado sin propagación, solicitud ya persistida mostrada como fallida si falla una lectura posterior, invalidación al cambiar la cita en la URL y alertas de productos dirigidas a Alquileres. Se corrigieron; las pruebas de flujo y regresión cubren los casos relevantes.

## Límites verificados

No se ha conectado el Supabase real del usuario ni se ha probado correo/registro contra una cuenta externa. Los RPC y políticas se probaron con un auth mínimo en PostgreSQL embebido. La publicación usa exclusivamente ejemplos locales; el acceso administrativo demo no pretende proteger datos reales.

Stock y Alquileres ofrecen catálogo y solicitudes; movimientos de almacén, contratos, entregas/devoluciones y pagos siguen pendientes. No hay cobros online. No se modifica ni se compila Android en v2.
