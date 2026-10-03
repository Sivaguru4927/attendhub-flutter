import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated emerald laser-sweep overlay for the QR scanner viewfinder.
///
/// Reproduces the `@keyframes scan-laser` animation from the web app:
/// a glowing horizontal bar sweeping top → bottom → top with a 2-second
/// ease-in-out period.
class LaserScannerOverlay extends StatefulWidget {
  const LaserScannerOverlay({
    super.key,
    this.borderColor = AppColors.primary,
    this.laserColor = AppColors.laserLine,
    this.cutOutSize = 0.75,
  });

  /// Color of the viewfinder corner brackets.
  final Color borderColor;

  /// Color of the animated laser line.
  final Color laserColor;

  /// Fraction of the screen width used for the cut-out (0..1).
  final double cutOutSize;

  @override
  State<LaserScannerOverlay> createState() => _LaserScannerOverlayState();
}

class _LaserScannerOverlayState extends State<LaserScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _laserAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _laserAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        ) * widget.cutOutSize;
        final cutOut = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: size,
          height: size,
        );

        return Stack(
          children: [
            // Dimmed overlay with cut-out hole.
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _OverlayPainter(cutOut: cutOut),
            ),

            // Corner brackets.
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _BracketPainter(
                cutOut: cutOut,
                color: widget.borderColor,
              ),
            ),

            // Laser line.
            AnimatedBuilder(
              animation: _laserAnim,
              builder: (_, __) {
                final top = cutOut.top +
                    (cutOut.height - 3) * _laserAnim.value;
                return Positioned(
                  left: cutOut.left + cutOut.width * 0.05,
                  top: top,
                  width: cutOut.width * 0.90,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.laserColor.withValues(alpha: 0),
                          widget.laserColor,
                          widget.laserColor.withValues(alpha: 0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.laserColor.withValues(alpha: 0.7),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.cutOut});
  final Rect cutOut;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(
          RRect.fromRectAndRadius(cutOut, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) =>
      oldDelegate.cutOut != cutOut;
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({required this.cutOut, required this.color});
  final Rect cutOut;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    const r = 12.0;

    void drawCorner(Offset anchor, double dx, double dy) {
      final ox = anchor.dx;
      final oy = anchor.dy;
      canvas.drawLine(
        Offset(ox + dx * r, oy),
        Offset(ox + dx * (r + len), oy),
        paint,
      );
      canvas.drawLine(
        Offset(ox, oy + dy * r),
        Offset(ox, oy + dy * (r + len)),
        paint,
      );
      canvas.drawArc(
        Rect.fromLTWH(ox + (dx > 0 ? 0 : -2 * r), oy + (dy > 0 ? 0 : -2 * r),
            2 * r, 2 * r),
        (dx > 0 ? (dy > 0 ? math.pi : math.pi / 2) : (dy > 0 ? math.pi * 1.5 : 0)),
        math.pi / 2,
        false,
        paint,
      );
    }

    drawCorner(cutOut.topLeft, 1, 1);
    drawCorner(cutOut.topRight, -1, 1);
    drawCorner(cutOut.bottomLeft, 1, -1);
    drawCorner(cutOut.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.cutOut != cutOut || old.color != color;
}
