import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mart2door_delivery/app.dart';
import 'package:mart2door_delivery/core/providers.dart';
import 'package:mart2door_delivery/core/storage/local_store.dart';
import 'package:mart2door_delivery/features/orders/application/delivery_providers.dart';
import 'package:mart2door_delivery/features/orders/application/pending_deliveries.dart';
import 'package:mart2door_delivery/features/orders/data/device_services.dart';
import 'package:mart2door_delivery/features/orders/data/fake_delivery_repository.dart';
import 'package:mart2door_delivery/features/orders/data/firestore_delivery_repository.dart';
import 'package:mart2door_delivery/features/orders/data/photo_shrink.dart';
import 'package:mart2door_delivery/features/orders/domain/delivery_order.dart';
import 'package:mart2door_delivery/features/orders/presentation/orders_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Photo size, delivering without signal, and the customer's map pin.

/// A photo that is as hard to compress as a photo can be: random colour in
/// every pixel, saved at high quality.
Uint8List _noisyPhoto(int width, int height) {
  final random = Random(7);
  final photo = img.Image(width: width, height: height);
  for (final pixel in photo) {
    pixel
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
  }
  return img.encodeJpg(photo, quality: 95);
}

DeliveryOrder _find(List<DeliveryOrder> orders, String id) =>
    orders.firstWhere((o) => o.id == id);

void main() {
  group('delivery photo size', () {
    test('a multi-megabyte photo is brought under 500 KB', () {
      final big = _noisyPhoto(2400, 1800);
      expect(big.length, greaterThan(3 * 1024 * 1024));

      final small = shrinkJpeg(big);
      expect(small.length, lessThanOrEqualTo(proofMaxBytes));
      // Still a readable picture, no larger than 1280 on its longer side.
      final decoded = img.decodeJpg(small)!;
      expect(decoded.width, lessThanOrEqualTo(1280));
      expect(decoded.width, greaterThan(decoded.height));
    });

    test('a portrait photo keeps its shape', () {
      final small = shrinkJpeg(_noisyPhoto(1200, 1600));
      expect(small.length, lessThanOrEqualTo(proofMaxBytes));
      final decoded = img.decodeJpg(small)!;
      expect(decoded.height, greaterThan(decoded.width));
      expect(decoded.height, lessThanOrEqualTo(1280));
    });

    test('a photo that is already small is left exactly as it is', () {
      final photo = img.Image(width: 800, height: 600);
      img.fill(photo, color: img.ColorRgb8(120, 30, 40));
      final bytes = img.encodeJpg(photo, quality: 80);
      expect(bytes.length, lessThan(proofTargetBytes));
      expect(identical(shrinkJpeg(bytes), bytes), isTrue);
    });

    test('something that is not a picture is passed through', () {
      final junk = Uint8List.fromList(List.filled(300 * 1024, 7));
      expect(shrinkJpeg(junk), junk);
    });
  });

  group('delivering without signal', () {
    late SharedPreferences prefs;
    late FakeDeliveryRepository repo;
    late FakeProofPhotoService photos;

    ProviderContainer open() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deliveryRepositoryProvider.overrideWithValue(repo),
          proofPhotoServiceProvider.overrideWithValue(photos),
        ],
      );
      // Keep the order stream running, as the screens do.
      container.listen(ordersProvider, (_, __) {});
      return container;
    }

    Future<List<DeliveryOrder>> shown(ProviderContainer container) async {
      await container.read(serverOrdersProvider.future);
      // Let the stream's latest value reach the derived list.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return container.read(ordersProvider).requireValue;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(
        {LocalStore.demoSessionKey: '+919900011111'},
      );
      prefs = await SharedPreferences.getInstance();
      repo = FakeDeliveryRepository();
      photos = FakeProofPhotoService();
      // M2D2038 starts accepted; pick it up so it can be delivered.
      await repo.confirmPickup('M2D2038');
    });

    test('with signal the delivery goes straight to the store', () async {
      final container = open();
      addTearDown(container.dispose);
      final sent = await container
          .read(pendingDeliveriesProvider.notifier)
          .deliver('M2D2038', 'sample://photo');
      expect(sent, isTrue);
      expect(container.read(pendingDeliveriesProvider), isEmpty);
      expect(repo.proofPhotos['M2D2038'], 'sample://photo');
      final order = _find(await shown(container), 'M2D2038');
      expect(order.status, DeliveryStatus.delivered);
      expect(order.awaitingSync, isFalse);
    });

    test('without signal it is kept, shown as delivered, and sent later',
        () async {
      photos.offline = true;
      final container = open();
      final sent = await container
          .read(pendingDeliveriesProvider.notifier)
          .deliver('M2D2038', 'sample://photo');
      expect(sent, isFalse);

      // The store has heard nothing yet...
      expect(repo.proofPhotos, isEmpty);
      // ...but the rider's app treats the order as done, cash included.
      var order = _find(await shown(container), 'M2D2038');
      expect(order.status, DeliveryStatus.delivered);
      expect(order.awaitingSync, isTrue);
      expect(order.cashOwedPaise, 9600);
      expect(order.isActive, isFalse);

      // Trying again while still offline changes nothing.
      await container.read(pendingDeliveriesProvider.notifier).sync();
      expect(container.read(pendingDeliveriesProvider).keys, ['M2D2038']);
      container.dispose();

      // The app is closed and opened again: the delivery is still waiting.
      final reopened = open();
      addTearDown(reopened.dispose);
      final waiting = reopened.read(pendingDeliveriesProvider);
      expect(waiting.keys, ['M2D2038']);
      expect(waiting['M2D2038']!.photoPath, 'sample://photo');
      final deliveredAt = waiting['M2D2038']!.deliveredAt;

      // Signal is back.
      photos.offline = false;
      await reopened.read(pendingDeliveriesProvider.notifier).sync();
      expect(reopened.read(pendingDeliveriesProvider), isEmpty);
      expect(repo.proofPhotos['M2D2038'], 'sample://photo');
      order = _find(await shown(reopened), 'M2D2038');
      expect(order.status, DeliveryStatus.delivered);
      expect(order.awaitingSync, isFalse);
      // Recorded at the time of the handover, not when it was sent.
      expect(order.deliveredAt, deliveredAt);
      expect(prefs.getString(PendingDeliveries.storeKey), isNull);
    });

    testWidgets('the rider is told it is saved, and can send it later', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      photos.offline = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            deliveryRepositoryProvider.overrideWithValue(repo),
            proofPhotoServiceProvider.overrideWithValue(photos),
          ],
          child: const DeliveryApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 3)); // splash
      await tester.pumpAndSettle();

      Future<void> tap(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Active (1)'));
      await tester.pumpAndSettle();
      await tap('continue-M2D2038');
      await tap('mark-delivered-button');
      await tap('cash-collected-checkbox');
      await tap('take-photo-button');
      await tap('confirm-delivered-button');

      expect(find.text('Delivered'), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-offline-note')), findsOneWidget);
      await tap('delivered-done-button');

      expect(find.byType(OrdersScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-sync-banner')), findsOneWidget);
      expect(find.text('Active (0)'), findsOneWidget);
      expect(repo.proofPhotos, isEmpty);

      photos.offline = false;
      await tap('send-now-button');
      expect(find.byKey(const ValueKey('pending-sync-banner')), findsNothing);
      expect(repo.proofPhotos.keys, ['M2D2038']);
    });
  });

  group("customer's map pin", () {
    test('an order carries the pin when the customer shared one', () {
      final pinned = FirestoreDeliveryRepository.orderFromMap('o1', {
        'status': 'pickedUp',
        'address': {
          'name': 'Navi',
          'line1': '12, 4th Cross',
          'pincode': '560034',
          'lat': 12.9352,
          'lng': 77.6245,
        },
      });
      expect(pinned.hasPin, isTrue);
      expect(pinned.latitude, 12.9352);
      expect(pinned.longitude, 77.6245);
      // Kept when the order changes status.
      expect(pinned.copyWith(status: DeliveryStatus.delivered).hasPin, isTrue);

      final typed = FirestoreDeliveryRepository.orderFromMap('o2', {
        'status': 'pickedUp',
        'address': {'line1': '12, 4th Cross', 'pincode': '560034'},
      });
      expect(typed.hasPin, isFalse);
    });
  });
}
