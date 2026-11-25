class Constants {
  // Base URL is provided at build time.
  // - Flutter Web (Vercel): --dart-define=API_BASE_URL=https://<vercel-app>.vercel.app
  //   (same-origin; /api/* routes to Vercel serverless proxy which forwards to Render)
  // - Android APK: --dart-define=API_BASE_URL=https://<render-service>.onrender.com
  //   (direct to Render with X-API-Key from secure storage)
  // - Local dev: default http://localhost:8080
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // Authentication endpoints (relative to baseUrl)
  static const String otpSend = '/api/auth/otp/send';
  static const String otpResend = '/api/auth/otp/resend';
  static const String otpVerify = '/api/auth/otp/verify';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
