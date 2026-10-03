import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../data/models/attendance_session.dart';
import '../../../logic/admin/session_control_provider.dart';
import '../../shared/scan_station.dart';

/// Admin scanner for one session (flashlight, hold time, confirm step).
class AdminScanScreen extends ConsumerWidget {
  const AdminScanScreen({super.key, required this.sessionId});
  final String sessionId;

  void _exit(BuildContext context, WidgetRef ref) {
    ref.invalidate(scanCountProvider(sessionId));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.adminDashboard);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionDetailProvider(sessionId));
    return async.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Scan')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (session) {
        if (session == null || session.status == SessionStatus.ended) {
          return Scaffold(
            appBar: AppBar(title: const Text('Scan')),
            body: const Center(child: Text('This session is not active.')),
          );
        }
        return ScanStation(
          title: session.name,
          onSubmit: (payload, method) =>
              ref.read(sessionRepositoryProvider).recordAdminScan(
                    sessionId: sessionId,
                    payload: payload,
                    method: method,
                  ),
          onExit: () => _exit(context, ref),
        );
      },
    );
  }
}
