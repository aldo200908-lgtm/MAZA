# Demo de MAZA en GitHub Pages

Repositorio previsto: `aldo200908-lgtm/MAZA`, público e independiente de otros proyectos.
La URL solo se considera publicada después de que GitHub confirme un despliegue correcto.

El workflow `.github/workflows/pages.yml` verifica el código, ejecuta las pruebas, compila Flutter y publica el artefacto web. Se ejecuta al actualizar `main` y manualmente desde Actions.

- En Settings → Pages, el origen debe ser **GitHub Actions**.
- Se fija Flutter 3.35.7 y se exige el lockfile de dependencias.
- El `base-href` viene de Pages para cargar correctamente los archivos dentro de `/MAZA/`.
- El build usa explícitamente `DEMO_MODE=true`; no necesita ni publica credenciales de Supabase.
- Los ejemplos son ficticios. Cada navegador guarda sus propios cambios; no se comparten entre visitantes.
- La fuente se conserva junto a Android, SQL y pruebas; GitHub Pages sirve exclusivamente la compilación web.
- No se añade un dominio propio.

Para activar posteriormente el modo conectado se debe configurar primero Supabase, su administrador y RLS. La publicación actual no habilita cobros ni acceso a datos reales.
