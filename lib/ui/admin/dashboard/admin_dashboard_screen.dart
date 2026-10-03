import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../logic/admin/session_control_provider.dart';
import '../../../logic/admin/master_list_provider.dart';
import '../../../logic/auth/auth_provider.dart';
import '../../../data/models/attendance_session.dart';
import 'widgets/stat_card.dart';
import 'widgets/recent_session_tile.dart';
import 'widgets/create_session_dialog.dart';

/// Admin dashboard — the home screen for approved admins.
///
/// Shows:
/// - Brand header + admin email chip
/// - Four stat cards (students, sessions, active sessions, today scans)
/// - Quick action buttons (New Session, Manage Students, View Reports)
/// - Recent sessions list
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsListProvider);
    final studentCountAsync = ref.watch(totalStudentsProvider);
    final profileAsync = ref.watch(adminProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('AttendHub'),
          ],
        ),
        actions: [
          profileAsync.when(
            data: (profile) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16, color: AppColors.primaryDark),
                label: Text(
                  profile?.email.split('@').first ?? 'Admin',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                backgroundColor: AppColors.primaryContainer,
                side: BorderSide.none,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authActionsProvider).signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sessionsListProvider);
          ref.invalidate(masterListsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ----------------------------------------------------------------
            // Stat cards row
            // ----------------------------------------------------------------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    StatCard(
                      icon: Icons.people_alt_outlined,
                      label: 'Students',
                      value: studentCountAsync.when(
                        data: (c) => c.toString(),
                        loading: () => '...',
                        error: (_, __) => '—',
                      ),
                      color: AppColors.primary,
                      backgroundColor: AppColors.primaryContainer,
                    ),
                    sessionsAsync.when(
                      data: (sessions) {
                        final active = sessions
                            .where((s) => s.status == SessionStatus.active)
                            .length;
                        return StatCard(
                          icon: Icons.wifi_tethering_rounded,
                          label: 'Active Sessions',
                          value: active.toString(),
                          color: active > 0 ? AppColors.success : AppColors.textMuted,
                          backgroundColor: active > 0
                              ? AppColors.successContainer
                              : AppColors.shimmer,
                        );
                      },
                      loading: () => const StatCard(
                        icon: Icons.wifi_tethering_rounded,
                        label: 'Active Sessions',
                        value: '...',
                        color: AppColors.textMuted,
                        backgroundColor: AppColors.shimmer,
                      ),
                      error: (_, __) => const StatCard(
                        icon: Icons.wifi_tethering_rounded,
                        label: 'Active Sessions',
                        value: '—',
                        color: AppColors.textMuted,
                        backgroundColor: AppColors.shimmer,
                      ),
                    ),
                    sessionsAsync.when(
                      data: (sessions) => StatCard(
                        icon: Icons.event_outlined,
                        label: 'Total Sessions',
                        value: sessions.length.toString(),
                        color: AppColors.accent,
                        backgroundColor: AppColors.accentContainer,
                      ),
                      loading: () => const StatCard(
                        icon: Icons.event_outlined,
                        label: 'Total Sessions',
                        value: '...',
                        color: AppColors.accent,
                        backgroundColor: AppColors.accentContainer,
                      ),
                      error: (_, __) => const StatCard(
                        icon: Icons.event_outlined,
                        label: 'Total Sessions',
                        value: '—',
                        color: AppColors.accent,
                        backgroundColor: AppColors.accentContainer,
                      ),
                    ),
                    const StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Today Scans',
                      value: '—',
                      color: AppColors.info,
                      backgroundColor: AppColors.primaryContainer,
                    ),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Quick actions
            // ----------------------------------------------------------------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'New Session',
                            color: AppColors.primary,
                            onTap: () => _showCreateSession(context, ref),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.group_outlined,
                            label: 'Students',
                            color: AppColors.accent,
                            onTap: () => context.push(RoutePaths.attendees),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.bar_chart_rounded,
                            label: 'Reports',
                            color: AppColors.info,
                            onTap: () => context.push(RoutePaths.reports),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Recent sessions header
            // ----------------------------------------------------------------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Sessions',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(sessionsListProvider.notifier).refresh(),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Sessions list
            // ----------------------------------------------------------------
            sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return SliverPadding(
                    padding: const EdgeInsets.all(32),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.event_busy_outlined,
                                size: 56, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No sessions yet.\nTap "New Session" to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RecentSessionTile(session: sessions[i]),
                      ),
                      childCount: sessions.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSession(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => CreateSessionDialog(
        onCreated: (session) {
          if (context.mounted) {
            context.push('${RoutePaths.sessionControl}/${session.id}');
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick action button
// ---------------------------------------------------------------------------
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
