import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../data/repositories/volunteer_scan_repository.dart';
import '../../../logic/volunteer/session_validation_provider.dart';

/// Volunteers paste the link they were sent (or just the code at its end).
class VolunteerJoinScreen extends ConsumerStatefulWidget {
  const VolunteerJoinScreen({super.key});

  @override
  ConsumerState<VolunteerJoinScreen> createState() =>
      _VolunteerJoinScreenState();
}

class _VolunteerJoinScreenState extends ConsumerState<VolunteerJoinScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Accepts a full link (…/#/scan/<token>) or the bare token.
  String _extractToken(String input) {
    final t = input.trim();
    final i = t.lastIndexOf('scan/');
    var token = i >= 0 ? t.substring(i + 5) : t;
    token = token.split(RegExp(r'[?#\s/]')).first;
    return token;
  }

  Future<void> _join() async {
    final token = _extractToken(_ctrl.text);
    if (token.isEmpty) {
      setState(() => _error = 'Paste the session link you received.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r =
          await ref.read(volunteerScanRepositoryProvider).validateSession(token);
      if (!mounted) return;
      switch (r) {
        case ValidSession():
          context.go('${RoutePaths.volunteerScan}/$token');
        case InvalidSession(reason: final reason):
          setState(() => _error = reason == 'SESSION_ENDED'
              ? 'This session has already ended.'
              : 'Session not found. Check the link and try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF), Color(0xFFD1FAE5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const BrandLogo(size: 64, showTagline: false),
                    const SizedBox(height: 8),
                    const Text('Volunteer Scanner',
                        style: TextStyle(
                            fontSize: 15, color: AppColors.textSecondary)),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Join a session',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          const Text(
                            'Paste the link your coordinator shared. '
                            'Opening the link directly also works.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _ctrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'https://…/#/scan/…',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                            onSubmitted: (_) => _join(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 13)),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _join,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : const Text('Join Session',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No login needed. Your access ends when the session ends.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
