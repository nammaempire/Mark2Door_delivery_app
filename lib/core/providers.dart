import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/fake_auth_repository.dart';
import '../features/auth/data/firebase_auth_repository.dart';
import '../features/orders/data/delivery_repository.dart';
import '../features/orders/data/device_services.dart';
import '../features/orders/data/fake_delivery_repository.dart';
import '../features/orders/data/firestore_delivery_repository.dart';
import '../features/orders/data/rider_repository.dart';
import 'config/env.dart';
import 'storage/local_store.dart';

/// Composition root: the only place that knows which implementation backs
/// each interface. Screens depend on the interfaces, so sample data and
/// Firebase are interchangeable.

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return Env.useFirebase
      ? FirebaseAuthRepository(FirebaseAuth.instance)
      : FakeAuthRepository(ref.watch(localStoreProvider));
});

/// Signed-in rider's phone without the country code; empty when signed out.
/// Rebuilds on sign-in and sign-out so order streams follow the session.
final riderPhoneProvider = StreamProvider<String>((ref) {
  String digits(String? phone) =>
      (phone ?? '').replaceFirst(AppConfig.countryCode, '');
  final auth = ref.watch(authRepositoryProvider);
  return auth.authStateChanges().map((user) => digits(user?.phone));
});

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  if (!Env.useFirebase) return FakeDeliveryRepository();
  return FirestoreDeliveryRepository(
    FirebaseFirestore.instance,
    riderPhone: ref.watch(riderPhoneProvider).valueOrNull ?? '',
  );
});

final riderRepositoryProvider = Provider<RiderRepository>((ref) {
  return Env.useFirebase
      ? FirestoreRiderRepository(FirebaseFirestore.instance)
      : FakeRiderRepository();
});

/// The admin's record for the signed-in rider; null data means this phone
/// number has not been added under Riders in the admin web.
final riderProfileProvider = FutureProvider<RiderProfile?>((ref) async {
  final phone = await ref.watch(riderPhoneProvider.future);
  return ref.watch(riderRepositoryProvider).fetchRider(phone);
});

/// Pickup point, live from the admin's settings.
final storeInfoProvider = Provider<StoreInfo>((ref) {
  return ref.watch(_storeInfoStreamProvider).valueOrNull ?? StoreInfo.unknown;
});

final _storeInfoStreamProvider = StreamProvider<StoreInfo>(
  (ref) => ref.watch(riderRepositoryProvider).watchStore(),
);

final proofPhotoServiceProvider = Provider<ProofPhotoService>((ref) {
  return Env.useFirebase
      ? FirebaseProofPhotoService(FirebaseStorage.instance)
      : FakeProofPhotoService();
});

final pushServiceProvider = Provider<PushService>((ref) {
  return Env.useFirebase
      ? FirebasePushService(
          FirebaseMessaging.instance,
          FirebaseFirestore.instance,
        )
      : FakePushService();
});

/// Registers this phone for new-order notifications once a rider is signed
/// in. Watched by the home screen; failing to register never blocks the app.
final pushRegistrationProvider = FutureProvider<void>((ref) async {
  final phone = await ref.watch(riderPhoneProvider.future);
  if (phone.isEmpty) return;
  try {
    await ref.watch(pushServiceProvider).register(phone);
    debugPrint('PUSH: registered this phone for rider $phone');
  } on Exception catch (e) {
    debugPrint('PUSH: could not register rider $phone: $e');
    // No Play services, no network, or permission refused: the rider still
    // sees orders in the app.
  }
});
