/// App-wide constants shared across the AttendHub codebase.
library;

class AppConstants {
  AppConstants._();

  // Session / OTP
  static const int otpLength = 6;
  static const int sessionDefaultDurationHours = 8;
  static const int sessionExtendMinutes = 30;

  // Scanner UX
  static const int scanHoldMs = 500; // ms hold before confirmation fires
  static const int scanDebounceMs = 2000; // ms before same code is re-accepted
  static const int feedbackDisplayMs = 2500; // ms to show scan result badge

  // Hold-to-confirm: seconds a code must stay in view before the roll no is shown
  static const String holdSecondsKey = 'ah_hold_seconds';
  static const double defaultHoldSeconds = 1.0;
  static const int resultDisplayMs = 4000;

  // Pagination
  static const int studentsPageSize = 50;
  static const int scanEventsPageSize = 100;

  // Offline queue
  static const String offlineQueueKey = 'ah_offline_scan_queue';

  // Realtime channel names
  static const String sessionRealtimeChannel = 'session_status';
}
