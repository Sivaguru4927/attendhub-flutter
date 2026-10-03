import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_profile.dart';

/// Handles Supabase Auth operations (login, signup, sign-out, session
/// streaming) and mirrors the auth state into the [AdminStatus] enum consumed
/// by the router guards.
class AuthRepository {
  AuthRepository(this._supabase);

  final SupabaseClient _supabase;

  // ---------------------------------------------------------------------------
  // Auth operations
  // ---------------------------------------------------------------------------

  /// Signs in with email & password. Throws [AuthException] on failure.
  Future<void> signIn({required String email, required String password}) =>
      _supabase.auth.signInWithPassword(email: email, password: password);

  /// Registers a new account. The database trigger automatically inserts a
  /// `pending` row in `public.admins`.
  Future<void> signUp({required String email, required String password}) =>
      _supabase.auth.signUp(email: email, password: password);

  /// Signs out the current user.
  Future<void> signOut() => _supabase.auth.signOut();

  // ---------------------------------------------------------------------------
  // Admin profile fetch
  // ---------------------------------------------------------------------------

  /// Fetches the [AdminProfile] for [userId] from `public.admins`.
  Future<AdminProfile?> fetchAdminProfile(String userId) async {
    var res = await _supabase
        .from('admins')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (res == null) {
      // The new schema has no trigger on auth.users, so create the pending row.
      final user = _supabase.auth.currentUser;
      if (user != null && user.id == userId) {
        try {
          await _supabase.from('admins').insert({
            'id': userId,
            'email': user.email,
            'status': 'pending',
          });
        } catch (_) {}
        res = await _supabase
            .from('admins')
            .select()
            .eq('id', userId)
            .maybeSingle();
      }
    }
    if (res == null) return null;
    return AdminProfile.fromJson(res);
  }

  /// Returns the current user's UID or null.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Live stream of auth state changes.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Admin team management (approved admin only)
  // ---------------------------------------------------------------------------

  /// Lists all admins visible to the current approved admin.
  Future<List<AdminProfile>> listAdmins() async {
    final rows = await _supabase.from('admins').select().order('created_at');
    return (rows as List)
        .map((r) => AdminProfile.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Approves a pending admin. Only callable by an already approved admin.
  Future<void> approveAdmin(String targetId) async {
    await _supabase.from('admins').update({
      'status': AdminStatus.approved.value,
      'approved_by': currentUserId,
    }).eq('id', targetId);
  }

  /// Revokes an admin account.
  Future<void> revokeAdmin(String targetId) async {
    await _supabase.from('admins').update({
      'status': AdminStatus.revoked.value,
    }).eq('id', targetId);
  }
}
