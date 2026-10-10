import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Where the barcode must be placed: a wide band across the screen.
///
/// The same rectangle is used to DRAW the guide and to limit the area the
/// camera reads (the scanner's scan window), so what you see is what is read.
class BarcodeGuide {
  BarcodeGuide._();

  /// The guide band for a scanner view of [size].
  static Rect rectFor(Size size) {
    final width = size.width * 0.90;
    final height = math.min(
      math.max(size.width * 0.50, 150.0),
      size.height * 0.34,
    );
    // A little above the middle, so the result panel at the bottom
    // never covers it.
    final centerY = size.height * 0.40;
    return Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: width,
      height: height,
    );
  }
}

/// Scanner overlay: dimmed screen with a clear band, white end bars
/// (put the barcode between them), a green centre line to line the bars of
/// the barcode up with, and a sweeping laser.
class BarcodeGuideOverlay extends StatefulWidget {
  const BarcodeGuideOverlay({
    super.key,
    required this.guide,
    this.hint = 'Place the barcode between the white bars',
  });

  final Rect guide;
  final String hint;

  @override
  State<BarcodeGuideOverlay> createState() => _BarcodeGuideOverlayState();
}

class _BarcodeGuideOverlayState extends State<BarcodeGuideOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _sweep = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    return IgnorePointer(
      child: Stack(
        children: [
          // Dimmed screen with the clear band.
          Positioned.fill(
            child: CustomPaint(painter: _DimPainter(guide: g)),
          ),

          // Band edges, end bars and the static centre line.
          Positioned.fill(
            child: CustomPaint(painter: _GuidePainter(guide: g)),
          ),

          // Sweeping laser inside the band.
          AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) {
              final top = g.top + 6 + (g.height - 12 - 2) * _sweep.value;
              return Positioned(
                left: g.left + 16,
                width: g.width - 32,
                top: top,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.laserLine.withValues(alpha: 0),
                        AppColors.laserLine.withValues(alpha: 0.85),
                        AppColors.laserLine.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Hint under the band.
          Positioned(
            left: 16,
            right: 16,
            top: g.bottom + 12,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.laserLine,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.hint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  const _DimPainter({required this.guide});
  final Rect guide;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(guide, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.50),
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.guide != guide;
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.guide});
  final Rect guide;

  @override
  void paint(Canvas canvas, Size size) {
    // Thin top and bottom edge lines.
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    canvas.drawLine(guide.topLeft, guide.topRight, edge);
    canvas.drawLine(guide.bottomLeft, guide.bottomRight, edge);

    // White end bars (the "place the barcode between these" markers).
    final bar = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(guide.left, guide.top + 4),
      Offset(guide.left, guide.bottom - 4),
      bar,
    );
    canvas.drawLine(
      Offset(guide.right, guide.top + 4),
      Offset(guide.right, guide.bottom - 4),
      bar,
    );

    // Static green centre line to line the barcode up with.
    final cy = guide.center.dy;
    final glow = Paint()
      ..color = AppColors.laserLine.withValues(alpha: 0.35)
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final line = Paint()
      ..color = AppColors.laserLine
      ..strokeWidth = 2;
    final a = Offset(guide.left + 12, cy);
    final b = Offset(guide.right - 12, cy);
    canvas.drawLine(a, b, glow);
    canvas.drawLine(a, b, line);
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.guide != guide;
}
