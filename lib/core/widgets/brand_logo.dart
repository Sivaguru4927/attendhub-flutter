import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The AttendHub brand logo, shown from the image `assets/images/logo.png`
/// (clipboard + QR + people, with the "AttendHub - Scan, Track, Manage"
/// wordmark already inside the picture).
///
/// [size] controls the overall scale (the picture is `size * 3.2` wide).
/// [showWordmark] and [showTagline] are kept so existing screens compile;
/// the wordmark and tagline are part of the image itself.
/// [subtitle] is the small "(E Cell)" line under the logo.
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
    final width = size * 3.2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            color: Colors.white,
            child: Image.asset(
              'assets/images/logo.png',
              width: width,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stack) => SizedBox(
                width: width,
                height: width * 0.6,
                child: const Center(
                  child: Text(
                    'AttendHub',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
