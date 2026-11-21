import '../domain/app_user.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// Emits the current user immediately, then on every sign-in / sign-out.
  Stream<AppUser?> authStateChanges();

  /// Sends an OTP to [phone] (E.164) and returns a verification id.
  /// Throws [AuthFailure] with a user-facing message.
  Future<String> sendOtp(String phone);

  /// Throws [AuthFailure] when the code is wrong or expired.
  Future<AppUser> verifyOtp({
    required String verificationId,
    required String code,
  });

  Future<void> signOut();

  /// True when the OTP was confirmed in the last few minutes. Deleting an
  /// account is only allowed then, so the app asks for a fresh OTP first.
  bool get signedInRecently;

  /// Permanently removes the login and signs out. Needs
  /// [signedInRecently]; throws [AuthFailure] with a user-facing message.
  Future<void> deleteAccount();
}
