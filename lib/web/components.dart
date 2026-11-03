import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'catalog.dart';

class WebPage extends StatelessWidget {
  const WebPage({super.key, required this.children, this.width = 1120});
  final List<Widget> children;
  final double width;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 650 ? 20 : 36,
          24,
          MediaQuery.sizeOf(context).width < 650 ? 20 : 36,
          36,
        ),
        children: children,
      ),
    ),
  );
}

class Intro extends StatelessWidget {
  const Intro(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: MediaQuery.sizeOf(context).width < 650 ? 32 : 44,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 12),
        Text(subtitle, style: const TextStyle(color: muted, height: 1.6)),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

class ItemArtwork extends StatelessWidget {
  const ItemArtwork(this.item, {super.key, this.height = 170});
  final ShopItem item;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
    label: item.rental
        ? 'Ilustración de ${item.name}'
        : 'Ilustración del producto ${item.name}',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        width: double.infinity,
        color: item.rental ? const Color(0xFFE8E7DC) : const Color(0xFFEDE1D4),
        child: CustomPaint(painter: _ItemPainter(item)),
      ),
    ),
  );
}

class _ItemPainter extends CustomPainter {
  _ItemPainter(this.item);
  final ShopItem item;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    void rect(Rect r, Color c, [double radius = 6]) {
      p.color = c;
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);
    }

    final cx = size.width / 2, cy = size.height / 2;
    p.color = Colors.black.withValues(alpha: .07);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + size.height * .32),
        width: size.width * .5,
        height: 16,
      ),
      p,
    );
    if (item.rental) {
      if (item.name.contains('luz')) {
        p
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8;
        canvas.drawCircle(Offset(cx, cy - 20), 42, p);
        p.color = orange;
        canvas.drawCircle(Offset(cx, cy - 20), 34, p);
        p.style = PaintingStyle.fill;
        rect(
          Rect.fromCenter(center: Offset(cx, cy + 40), width: 6, height: 65),
          ink,
        );
        p
          ..color = ink
          ..strokeWidth = 4;
        canvas.drawLine(Offset(cx, cy + 49), Offset(cx - 30, cy + 69), p);
        canvas.drawLine(Offset(cx, cy + 49), Offset(cx + 30, cy + 69), p);
      } else if (item.name.contains('Estación')) {
        rect(
          Rect.fromCenter(center: Offset(cx, cy - 18), width: 90, height: 96),
          ink,
          9,
        );
        rect(
          Rect.fromCenter(center: Offset(cx, cy - 20), width: 73, height: 74),
          const Color(0xFFC4C8BE),
          5,
        );
        rect(
          Rect.fromCenter(center: Offset(cx, cy + 40), width: 145, height: 10),
          orange,
        );
        rect(
          Rect.fromCenter(
            center: Offset(cx - 60, cy + 58),
            width: 7,
            height: 32,
          ),
          ink,
        );
        rect(
          Rect.fromCenter(
            center: Offset(cx + 60, cy + 58),
            width: 7,
            height: 32,
          ),
          ink,
        );
      } else {
        rect(
          Rect.fromCenter(center: Offset(cx, cy - 20), width: 82, height: 72),
          ink,
          16,
        );
        rect(
          Rect.fromCenter(center: Offset(cx, cy + 26), width: 112, height: 24),
          orange,
          10,
        );
        rect(
          Rect.fromCenter(
            center: Offset(cx - 55, cy + 1),
            width: 13,
            height: 44,
          ),
          ink,
        );
        rect(
          Rect.fromCenter(
            center: Offset(cx + 55, cy + 1),
            width: 13,
            height: 44,
          ),
          ink,
        );
        rect(
          Rect.fromCenter(center: Offset(cx, cy + 50), width: 12, height: 32),
          ink,
        );
        rect(
          Rect.fromCenter(center: Offset(cx, cy + 68), width: 80, height: 7),
          ink,
        );
      }
    } else if (item.name.contains('Peine')) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(-.2);
      rect(const Rect.fromLTWH(-75, -22, 150, 18), ink);
      for (var x = -65; x < 70; x += 10) {
        rect(Rect.fromLTWH(x.toDouble(), -7, 5, 42), ink, 2);
      }
      canvas.restore();
    } else {
      final jar = item.name.contains('Pomada'),
          oil = item.name.contains('Aceite');
      final w = jar
              ? 110.0
              : oil
              ? 53.0
              : 70.0,
          h = jar
              ? 64.0
              : oil
              ? 86.0
              : 112.0;
      rect(
        Rect.fromCenter(center: Offset(cx, cy + 10), width: w, height: h),
        oil ? const Color(0xFF8A512F) : ink,
        jar ? 14 : 10,
      );
      rect(
        Rect.fromCenter(
          center: Offset(cx, cy + 10 - h / 2 - 6),
          width: w + 2,
          height: jar ? 19 : 15,
        ),
        orange,
        4,
      );
      if (oil) {
        rect(
          Rect.fromCenter(
            center: Offset(cx, cy - h / 2 - 10),
            width: 18,
            height: 18,
          ),
          ink,
        );
      }
      rect(
        Rect.fromCenter(
          center: Offset(cx, cy + 15),
          width: w * .77,
          height: jar ? 29 : 44,
        ),
        paper,
        2,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'MAZA',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: ink,
            fontWeight: FontWeight.w900,
            fontSize: jar ? 17 : 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + 9));
    }
  }

  @override
  bool shouldRepaint(covariant _ItemPainter old) => old.item.id != item.id;
}

class ItemCard extends StatelessWidget {
  const ItemCard(this.item, {super.key, required this.onTap});
  final ShopItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemArtwork(item, height: 145),
            const SizedBox(height: 14),
            Text(
              item.category,
              style: const TextStyle(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 5),
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 12),
            Text(
              'S/ ${(item.priceCents / 100).toStringAsFixed(2)}${item.rental ? ' / día' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.rental
                        ? 'Consultar fechas'
                        : item.units > 0
                        ? 'Disponible'
                        : 'Agotado',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.units > 0 ? muted : orange,
                    ),
                  ),
                ),
                const Icon(Icons.north_east, size: 17, color: orange),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ItemGrid extends StatelessWidget {
  const ItemGrid({super.key, required this.items, required this.onTap});
  final List<ShopItem> items;
  final void Function(ShopItem) onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, c) {
      final count = c.maxWidth >= 850
          ? 3
          : c.maxWidth >= 330
          ? 2
          : 1;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: items
            .map(
              (x) => SizedBox(
                width: (c.maxWidth - 14 * (count - 1)) / count,
                child: ItemCard(x, onTap: () => onTap(x)),
              ),
            )
            .toList(),
      );
    },
  );
}

class LoadingOrError extends StatelessWidget {
  const LoadingOrError({super.key, this.error, required this.retry});
  final String? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: error == null
          ? const CircularProgressIndicator()
          : EmptyState(
              title: 'No pudimos cargar esta página',
              message: error!,
              action: FilledButton(
                onPressed: retry,
                child: const Text('Reintentar'),
              ),
            ),
    ),
  );
}
