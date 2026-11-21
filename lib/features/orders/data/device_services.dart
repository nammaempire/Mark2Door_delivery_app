import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/alerts/order_alerts.dart';
import 'photo_shrink.dart';

/// Takes the photo that proves an order was handed over.
///
/// Taking the photo and sending it are separate steps, so a rider with no
/// signal can still take the photo and finish the delivery; it is sent
/// when the phone is back online.
abstract interface class ProofPhotoService {
  /// Opens the camera, shrinks the photo for [orderId] to about 200 KB
  /// (never above 500 KB) and saves it on the phone. Returns where it was
  /// saved, or null if the rider backs out of the camera. Needs no signal.
  Future<String?> capture(String orderId);

  /// Sends the photo saved at [path] to the store and returns its web
  /// address. Throws when it cannot be sent, for example with no signal.
  Future<String> upload(String orderId, String path);
}

/// Sample-data stand-in: there is no camera, so a photo is pretended.
class FakeProofPhotoService implements ProofPhotoService {
  /// Set to true to act as a phone with no signal: sending fails.
  bool offline = false;

  @override
  Future<String?> capture(String orderId) async =>
      'sample://delivery-photo/$orderId';

  @override
  Future<String> upload(String orderId, String path) async {
    if (offline) throw const SocketException('No signal');
    return path;
  }
}

class FirebaseProofPhotoService implements ProofPhotoService {
  FirebaseProofPhotoService(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String?> capture(String orderId) async {
    // The camera already hands back a reduced photo: at most 1280 pixels
    // on its longer side, at 60% quality. That is usually 150 to 300 KB
    // however large the phone's camera is.
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 60,
    );
    if (shot == null) return null;
    // Anything still above the target is squeezed further, off the main
    // thread so the screen stays responsive.
    final bytes = await compute(shrinkJpeg, await shot.readAsBytes());
    // Kept in the app's own temporary folder until it has been sent.
    final file = File('${Directory.systemTemp.path}/m2d_proof_$orderId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<String> upload(String orderId, String path) async {
    final ref = _storage.ref('deliveries/$orderId.jpg');
    await ref
        .putFile(File(path), SettableMetadata(contentType: 'image/jpeg'))
        .timeout(const Duration(seconds: 60));
    return ref.getDownloadURL();
  }
}

/// Registers this phone for "new order" notifications.
abstract interface class PushService {
  /// Asks permission to notify and records this phone as the one to alert
  /// for the rider with [phone] (10 digits).
  Future<void> register(String phone);

  /// Stops alerts to this phone for [phone], when the rider logs out.
  Future<void> unregister(String phone);
}

class FakePushService implements PushService {
  @override
  Future<void> register(String phone) async {}

  @override
  Future<void> unregister(String phone) async {}
}

/// Saves the phone's Firebase Cloud Messaging token under
/// `rider_tokens/{phone}`. A server function reads it to notify the rider
/// when the admin assigns them an order.
class FirebasePushService implements PushService {
  FirebasePushService(this._messaging, this._db);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _whileOpen;

  DocumentReference<Map<String, dynamic>> _doc(String phone) =>
      _db.collection('rider_tokens').doc(phone);

  Future<void> _save(String phone, String token) => _doc(phone).set({
        'token': token,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Future<void> register(String phone) async {
    if (phone.isEmpty) return;
    // Android 13 and later ask the rider; earlier versions allow it already.
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) await _save(phone, token);
    // Google replaces tokens now and then; keep the saved one current.
    await _refresh?.cancel();
    _refresh = _messaging.onTokenRefresh.listen((t) => _save(phone, t));
    // With the app open on screen, Android shows nothing by itself, so the
    // app rings and shows the banner for each message that arrives.
    await _whileOpen?.cancel();
    _whileOpen = FirebaseMessaging.onMessage.listen((message) {
      final note = message.notification;
      if (note == null) return;
      OrderAlerts.show(
        title: note.title ?? 'New order',
        body: note.body ?? '',
      );
    });
  }

  @override
  Future<void> unregister(String phone) async {
    await _refresh?.cancel();
    _refresh = null;
    await _whileOpen?.cancel();
    _whileOpen = null;
    if (phone.isEmpty) return;
    await _doc(phone).delete();
  }
}
