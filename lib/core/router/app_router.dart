import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/auth/auth_provider.dart';
import '../../ui/admin/auth/login_screen.dart';
import '../../ui/admin/auth/pending_approval_screen.dart';
import '../../ui/admin/dashboard/admin_dashboard_screen.dart';
import '../../ui/admin/sessions/session_control_screen.dart';
import '../../ui/admin/attendees/attendee_master_screen.dart';
import '../../ui/admin/reports/attendance_reports_screen.dart';
import '../../ui/admin/scan/admin_scan_screen.dart';
import '../../ui/volunteer/join/volunteer_join_screen.dart';
import '../../ui/volunteer/scanner/volunteer_scanner_screen.dart';
import '../../ui/volunteer/ended/session_ended_screen.dart';
import 'route_paths.dart';

class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(Ref ref) {
    ref.listen<AsyncValue<AdminStatus>>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// Provides the singleton [GoRouter] instance.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRouterNotifier(ref);

  return GoRouter(
    initialLocation: RoutePaths.adminLogin,
    refreshListenable: refreshNotifier,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider);
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      final isVolunteerRoute =
          state.matchedLocation.startsWith('/scan') ||
          state.matchedLocation.startsWith('/join') ||
          state.matchedLocation.startsWith('/session-ended');

      // Volunteer routes are always publicly accessible.
      if (isVolunteerRoute) return null;

      return authState.when(
        data: (adminStatus) {
          switch (adminStatus) {
            case AdminStatus.unauthenticated:
              if (isAdminRoute &&
                  state.matchedLocation != RoutePaths.adminLogin) {
                return RoutePaths.adminLogin;
              }
              return null;

            case AdminStatus.pending:
              if (state.matchedLocation != RoutePaths.pendingApproval) {
                return RoutePaths.pendingApproval;
              }
              return null;

            case AdminStatus.approved:
              if (state.matchedLocation == RoutePaths.adminLogin ||
                  state.matchedLocation == RoutePaths.pendingApproval) {
                return RoutePaths.adminDashboard;
              }
              return null;

            case AdminStatus.revoked:
              return RoutePaths.adminLogin;
          }
        },
        loading: () => null,
        error: (_, __) => null,
      );
    },
    routes: [
      // -----------------------------------------------------------------------
      // Admin routes
      // -----------------------------------------------------------------------
      GoRoute(
        path: RoutePaths.adminLogin,
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.pendingApproval,
        name: 'pending-approval',
        builder: (_, __) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminDashboard,
        name: 'dashboard',
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '${RoutePaths.sessionControl}/:sessionId',
        name: 'session-control',
        builder: (_, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return SessionControlScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '${RoutePaths.adminScan}/:sessionId',
        name: 'admin-scan',
        builder: (_, state) => AdminScanScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.attendees,
        name: 'attendees',
        builder: (_, __) => const AttendeeMasterScreen(),
      ),
      GoRoute(
        path: RoutePaths.reports,
        name: 'reports',
        builder: (_, __) => const AttendanceReportsScreen(),
      ),

      // -----------------------------------------------------------------------
      // Volunteer routes (public)
      // -----------------------------------------------------------------------
      GoRoute(
        path: RoutePaths.volunteerJoin,
        name: 'volunteer-join',
        builder: (_, __) => const VolunteerJoinScreen(),
      ),
      GoRoute(
        path: '${RoutePaths.volunteerScan}/:sessionToken',
        name: 'volunteer-scanner',
        builder: (_, state) {
          final token = state.pathParameters['sessionToken']!;
          return VolunteerScannerScreen(sessionToken: token);
        },
      ),
      GoRoute(
        path: RoutePaths.sessionEnded,
        name: 'session-ended',
        builder: (_, state) {
          final sessionName =
              state.uri.queryParameters['sessionName'] ?? 'the session';
          return SessionEndedScreen(sessionName: sessionName);
        },
      ),
    ],

    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
