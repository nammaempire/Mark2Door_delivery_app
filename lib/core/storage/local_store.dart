import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the instance loaded before `runApp`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPreferencesProvider)),
);

/// Thin typed wrapper over SharedPreferences for small device-local state.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const pincodeKey = 'pincode';
  static const cartKey = 'cart';
  static const addressKey = 'address';
  static const demoSessionKey = 'demo_session_phone';

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  Map<String, dynamic>? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null; // corrupted entry: treat as absent
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic>? value) =>
      writeString(key, value == null ? null : jsonEncode(value));
}
