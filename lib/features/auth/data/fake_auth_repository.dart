import 'dart:async';

import '../../../core/config/env.dart';
import '../../../core/storage/local_store.dart';
import '../domain/app_user.dart';
import 'auth_repository.dart';

/// Sample-data auth: any valid number works and the OTP is
/// [AppConfig.demoOtp]. The session survives restarts via [LocalStore].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._store) {
    final phone = _store.readString(LocalStore.demoSessionKey);
    if (phone != null) _user = AppUser(uid: 'demo-$phone', phone: phone);
  }

  final LocalStore _store;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<String> sendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return phone; // the phone doubles as the verification id
  }

  @override
  Future<AppUser> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (code != AppConfig.demoOtp) {
      throw const AuthFailure('Incorrect OTP. Check the code and try again.');
    }
    final user = AppUser(uid: 'demo-$verificationId', phone: verificationId);
    _user = user;
    await _store.writeString(LocalStore.demoSessionKey, user.phone);
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    await _store.writeString(LocalStore.demoSessionKey, null);
    _controller.add(null);
  }
}
