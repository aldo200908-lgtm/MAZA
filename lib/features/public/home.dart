import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../web/components.dart';
import '../../web/controller.dart';

class PublicHome extends StatelessWidget {
  const PublicHome({super.key, required this.controller});
  final WebController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller.catalog;
    if (c == null) {
      return LoadingOrError(
        error: controller.error,
        retry: () => controller.start(),
      );
    }
    final nextVisit = controller.appointments.where((a) =>
      a.status.blocks && a.start.isAfter(DateTime.now().toUtc())).firstOrNull;
    return WebPage(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: TextField(
            readOnly: true,
            onTap: () => context.go('/buscar'),
            decoration: const InputDecoration(
              hintText: '¿Qué estás buscando?',
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.arrow_forward, size: 20),
            ),
          ),
        ),
        if (controller.customer != null && nextVisit != null) Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Surface(color: const Color(0xFFE8EDDF), child: Row(children: [
            const Icon(Icons.event_available_outlined, color: orange), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tu próxima visita', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(nextVisit.serviceName + ' · ' + dayLabel(peruWall(nextVisit.start)) +
                ' · ' + hm(peruWall(nextVisit.start)), style: const TextStyle(fontSize: 12, color: muted)),
            ])),
            IconButton(tooltip: 'Ver mis citas', onPressed: () => context.go('/mi-cuenta/citas'),
              icon: const Icon(Icons.arrow_forward, size: 20)),
          ]))),
        Container(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 650 ? 25 : 40,
          ),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(28),
          ),
          child: LayoutBuilder(
            builder: (ctx, b) {
              final text = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A TU MANERA',
                    style: TextStyle(
                      color: Color(0xFFE1AD83),
                      fontSize: 10,
                      letterSpacing: 2.7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tu estilo.\nA tu hora.',
                    style: TextStyle(
                      color: paper,
                      fontWeight: FontWeight.w900,
                      fontSize: b.maxWidth > 650 ? 70 : 48,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Un buen corte, tus básicos de cuidado\ny equipo para lo que viene.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.6,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 25),
                  FilledButton.icon(
                    onPressed: () => context.go('/barberia'),
                    icon: const Icon(Icons.north_east, size: 18),
                    label: const Text('Reservar mi próximo corte'),
                  ),
                ],
              );
              return b.maxWidth > 650
                  ? Row(
                      children: [
                        Expanded(child: text),
                        const SizedBox(width: 30),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1.3,
                            child: _HeroArt(),
                          ),
                        ),
                      ],
                    )
                  : text;
            },
          ),
        ),
        SectionTitle(
          'Tu próximo corte',
          trailing: TextButton(
            onPressed: () => context.go('/barberia'),
            child: const Text('Ver todos'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 18),
          child: Text(
            'Elige el servicio. Nosotros hacemos espacio.',
            style: TextStyle(color: muted),
          ),
        ),
        if (c.services.isEmpty)
          const EmptyState(
            title: 'Pronto tendremos turnos',
            message: 'Vuelve más tarde para conocer nuestros servicios.',
          )
        else
          LayoutBuilder(
            builder: (ctx, b) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: c.services
                  .take(3)
                  .map(
                    (s) => SizedBox(
                      width: b.maxWidth >= 700
                          ? (b.maxWidth - 24) / 3
                          : b.maxWidth,
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.content_cut,
                              color: orange,
                              size: 22,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              s.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${soles(s.priceCents)} · ${s.minutes} min',
                              style: const TextStyle(color: muted),
                            ),
                            const SizedBox(height: 18),
                            TextButton.icon(
                              key: ValueKey('reserve-${s.id}'),
                              onPressed: () => context.go(
                                '/barberia/reservar?servicio=${s.id}',
                              ),
                              icon: const Icon(Icons.arrow_forward, size: 17),
                              label: const Text('Reservar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 18),
        SectionTitle(
          'El cuidado sigue en casa',
          trailing: TextButton(
            onPressed: () => context.go('/productos'),
            child: const Text('Ver catálogo'),
          ),
        ),
        ItemGrid(
          items: c.products.take(4).toList(),
          onTap: (i) => context.go('/productos/${i.id}'),
        ),
        const SizedBox(height: 18),
        SectionTitle(
          'Úsalo. Devuélvelo. Sigue.',
          trailing: TextButton(
            onPressed: () => context.go('/alquileres'),
            child: const Text('Ver equipos'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Equipamiento por día, con fechas y condiciones claras.',
            style: TextStyle(color: muted),
          ),
        ),
        ItemGrid(
          items: c.rentals.take(3).toList(),
          onTap: (i) => context.go('/alquileres/${i.id}'),
        ),
        const SizedBox(height: 34),
        const Divider(),
        const SizedBox(height: 20),
        Text(
          c.business.name,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(c.business.address, style: const TextStyle(color: muted)),
        const SizedBox(height: 8),
        Text(
          c.business.policy,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go('/admin/acceso'),
            child: const Text('Acceso de administración'),
          ),
        ),
        if (controller.demo)
          const Text(
            'Sitio de demostración. Negocio, catálogos y datos de ejemplo. No se realizan cobros.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
      ],
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt();
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          color: paper.withValues(alpha: .05),
          shape: BoxShape.circle,
          border: Border.all(color: paper.withValues(alpha: .12)),
        ),
      ),
      Transform.rotate(
        angle: -.18,
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFECE2D1),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 30,
                offset: Offset(15, 20),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAZA',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 24),
              Icon(Icons.content_cut, size: 56, color: orange),
              SizedBox(height: 20),
              Divider(color: muted),
              SizedBox(height: 10),
              Text(
                'UN MOMENTO\nPARA TI.',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'PUNO · PERÚ',
                style: TextStyle(fontSize: 9, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.controller});
  final WebController controller;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = widget.controller.catalog;
    if (c == null) {
      return LoadingOrError(
        error: widget.controller.error,
        retry: () => widget.controller.start(),
      );
    }
    final q = query.trim().toLowerCase();
    final s = c.services
        .where((x) => x.name.toLowerCase().contains(q))
        .toList();
    final items = [...c.products, ...c.rentals]
        .where((x) => '${x.name} ${x.category}'.toLowerCase().contains(q))
        .toList();
    return WebPage(
      children: [
        const Intro(
          'Encuentra lo tuyo.',
          'Busca un corte, un básico de cuidado o un equipo.',
        ),
        TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Buscar en MAZA',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 24),
        if (q.isEmpty)
          const EmptyState(
            title: 'Todo MAZA, en una búsqueda',
            message: 'Escribe lo que necesitas para ver los resultados.',
            icon: Icons.search,
          )
        else if (s.isEmpty && items.isEmpty)
          const EmptyState(
            title: 'Sin coincidencias',
            message: 'Prueba con otro servicio, producto o equipo.',
            icon: Icons.search_off,
          )
        else ...[
          ...s.map(
            (x) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Surface(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.content_cut),
                  title: Text(x.name),
                  subtitle: Text('${soles(x.priceCents)} · ${x.minutes} min'),
                  trailing: const Icon(Icons.north_east),
                  onTap: () =>
                      context.go('/barberia/reservar?servicio=${x.id}'),
                ),
              ),
            ),
          ),
          ItemGrid(
            items: items,
            onTap: (x) =>
                context.go('/${x.rental ? 'alquileres' : 'productos'}/${x.id}'),
          ),
        ],
      ],
    );
  }
}
