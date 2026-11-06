import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../logic/auth/auth_provider.dart';

/// Forgot-password screen.
///
/// Step 1: enter the admin email, a one-time code is emailed.
/// Step 2: enter the code and a new password.
///
/// A code (instead of a link) works the same on the web app and the Android
/// app, with no deep links needed.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _resendSeconds = 60;

  late final TextEditingController _emailCtrl;
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  bool _codeSent = false;
  bool _notApproved = false;
  bool _loading = false;
  bool _obscure = true;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  String _friendly(Object e) {
    final msg = e is AuthException ? e.message : e.toString();
    final lower = msg.toLowerCase();
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many emails requested. Please wait a few minutes and try again.';
    }
    if (lower.contains('expired') || lower.contains('invalid')) {
      return 'That code is wrong or has expired. Check it, or ask for a new one.';
    }
    if (lower.contains('same') && lower.contains('password')) {
      return 'Choose a password different from your old one.';
    }
    return msg;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _notApproved = false;
    });
    try {
      final email = _emailCtrl.text.trim();
      final actions = ref.read(authActionsProvider);
      // Only approved admins can reset their password here. New people
      // must use "Request Access" and wait for approval first.
      final approved = await actions.isEmailApprovedAdmin(email);
      if (!mounted) return;
      if (!approved) {
        setState(() => _notApproved = true);
        return;
      }
      await actions.sendPasswordResetCode(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCooldown();
    } catch (e) {
      _showError(_friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _loading) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authActionsProvider)
          .sendPasswordResetCode(_emailCtrl.text.trim());
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent.')),
      );
    } catch (e) {
      _showError(_friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authActionsProvider).resetPasswordWithCode(
            email: _emailCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            newPassword: _passCtrl.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. You are signed in.'),
          backgroundColor: AppColors.success,
        ),
      );
      final repo = ref.read(authRepositoryProvider);
      final profile = await repo.fetchAdminProfile(repo.currentUserId ?? '');
      if (!mounted) return;
      context.go(profile?.status == AdminStatus.approved
          ? RoutePaths.adminDashboard
          : RoutePaths.pendingApproval);
    } catch (e) {
      _showError(_friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
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
            stops: [0.0, 0.5, 1.0],
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
                    const BrandLogo(size: 72),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.cardBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _codeSent ? _buildReset() : _buildEmail(),
                      ),
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

  Widget _title(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _button(String label, VoidCallback? onPressed) {
    return FilledButton(
      onPressed: _loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }

  Widget _buildEmail() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(
            'Forgot password?',
            'Enter your admin email and we will send you a code to reset it.',
          ),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Admin Email',
              prefixIcon: Icon(Icons.mail_outline, size: 20),
            ),
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Enter a valid email'
                : null,
            onFieldSubmitted: (_) => _sendCode(),
          ),
          if (_notApproved) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'This email is not an approved admin yet. New here? Use '
                '"Request Access" on the sign-in page and wait for approval. '
                'Already requested? Ask an admin to approve you.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _button('Send Code', _sendCode),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loading ? null : () => context.go(RoutePaths.adminLogin),
            child: const Text('Back to Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildReset() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(
            'Check your email',
            'We sent a code to ${_emailCtrl.text.trim()}. '
                'Enter it below and choose a new password.',
          ),
          TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Code from email',
              prefixIcon: Icon(Icons.pin_outlined, size: 20),
            ),
            validator: (v) =>
                (v == null || v.trim().length < 6) ? 'Enter the code' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 8) ? 'Min 8 characters' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_outline, size: 20),
            ),
            validator: (v) =>
                v != _passCtrl.text ? 'Passwords do not match' : null,
            onFieldSubmitted: (_) => _resetPassword(),
          ),
          const SizedBox(height: 20),
          _button('Reset Password', _resetPassword),
          const SizedBox(height: 4),
          TextButton(
            onPressed: (_cooldown > 0 || _loading) ? null : _resend,
            child: Text(
              _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
            ),
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _codeSent = false;
                      _codeCtrl.clear();
                    }),
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }
}
