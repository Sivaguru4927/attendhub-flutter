/// Central route path definitions for AttendHub.
abstract final class RoutePaths {
  // Admin
  static const String adminLogin = '/admin/login';
  static const String pendingApproval = '/admin/pending';
  static const String adminDashboard = '/admin/dashboard';
  static const String sessionControl = '/admin/sessions';
  static const String attendees = '/admin/attendees';
  static const String reports = '/admin/reports';
  static const String adminScan = '/admin/scan';

  // Volunteer (public)
  static const String volunteerJoin = '/join';
  static const String volunteerScan = '/scan';
  static const String sessionEnded = '/session-ended';
}
