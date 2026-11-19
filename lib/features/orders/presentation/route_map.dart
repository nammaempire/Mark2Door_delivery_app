import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Illustrated route from store to customer. This is a drawing, not live
/// map tiles: it marks where the Google Map will sit once an API key is
/// added. Turn-by-turn directions already work through the Navigate button.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, required this.distanceKm, required this.eta});

  final double distanceKm;
  final String eta;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 240,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, 240);
            final store = Offset(size.width * 0.16, size.height * 0.74);
            final customer = Offset(size.width * 0.82, size.height * 0.24);
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapPainter(store: store, customer: customer),
                  ),
                ),
                _pin(store, Icons.storefront_rounded, AppColors.accent),
                _pin(customer, Icons.home_rounded, AppColors.primary),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _chip(
                    Icons.near_me_rounded,
                    distanceKm > 0
                        ? '${distanceKm.toStringAsFixed(1)} km'
                        : 'Route preview',
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _chip(Icons.schedule_rounded, 'Deliver by $eta'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pin(Offset at, IconData icon, Color color) {
    const size = 40.0;
    return Positioned(
      left: at.dx - size / 2,
      top: at.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.store, required this.customer});

  final Offset store;
  final Offset customer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7ECEE));

    // City blocks.
    final block = Paint()..color = const Color(0xFFEFDDE1);
    const cols = 5, rows = 4, gap = 14.0;
    final bw = (size.width - gap * (cols + 1)) / cols;
    final bh = (size.height - gap * (rows + 1)) / rows;
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(gap + c * (bw + gap), gap + r * (bh + gap), bw, bh),
            const Radius.circular(8),
          ),
          block,
        );
      }
    }
    // A park, for a little life.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(gap + 2 * (bw + gap), gap + (bh + gap), bw, bh),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFD5EBD9),
    );

    // Route follows the streets: right, up, right.
    final midX = gap * 2.5 + 2 * (bw + gap) + bw;
    final path = Path()
      ..moveTo(store.dx, store.dy)
      ..lineTo(midX, store.dy)
      ..lineTo(midX, customer.dy)
      ..lineTo(customer.dx, customer.dy);
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.store != store || old.customer != customer;
}
