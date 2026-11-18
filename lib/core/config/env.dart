/// Compile-time configuration, supplied with `--dart-define`.
abstract final class Env {
  /// false => in-memory sample data. The Firebase implementations are
  /// added when the three apps are connected to one project.
  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');
}

abstract final class AppConfig {
  static const String appName = 'mart2door Delivery';
  static const String countryCode = '+91';

  /// OTP accepted by the sample-data auth repository.
  static const String demoOtp = '123456';

  /// Pickup point shown to riders. Will come from the admin's store
  /// settings once Firebase is connected.
  static const String storeName = 'mart2door Store';
  static const String storeAddress = '80 Feet Road, Koramangala 4th Block, '
      'Bengaluru 560034';
}
