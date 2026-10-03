import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The AttendHub brand logo — painted as a [CustomPainter] to avoid external
/// image assets and render crisply at any size.
///
/// Displays the clipboard + QR + users motif with the wordmark below.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 80,
    this.showWordmark = true,
    this.showTagline = true,
    this.subtitle = '(E Cell)',
  });

  final double size;
  final bool showWordmark;
  final bool showTagline;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _LogoPainter()),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 12),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Attend ',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'Hub',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
        if (showTagline) ...[
          const SizedBox(height: 6),
          const Text(
            'SCAN  •  TRACK  •  MANAGE',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Clipboard body
    final clipPaint = Paint()
      ..color = AppColors.primaryContainer
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06;

    final clipRect =
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.7),
            Radius.circular(w * 0.1));
    canvas.drawRRect(clipRect, clipPaint);
    canvas.drawRRect(clipRect, borderPaint);

    // Clipboard clip at top
    final clipTopPaint = Paint()..color = AppColors.primaryDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.35, h * 0.06, w * 0.3, h * 0.14),
        Radius.circular(w * 0.04),
      ),
      clipTopPaint,
    );

    // QR corners
    final qrPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;

    final qrRect = Rect.fromLTWH(w * 0.3, h * 0.25, w * 0.4, h * 0.3);
    const l = 8.0;
    void drawQrCorner(Offset o, double dx, double dy) {
      canvas.drawLine(o, Offset(o.dx + dx * l, o.dy), qrPaint);
      canvas.drawLine(o, Offset(o.dx, o.dy + dy * l), qrPaint);
    }

    drawQrCorner(qrRect.topLeft, 1, 1);
    drawQrCorner(qrRect.topRight, -1, 1);
    drawQrCorner(qrRect.bottomLeft, 1, -1);
    drawQrCorner(qrRect.bottomRight, -1, -1);

    // Small QR pattern dots
    final dotPaint = Paint()..color = AppColors.primaryDark;
    final cx = qrRect.center.dx;
    final cy = qrRect.center.dy;
    final r = w * 0.03;
    for (var i = -1; i <= 1; i++) {
      for (var j = -1; j <= 1; j++) {
        if ((i + j).abs() != 1) {
          canvas.drawCircle(Offset(cx + i * r * 2.5, cy + j * r * 2.5), r, dotPaint);
        }
      }
    }

    // User silhouettes at bottom
    final userPaint = Paint()..style = PaintingStyle.fill;

    void drawUser(double x, double y, Color color, double scale) {
      userPaint.color = color;
      canvas.drawCircle(Offset(x, y - h * 0.04 * scale), h * 0.05 * scale, userPaint);
      final path = Path()
        ..moveTo(x - h * 0.06 * scale, y + h * 0.01)
        ..cubicTo(x - h * 0.06 * scale, y - h * 0.01, x + h * 0.06 * scale,
            y - h * 0.01, x + h * 0.06 * scale, y + h * 0.01)
        ..lineTo(x + h * 0.06 * scale, y + h * 0.07 * scale)
        ..lineTo(x - h * 0.06 * scale, y + h * 0.07 * scale)
        ..close();
      canvas.drawPath(path, userPaint);
    }

    drawUser(w * 0.5, h * 0.8, AppColors.primary, 1.0);
    drawUser(w * 0.3, h * 0.83, AppColors.accent, 0.85);
    drawUser(w * 0.7, h * 0.83, AppColors.accent, 0.85);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
