import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  const AppUser({required this.uid, required this.phone});

  final String uid;

  /// E.164 format, e.g. +919876543210.
  final String phone;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.uid == uid && other.phone == phone;

  @override
  int get hashCode => Object.hash(uid, phone);
}

/// Error with a message that is safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => 'AuthFailure($message)';
}
