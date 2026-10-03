import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/attendance_session.dart';
import '../../data/models/report_row.dart';
import '../../data/repositories/session_repository.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Sessions list provider
// ---------------------------------------------------------------------------

final sessionsListProvider =
    AsyncNotifierProvider<SessionsListNotifier, List<AttendanceSession>>(
        SessionsListNotifier.new);

class SessionsListNotifier extends AsyncNotifier<List<AttendanceSession>> {
  @override
  Future<List<AttendanceSession>> build() async {
    return ref.read(sessionRepositoryProvider).listSessions();
  }

  /// Refreshes the sessions list from Supabase.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(sessionRepositoryProvider).listSessions(),
    );
  }

  /// Creates a new session and prepends it to the list.
  Future<AttendanceSession> createSession({
    required String name,
    required List<String> masterListIds,
    String? venue,
    String? description,
    DateTime? eventDate,
    num durationHours = 8,
    bool allowDuplicateScans = false,
  }) async {
    final session = await ref.read(sessionRepositoryProvider).createSession(
          name: name,
          masterListIds: masterListIds,
          venue: venue,
          description: description,
          eventDate: eventDate,
          durationHours: durationHours,
          allowDuplicateScans: allowDuplicateScans,
        );
    state = AsyncData([session, ...state.valueOrNull ?? []]);
    return session;
  }

  /// Ends a session and updates the local list.
  Future<void> endSession(String sessionId) async {
    await ref.read(sessionRepositoryProvider).endSession(sessionId);
    await refresh();
  }

  /// Re-opens an ended session for [hours] more hours.
  Future<void> reopenSession(String sessionId, num hours) async {
    await ref.read(sessionRepositoryProvider).reopenSession(sessionId, hours);
    await refresh();
  }

  /// Permanently deletes a session and all of its scans.
  Future<void> deleteSession(String sessionId) async {
    await ref.read(sessionRepositoryProvider).deleteSession(sessionId);
    await refresh();
  }
}

// ---------------------------------------------------------------------------
// Single session detail provider
// ---------------------------------------------------------------------------

final sessionDetailProvider =
    FutureProvider.family<AttendanceSession?, String>((ref, sessionId) async {
  return ref.read(sessionRepositoryProvider).fetchSession(sessionId);
});

// ---------------------------------------------------------------------------
// Full attendance report of one session (JSON array from get_session_report)
// ---------------------------------------------------------------------------

final sessionReportProvider = FutureProvider.autoDispose
    .family<List<ReportRow>, String>((ref, sessionId) async {
  return ref.read(sessionRepositoryProvider).report(sessionId);
});

// ---------------------------------------------------------------------------
// Scan count provider (for session control screen live counter)
// ---------------------------------------------------------------------------

final scanCountProvider =
    FutureProvider.family<int, String>((ref, sessionId) async {
  return ref.read(sessionRepositoryProvider).scanCount(sessionId);
});
