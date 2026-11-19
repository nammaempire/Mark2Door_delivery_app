import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Compile-time configuration, supplied with `--dart-define`.
abstract final class Env {
  /// The app uses Firebase unless it is started with
  /// `--dart-define=USE_FIREBASE=false`, which switches to in-memory sample
  /// data. Automated tests always run on sample data.
  static final bool useFirebase = _firebaseFlag && !_runningTests;

  static const bool _firebaseFlag =
      bool.fromEnvironment('USE_FIREBASE', defaultValue: true);

  static bool get _runningTests =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
}

abstract final class AppConfig {
  static const String appName = 'mart2door Delivery';
  static const String countryCode = '+91';

  /// OTP accepted by the sample-data auth repository.
  static const String demoOtp = '123456';

}
