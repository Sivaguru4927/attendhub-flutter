import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scan_event.dart';

/// Volunteer (no-login) operations. Every call goes through a SECURITY
/// DEFINER RPC that checks the secret share token.
class VolunteerScanRepository {
  VolunteerScanRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<SessionValidationResult> validateSession(String token) async {
    final res = await _supabase.rpc('validate_volunteer_session',
        params: {'p_token': token.trim()});
    final json = res as Map<String, dynamic>;
    if (json['valid'] != true) {
      return InvalidSession(
          reason: json['reason'] as String? ?? 'INVALID_OR_NOT_FOUND');
    }
    return ValidSession(
      sessionId: json['session_id'] as String,
      sessionName: json['session_name'] as String,
      venue: json['venue'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// true while the session is still open.
  Future<bool> isSessionActive(String sessionId, String token) async {
    final res = await _supabase.rpc('get_volunteer_session_status',
        params: {'p_session_id': sessionId, 'p_token': token.trim()});
    return (res as Map<String, dynamic>)['active'] == true;
  }

  Future<ScanResult> recordScan({
    required String sessionId,
    required String token,
    required String payload,
    String method = 'QR Camera',
  }) async {
    final res = await _supabase.rpc('record_volunteer_scan', params: {
      'p_session_id': sessionId,
      'p_token': token.trim(),
      'p_scanned_payload': payload.trim(),
      'p_method': method,
    });
    return ScanResult.fromRpcJson(res as Map<String, dynamic>);
  }
}

sealed class SessionValidationResult {
  const SessionValidationResult();
}

final class ValidSession extends SessionValidationResult {
  const ValidSession({
    required this.sessionId,
    required this.sessionName,
    this.venue,
    required this.expiresAt,
  });
  final String sessionId;
  final String sessionName;
  final String? venue;
  final DateTime expiresAt;
}

final class InvalidSession extends SessionValidationResult {
  const InvalidSession({required this.reason});
  final String reason;
}
