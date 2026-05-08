class ApiConfig {
  // ════════════════════════════════════════════════════════════════
  // ✏️  CHANGE ONLY THIS LINE when you switch networks / locations
  static const String serverIp = '192.168.0.7';
  // ════════════════════════════════════════════════════════════════
  //
  // HOW TO FIND YOUR IP:
  //   1. Open PowerShell → run: ipconfig
  //   2. Look for "Wireless LAN adapter Wi-Fi" → IPv4 Address
  //   3. Paste that value above, then run: flutter run
  //
  // ════════════════════════════════════════════════════════════════

  static String get baseUrl => 'http://$serverIp:8000';

  // ── Auth ─────────────────────────────────────────────────────
  static String get login => '$baseUrl/login';
  static String get register => '$baseUrl/register';
  static String get sendOtp => '$baseUrl/send-otp';
  static String get verifyOtp => '$baseUrl/verify-otp';
  static String get forgotPassword => '$baseUrl/forgot-password';
  static String get resetPassword => '$baseUrl/reset-password';

  // ── Dashboard & Alerts ───────────────────────────────────────
  static String get dashboardStats => '$baseUrl/dashboard/stats';
  static String get alerts => '$baseUrl/alerts';
  static String resolveAlert(dynamic id) => '$baseUrl/alerts/resolve/$id';

  // ── KYC & Tourists ───────────────────────────────────────────
  static String get kycPending => '$baseUrl/kyc/pending';
  static String kycDocuments(String uid) => '$baseUrl/kyc/$uid/documents';
  static String kycDownload(String uid, String t) =>
      '$baseUrl/kyc/$uid/download/$t';
  static String kycApprove(String uid) => '$baseUrl/kyc/$uid/approve';
  static String kycReject(String uid) => '$baseUrl/kyc/$uid/reject';

  static String get tourists => '$baseUrl/tourists';
  static String touristProfile(String id) => '$baseUrl/tourists/$id';

  // ── Anomaly / Geofencing ─────────────────────────────────────
  static String get trackLocation => '$baseUrl/anomaly/track-location';
  static String get anomalyAlerts => '$baseUrl/anomaly/alerts';
  static String get anomalyConfig => '$baseUrl/anomaly/config';
  static String resolveAnomalyAlert(String id) =>
      '$baseUrl/anomaly/alerts/resolve/$id';

  // Live tourist locations for authority map
  static String get touristLocations => '$baseUrl/anomaly/tourist-locations';

  // Danger zones & AI assessment
  static String get dangerZones => '$baseUrl/anomaly/danger-zones';
  static String dangerZonesNear(
    double lat,
    double lng, {
    double radiusKm = 5,
  }) =>
      '$baseUrl/anomaly/danger-zones?latitude=$lat&longitude=$lng&radius_km=$radiusKm';
  static String get assessZone => '$baseUrl/anomaly/assess-zone';
}
