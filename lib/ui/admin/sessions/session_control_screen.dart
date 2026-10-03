import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/config/env_config.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../logic/admin/session_control_provider.dart';
import '../../../data/models/attendance_session.dart';

/// Admin screen for managing an active session.
///
/// Shows the session OTP code, share link, live scan count,
/// and an "End Session" button.
class SessionControlScreen extends ConsumerWidget {
  const SessionControlScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));
    final scanCountAsync = ref.watch(scanCountProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Control'),
        leading: const BackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: sessionAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Session not found.'));
          }
          return _SessionControlBody(
            session: session,
            scanCount: scanCountAsync.valueOrNull ?? 0,
            onEndSession: () => _confirmEnd(context, ref, session),
            onReopen: () => _reopen(context, ref, session),
            onDelete: () => _confirmDelete(context, ref, session),
            onRefreshCount: () => ref.invalidate(scanCountProvider(sessionId)),
          );
        },
      ),
    );
  }

  Future<void> _reopen(
    BuildContext context,
    WidgetRef ref,
    AttendanceSession session,
  ) async {
    final hours = await showDialog<num>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Re-open for how long?'),
        children: [
          for (final h in const [1, 2, 4, 8, 12, 24])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(h),
              child: Text(h == 1 ? '1 hour' : '$h hours'),
            ),
        ],
      ),
    );
    if (hours == null || !context.mounted) return;
    try {
      await ref
          .read(sessionsListProvider.notifier)
          .reopenSession(session.id, hours);
      ref.invalidate(sessionDetailProvider(session.id));
      ref.invalidate(scanCountProvider(session.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session re-opened')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not re-open: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AttendanceSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text(
          '"${session.name}" and ALL of its scans will be permanently '
          'deleted. Your master lists are not touched.\n\n'
          'Download the report first if you still need it. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(sessionsListProvider.notifier).deleteSession(session.id);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  Future<void> _confirmEnd(
    BuildContext context,
    WidgetRef ref,
    AttendanceSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Session?'),
        content: Text(
          'This will immediately revoke all volunteer access for '
          '"${session.name}" and no more scans will be accepted.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(sessionsListProvider.notifier).endSession(session.id);
      if (context.mounted) context.pop();
    }
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------
class _SessionControlBody extends StatelessWidget {
  const _SessionControlBody({
    required this.session,
    required this.scanCount,
    required this.onEndSession,
    required this.onReopen,
    required this.onDelete,
    required this.onRefreshCount,
  });

  final AttendanceSession session;
  final int scanCount;
  final VoidCallback onEndSession;
  final VoidCallback onReopen;
  final VoidCallback onDelete;
  final VoidCallback onRefreshCount;

  String get shareUrl =>
      '${EnvConfig.shareBase}/#/scan/${session.shareToken}';

  @override
  Widget build(BuildContext context) {
    final isActive = session.status == SessionStatus.active;
    final fmt = DateFormat('d MMM yyyy, HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Session header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [AppColors.primary, AppColors.primaryDark]
                    : [AppColors.textSecondary, const Color(0xFF475569)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? '● LIVE' : '■ ENDED',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  session.name,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (session.venue != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white60, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        session.venue!,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _SessionStat(
                      label: 'Scanned',
                      value: scanCount.toString(),
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 24),
                    _SessionStat(
                      label: 'Expires',
                      value: fmt.format(session.expiresAt.toLocal()),
                      icon: Icons.access_time_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Share link card
          _InfoCard(
            title: 'Volunteer Share Link',
            subtitle: 'Opens scanner directly — no login needed',
            icon: Icons.link_rounded,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shareUrl,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _CopyButton(value: shareUrl),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => Share.share(
                    '🎟 Join as scanner for "${session.name}":\n$shareUrl',
                  ),
                  icon: const Icon(Icons.share_outlined,
                      color: AppColors.primary, size: 20),
                  tooltip: 'Share',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (isActive) ...[
            FilledButton.icon(
              onPressed: () => context
                  .push('${RoutePaths.adminScan}/${session.id}')
                  .then((_) => onRefreshCount()),
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text('Scan Attendance (Admin)'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 14),
          ],
          OutlinedButton.icon(
            onPressed: () => context.push(RoutePaths.reports),
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: const Text('Open Reports'),
          ),
          const SizedBox(height: 14),

          // Refresh count button
          OutlinedButton.icon(
            onPressed: onRefreshCount,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('Refresh Scan Count ($scanCount)'),
          ),

          if (isActive) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onEndSession,
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: const Text('End Session'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onReopen,
              icon: const Icon(Icons.play_circle_outline, size: 20),
              label: const Text('Re-open Session'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Delete Session'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Outfit',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Outfit',
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      },
      icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.primary),
      tooltip: 'Copy',
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primaryContainer,
        minimumSize: const Size(36, 36),
      ),
    );
  }
}
