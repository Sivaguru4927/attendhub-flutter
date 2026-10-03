import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/admin_profile.dart';
import '../../data/repositories/auth_repository.dart';

export '../../data/models/admin_profile.dart' show AdminStatus;

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the [AuthRepository] singleton.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// Streams the current user's [AdminStatus].
///
/// The router's redirect guard watches this to decide which routes are
/// accessible. Loading state maps to [null] (router does nothing).
final authStateProvider =
    StreamProvider<AdminStatus>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);

  await for (final authState in repo.authStateChanges) {
    final user = authState.session?.user;
    if (user == null) {
      yield AdminStatus.unauthenticated;
      continue;
    }

    // Resolve the admin approval status from `public.admins`.
    try {
      final profile = await repo.fetchAdminProfile(user.id);
      if (profile == null) {
        yield AdminStatus.pending;
      } else {
        yield profile.status;
      }
    } catch (_) {
      yield AdminStatus.unauthenticated;
    }
  }
});

/// Exposes the raw [AdminProfile] for display purposes (name, email, etc.).
final adminProfileProvider = FutureProvider<AdminProfile?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final uid = repo.currentUserId;
  if (uid == null) return null;
  return repo.fetchAdminProfile(uid);
});

// ---------------------------------------------------------------------------
// Auth action notifier
// ---------------------------------------------------------------------------

/// Provides imperative sign-in / sign-up / sign-out methods.
final authActionsProvider = Provider<AuthActions>((ref) {
  return AuthActions(ref.read(authRepositoryProvider));
});

class AuthActions {
  AuthActions(this._repo);
  final AuthRepository _repo;

  Future<void> signIn({required String email, required String password}) =>
      _repo.signIn(email: email, password: password);

  Future<void> signUp({required String email, required String password}) =>
      _repo.signUp(email: email, password: password);

  Future<void> signOut() => _repo.signOut();
}
