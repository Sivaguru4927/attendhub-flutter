import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/volunteer_scan_repository.dart';
import '../../../logic/volunteer/session_validation_provider.dart';
import '../../shared/scan_station.dart';

/// Volunteer scanner (no login). Opened from the share link `/#/scan/<token>`.
class VolunteerScannerScreen extends ConsumerStatefulWidget {
  const VolunteerScannerScreen({super.key, required this.sessionToken});
  final String sessionToken;

  @override
  ConsumerState<VolunteerScannerScreen> createState() =>
      _VolunteerScannerScreenState();
}

class _VolunteerScannerScreenState
    extends ConsumerState<VolunteerScannerScreen> {
  String? _sessionId;
  String? _sessionName;
  String? _error;
  Timer? _poll;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _validate() async {
    try {
      final result = await ref
          .read(volunteerScanRepositoryProvider)
          .validateSession(widget.sessionToken);
      if (!mounted) return;
      switch (result) {
        case ValidSession(sessionId: final id, sessionName: final name):
          setState(() {
            _sessionId = id;
            _sessionName = name;
          });
          // The session can be ended by the admin at any time -> check often.
          _poll = Timer.periodic(const Duration(seconds: 6), (_) => _checkActive());
        case InvalidSession(reason: final r):
          setState(() => _error = _humanise(r));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not reach the server.\n$e');
    }
  }

  Future<void> _checkActive() async {
    final id = _sessionId;
    if (id == null || _leaving) return;
    try {
      final active = await ref
          .read(volunteerScanRepositoryProvider)
          .isSessionActive(id, widget.sessionToken);
      if (!active) _goEnded();
    } catch (_) {/* offline: try again next tick */}
  }

  void _goEnded() {
    if (_leaving || !mounted) return;
    _leaving = true;
    context.go(
        '${RoutePaths.sessionEnded}?sessionName=${Uri.encodeComponent(_sessionName ?? 'the session')}');
  }

  String _humanise(String r) {
    switch (r) {
      case 'SESSION_ENDED':
        return 'This session has already ended.';
      case 'INVALID_OR_NOT_FOUND':
        return 'Session not found. Please check your link.';
      default:
        return 'Access invalid. Contact your coordinator.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go(RoutePaths.volunteerJoin),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_sessionId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return ScanStation(
      title: _sessionName ?? '',
      onSubmit: (payload, method) =>
          ref.read(volunteerScanRepositoryProvider).recordScan(
                sessionId: _sessionId!,
                token: widget.sessionToken,
                payload: payload,
                method: method,
              ),
      onSessionEnded: _goEnded,
      onExit: () => context.go(RoutePaths.volunteerJoin),
    );
  }
}
