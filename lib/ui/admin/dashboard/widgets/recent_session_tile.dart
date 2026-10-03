import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/attendance_session.dart';

/// A list tile for a single [AttendanceSession] on the dashboard.
class RecentSessionTile extends StatelessWidget {
  const RecentSessionTile({super.key, required this.session});
  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final isActive = session.status == SessionStatus.active;
    final fmt = DateFormat('d MMM, HH:mm');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () =>
            context.push('${RoutePaths.sessionControl}/${session.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? AppColors.success : AppColors.cardBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.successContainer
                      : AppColors.shimmer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive
                      ? Icons.wifi_tethering_rounded
                      : Icons.event_available_outlined,
                  color: isActive ? AppColors.success : AppColors.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fmt.format(session.startedAt.toLocal())} · ${session.venue ?? "No venue"}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.successContainer
                      : AppColors.shimmer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'LIVE' : 'ENDED',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: isActive ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
