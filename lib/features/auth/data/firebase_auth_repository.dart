import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  static AppUser? _map(User? user) => user == null
      ? null
      : AppUser(uid: user.uid, phone: user.phoneNumber ?? '');

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<String> sendOtp(String phone) {
    final completer = Completer<String>();

    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      // Android may read the SMS and sign in without the user typing it.
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
        } on FirebaseAuthException {
          // Fall back to manual entry; the OTP screen is still usable.
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(AuthFailure(_message(e)));
        }
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    ).catchError((Object e) {
      if (!completer.isCompleted) {
        completer.completeError(
          const AuthFailure('Could not send the OTP. Try again.'),
        );
      }
    });

    return completer.future;
  }

  @override
  Future<AppUser> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      final result = await _auth.signInWithCredential(credential);
      return _map(result.user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That mobile number looks invalid.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Check the code and try again.';
      case 'session-expired':
        return 'The OTP expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Could not verify your number. Try again.';
    }
  }
}
