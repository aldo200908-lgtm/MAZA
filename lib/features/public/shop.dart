import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../web/catalog.dart';
import '../../web/components.dart';
import '../../web/controller.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key, required this.controller, required this.rentals});
  final WebController controller;
  final bool rentals;
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String query = '', category = 'Todos';
  @override
  Widget build(BuildContext context) {
    final c = widget.controller.catalog;
    if (c == null) {
      return LoadingOrError(
        error: widget.controller.error,
        retry: () => widget.controller.start(),
      );
    }
    final all = widget.rentals ? c.rentals : c.products;
    final categories = ['Todos', ...all.map((i) => i.category).toSet()];
    final filtered = all
        .where(
          (x) =>
              (category == 'Todos' || x.category == category) &&
              x.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return WebPage(
      children: [
        Intro(
          widget.rentals
              ? 'Equipo para lo que viene.'
              : 'Tus básicos. Bien elegidos.',
          widget.rentals
              ? 'Por los días que necesitas. Consulta fechas y coordina la entrega.'
              : 'Cuida tu corte y tu barba, también después de salir de la silla.',
        ),
        TextField(
          decoration: InputDecoration(
            labelText: widget.rentals ? 'Buscar equipo' : 'Buscar producto',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: categories
              .map(
                (s) => ChoiceChip(
                  label: Text(s),
                  selected: category == s,
                  onSelected: (_) => setState(() => category = s),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        if (filtered.isEmpty)
          const EmptyState(
            title: 'Sin resultados',
            message: 'Prueba otra búsqueda o categoría.',
          )
        else
          ItemGrid(
            items: filtered,
            onTap: (x) => context.go(
              '/${widget.rentals ? 'alquileres' : 'productos'}/${x.id}',
            ),
          ),
      ],
    );
  }
}

class ItemDetail extends StatefulWidget {
  const ItemDetail({
    super.key,
    required this.controller,
    required this.id,
    required this.rental,
  });
  final WebController controller;
  final String id;
  final bool rental;
  @override
  State<ItemDetail> createState() => _ItemDetailState();
}

class _ItemDetailState extends State<ItemDetail> {
  DateTime? start, end;
  int quantity = 1;
  bool busy = false;
  String? error;
  CustomerRequest? sent;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller.catalog;
    if (c == null) {
      return LoadingOrError(
        error: widget.controller.error,
        retry: () => widget.controller.start(),
      );
    }
    final item = (widget.rental ? c.rentals : c.products)
        .where((x) => x.id == widget.id)
        .firstOrNull;
    if (item == null) {
      return const WebPage(
        children: [
          EmptyState(
            title: 'Este artículo ya no está disponible',
            message: 'Vuelve al catálogo para ver otras opciones.',
          ),
        ],
      );
    }
    final path = '/${widget.rental ? 'alquileres' : 'productos'}/${item.id}';
    if (sent != null) {
      return WebPage(
        width: 640,
        children: [
          const Intro(
            'Solicitud enviada.',
            'Te mostraremos su estado en tu cuenta.',
          ),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('${soles(sent!.amountCents)} · importe estimado'),
                const SizedBox(height: 12),
                const Text(
                  'Pendiente de confirmación. Esta solicitud no es un cobro ni una reserva de equipo confirmada.',
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/mi-cuenta/solicitudes'),
            child: const Text('Ver mis solicitudes'),
          ),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Volver al inicio'),
          ),
        ],
      );
    }
    return WebPage(
      width: 800,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                context.go(widget.rental ? '/alquileres' : '/productos'),
            icon: const Icon(Icons.arrow_back, size: 17),
            label: const Text('Volver al catálogo'),
          ),
        ),
        ItemArtwork(item, height: 270),
        const SizedBox(height: 26),
        Intro(item.name, item.description),
        Text(
          '${soles(item.priceCents)}${item.rental ? ' por día' : ''}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.rental
              ? 'Garantía: ${soles(item.depositCents)}. Se coordina al confirmar.'
              : '${item.units} unidades disponibles.',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        if (item.rental) ...[
          OutlinedButton.icon(
            onPressed: () async {
              final now = peruNow();
              final first = DateTime(now.year, now.month, now.day);
              final range = await showDateRangePicker(
                context: context,
                firstDate: first,
                lastDate: first.add(const Duration(days: 90)),
                initialDateRange: start == null
                    ? null
                    : DateTimeRange(start: start!, end: end!),
              );
              if (range != null) {
                setState(() {
                  start = range.start;
                  end = range.end;
                });
              }
            },
            icon: const Icon(Icons.date_range),
            label: Text(
              start == null
                  ? 'Elegir fechas'
                  : '${dayLabel(start!)} → ${dayLabel(end!)}',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'La devolución marca el final del alquiler y no suma un día extra. La disponibilidad se confirma al atender tu solicitud.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          if (start != null && end!.isAfter(start!))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '${end!.difference(start!).inDays} días · ${soles(item.priceCents * end!.difference(start!).inDays)} estimados',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ] else
          DropdownButtonFormField<int>(
            initialValue: quantity,
            decoration: const InputDecoration(labelText: 'Cantidad'),
            items: List.generate(
              item.units.clamp(0, 20),
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
            ),
            onChanged: item.units == 0
                ? null
                : (n) => setState(() => quantity = n!),
          ),
        const SizedBox(height: 22),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(error!, style: const TextStyle(color: orange)),
          ),
        FilledButton(
          onPressed: busy || item.units == 0
              ? null
              : () async {
                  if (!widget.controller.signedIn) {
                    context.go(
                      Uri(
                        path: '/acceso',
                        queryParameters: {'volver': path},
                      ).toString(),
                    );
                    return;
                  }
                  if (widget.controller.customer == null) {
                    context.go(
                      Uri(
                        path: '/mi-cuenta',
                        queryParameters: {'volver': path},
                      ).toString(),
                    );
                    return;
                  }
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    final result = await widget.controller.requestItem(
                      item,
                      quantity,
                      start: start,
                      end: end,
                    );
                    if (mounted) setState(() => sent = result);
                  } catch (e) {
                    if (mounted) setState(() => error = friendlyError(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(
            busy
                ? 'Enviando…'
                : widget.controller.signedIn
                ? item.rental
                      ? 'Solicitar alquiler'
                      : 'Solicitar producto'
                : widget.controller.demo
                ? 'Usar cuenta de ejemplo para solicitar'
                : 'Ingresar para solicitar',
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'Sin pagos online. Enviar la solicitud no descuenta dinero.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}
