import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';

/// A delivery the rider finished without signal: the photo is on the phone
/// and the store has not been told yet.
@immutable
class PendingDelivery {
  const PendingDelivery({
    required this.orderId,
    required this.photoPath,
    required this.deliveredAt,
  });

  final String orderId;

  /// The delivery photo, saved on this phone.
  final String photoPath;

  /// When the rider handed the order over, not when it was sent.
  final DateTime deliveredAt;

  Map<String, dynamic> toMap() => {
        'photoPath': photoPath,
        'deliveredAt': deliveredAt.millisecondsSinceEpoch,
      };

  static PendingDelivery? fromMap(String orderId, Object? raw) {
    if (raw is! Map) return null;
    final path = raw['photoPath'];
    final at = raw['deliveredAt'];
    if (path is! String || at is! num) return null;
    return PendingDelivery(
      orderId: orderId,
      photoPath: path,
      deliveredAt: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}

/// Deliveries waiting to be sent, by order id.
final pendingDeliveriesProvider =
    NotifierProvider<PendingDeliveries, Map<String, PendingDelivery>>(
  PendingDeliveries.new,
);

/// Lets a rider finish a delivery with no signal.
///
/// "Mark delivered" first tries to send the photo and the update straight
/// away. If that does not go through, the delivery is kept on the phone
/// (it survives closing the app) and sent again every [retryEvery] until
/// it succeeds. Until then the app shows the order as delivered, and the
/// store and the customer still see it as out for delivery.
class PendingDeliveries extends Notifier<Map<String, PendingDelivery>> {
  static const storeKey = 'pending_deliveries';

  /// How long "Mark delivered" waits for the network before keeping the
  /// delivery on the phone instead.
  static const sendTimeout = Duration(seconds: 15);
  static const retryEvery = Duration(seconds: 30);

  Timer? _timer;
  bool _syncing = false;

  @override
  Map<String, PendingDelivery> build() {
    ref.onDispose(() => _timer?.cancel());
    final saved = ref.read(localStoreProvider).readJson(storeKey) ?? const {};
    final waiting = <String, PendingDelivery>{};
    for (final entry in saved.entries) {
      final p = PendingDelivery.fromMap(entry.key, entry.value);
      if (p != null) waiting[entry.key] = p;
    }
    if (waiting.isNotEmpty) {
      // Left over from last time the app was open: try again now.
      _startTimer();
      Future.microtask(sync);
    }
    return waiting;
  }

  /// Marks [orderId] delivered with the photo at [photoPath]. Returns true
  /// when the store has been told, false when the delivery was kept on the
  /// phone to be sent later.
  Future<bool> deliver(String orderId, String photoPath) async {
    final delivery = PendingDelivery(
      orderId: orderId,
      photoPath: photoPath,
      deliveredAt: DateTime.now(),
    );
    try {
      await _send(delivery).timeout(sendTimeout);
      _deletePhoto(delivery);
      return true;
    } catch (_) {
      _save({...state, orderId: delivery});
      _startTimer();
      return false;
    }
  }

  /// Tries to send every waiting delivery. Safe to call at any time.
  Future<void> sync() async {
    if (_syncing || state.isEmpty) return;
    _syncing = true;
    try {
      for (final delivery in state.values.toList()) {
        try {
          await _send(delivery).timeout(const Duration(seconds: 60));
        } catch (_) {
          continue; // still no signal: stays in the list
        }
        _save({...state}..remove(delivery.orderId));
        _deletePhoto(delivery);
      }
    } finally {
      _syncing = false;
      if (state.isEmpty) {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  Future<void> _send(PendingDelivery delivery) async {
    final url = await ref
        .read(proofPhotoServiceProvider)
        .upload(delivery.orderId, delivery.photoPath);
    await ref.read(deliveryRepositoryProvider).markDelivered(
          delivery.orderId,
          photoUrl: url,
          deliveredAt: delivery.deliveredAt,
        );
  }

  void _save(Map<String, PendingDelivery> next) {
    state = Map.unmodifiable(next);
    ref.read(localStoreProvider).writeJson(
          storeKey,
          next.isEmpty
              ? null
              : {for (final e in next.entries) e.key: e.value.toMap()},
        );
  }

  void _startTimer() {
    _timer ??= Timer.periodic(retryEvery, (_) => sync());
  }

  void _deletePhoto(PendingDelivery delivery) {
    try {
      final file = File(delivery.photoPath);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // A leftover photo in the app's temporary folder does no harm.
    }
  }
}
