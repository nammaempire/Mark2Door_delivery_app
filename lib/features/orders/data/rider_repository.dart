import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A delivery partner as registered by the admin (`riders/{id}`).
@immutable
class RiderProfile {
  const RiderProfile({required this.name, required this.active});

  final String name;

  /// False when the admin has marked the rider off duty.
  final bool active;
}

/// Where riders pick orders up; managed in the admin web (`settings/store`).
@immutable
class StoreInfo {
  const StoreInfo({required this.name, required this.address});

  static const unknown = StoreInfo(
    name: 'mart2door Store',
    address: 'Ask the store for the pickup address',
  );

  final String name;
  final String address;
}

abstract interface class RiderRepository {
  /// The rider registered with [phone] (10 digits), or null when the admin
  /// has not added this number under Riders.
  Future<RiderProfile?> fetchRider(String phone);

  Stream<StoreInfo> watchStore();
}

class FakeRiderRepository implements RiderRepository {
  static const store = StoreInfo(
    name: 'mart2door Store',
    address: '80 Feet Road, Koramangala 4th Block, Bengaluru 560034',
  );

  @override
  Future<RiderProfile?> fetchRider(String phone) async =>
      const RiderProfile(name: 'Delivery partner', active: true);

  @override
  Stream<StoreInfo> watchStore() => Stream.value(store);
}

class FirestoreRiderRepository implements RiderRepository {
  FirestoreRiderRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<RiderProfile?> fetchRider(String phone) async {
    if (phone.isEmpty) return null;
    final snap = await _db
        .collection('riders')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    return RiderProfile(
      name: data['name'] as String? ?? '',
      active: data['active'] as bool? ?? true,
    );
  }

  @override
  Stream<StoreInfo> watchStore() =>
      _db.collection('settings').doc('store').snapshots().map((doc) {
        final data = doc.data() ?? const {};
        final name = (data['storeName'] as String? ?? '').trim();
        final address = (data['storeAddress'] as String? ?? '').trim();
        return StoreInfo(
          name: name.isEmpty ? StoreInfo.unknown.name : name,
          address: address.isEmpty ? StoreInfo.unknown.address : address,
        );
      });
}
