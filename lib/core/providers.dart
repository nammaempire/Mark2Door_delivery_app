import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/fake_auth_repository.dart';
import '../features/orders/data/delivery_repository.dart';
import '../features/orders/data/fake_delivery_repository.dart';
import 'storage/local_store.dart';

/// Composition root: the only place that knows which implementation backs
/// each interface. Swapping in Firebase later changes only this file.

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FakeAuthRepository(ref.watch(localStoreProvider)),
);

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => FakeDeliveryRepository(),
);
