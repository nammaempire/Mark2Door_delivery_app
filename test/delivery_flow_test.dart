import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door_delivery/core/providers.dart';
import 'package:mart2door_delivery/features/orders/data/firestore_delivery_repository.dart';
import 'package:mart2door_delivery/app.dart';
import 'package:mart2door_delivery/core/storage/local_store.dart';
import 'package:mart2door_delivery/features/auth/presentation/login_screen.dart';
import 'package:mart2door_delivery/features/orders/application/delivery_providers.dart';
import 'package:mart2door_delivery/features/orders/data/fake_delivery_repository.dart';
import 'package:mart2door_delivery/features/orders/data/rider_repository.dart';
import 'package:mart2door_delivery/features/orders/domain/delivery_order.dart';
import 'package:mart2door_delivery/features/orders/presentation/delivery_screen.dart';
import 'package:mart2door_delivery/features/orders/presentation/orders_screen.dart';
import 'package:mart2door_delivery/features/orders/presentation/pickup_screen.dart';
import 'package:mart2door_delivery/features/profile/rider_documents.dart';
import 'package:mart2door_delivery/features/profile/rider_documents_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end journeys against the sample-data repositories.
Future<void> _pumpApp(WidgetTester tester, {bool signedIn = true}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(
    signedIn ? {LocalStore.demoSessionKey: '+919900011111'} : {},
  );
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const DeliveryApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 3)); // splash
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  // Rows far down a long page are built only once scrolled near.
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rider logs in with OTP and lands on orders', (tester) async {
    await _pumpApp(tester, signedIn: false);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('phone-field')),
      '9900011111',
    );
    await tester.tap(find.text('Get OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('otp-field')), '123456');
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.text('New (2)'), findsOneWidget);
    expect(find.text('Active (1)'), findsOneWidget);
  });

  testWidgets('accept, pick up, deliver a cash order end to end', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _tapKey(tester, 'accept-M2D2041');
    // Accepting switches to the Active tab.
    expect(find.text('New (1)'), findsOneWidget);
    expect(find.text('Active (2)'), findsOneWidget);

    await _tapKey(tester, 'continue-M2D2041');
    expect(find.byType(PickupScreen), findsOneWidget);
    // Pickup cannot be confirmed until every item is ticked.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-pickup-button')),
          )
          .onPressed,
      isNull,
    );
    for (var i = 0; i < 3; i++) {
      await _tapKey(tester, 'item-$i');
    }
    expect(find.text('3 of 3 picked'), findsOneWidget);
    await _tapKey(tester, 'confirm-pickup-button');

    expect(find.byType(DeliveryScreen), findsOneWidget);
    expect(find.text('Collect cash from customer'), findsOneWidget);

    await _tapKey(tester, 'mark-delivered-button');
    bool canConfirm() =>
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('confirm-delivered-button')),
            )
            .onPressed !=
        null;
    // A cash order needs both the delivery photo and the "collected" tick.
    expect(canConfirm(), isFalse);
    await tester.tap(find.byKey(const ValueKey('cash-collected-checkbox')));
    await tester.pumpAndSettle();
    expect(canConfirm(), isFalse, reason: 'no photo yet');
    await tester.tap(find.byKey(const ValueKey('take-photo-button')));
    await tester.pumpAndSettle();
    expect(find.text('Photo added · tap to retake'), findsOneWidget);
    expect(canConfirm(), isTrue);
    await tester.tap(find.byKey(const ValueKey('confirm-delivered-button')));
    await tester.pumpAndSettle();
    // The photo went in with the delivery.
    final deliveries = ProviderScope.containerOf(
      tester.element(find.byType(DeliveryApp)),
    ).read(deliveryRepositoryProvider) as FakeDeliveryRepository;
    expect(deliveries.proofPhotos.values.single, startsWith('sample://'));
    expect(find.text('Delivered'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delivered-done-button')));
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.text('Active (1)'), findsOneWidget);
  });

  testWidgets('a cash order paid by QR scan needs a proof photo, and then no '
      'cash is collected', (tester) async {
    await _pumpApp(tester);
    await _tapKey(tester, 'accept-M2D2041');
    await _tapKey(tester, 'continue-M2D2041');
    for (var i = 0; i < 3; i++) {
      await _tapKey(tester, 'item-$i');
    }
    await _tapKey(tester, 'confirm-pickup-button');
    expect(find.text('Collect cash from customer'), findsOneWidget);

    await _tapKey(tester, 'qr-pay-button');
    expect(find.byKey(const ValueKey('store-qr')), findsOneWidget);
    // No proof photo, no confirmation.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('qr-confirm-button')),
          )
          .onPressed,
      isNull,
    );
    await _tapKey(tester, 'qr-proof-button');
    expect(find.text('Photo taken. Tap to retake'), findsOneWidget);
    await _tapKey(tester, 'qr-confirm-button');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeliveryApp)),
    );
    final repo =
        container.read(deliveryRepositoryProvider) as FakeDeliveryRepository;
    expect(repo.qrProofs['M2D2041'], isNotNull);
    final order = container
        .read(ordersProvider)
        .requireValue
        .firstWhere((o) => o.id == 'M2D2041');
    expect(order.paidByQr, isTrue);
    expect(order.collectsCash, isFalse);
    expect(order.cashToCollectPaise, 0);

    // The screen now says it is paid, and delivery asks only for a photo.
    expect(find.text('Paid by QR scan'), findsOneWidget);
    expect(find.byKey(const ValueKey('qr-pay-button')), findsNothing);
    await tester.pump(const Duration(seconds: 5)); // snackbar goes away
    await tester.pumpAndSettle();
    await _tapKey(tester, 'mark-delivered-button');
    expect(
      find.byKey(const ValueKey('cash-collected-checkbox')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('take-photo-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delivered-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsOneWidget);
  });

  testWidgets('a new rider submits documents before seeing orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(
      {LocalStore.demoSessionKey: '+919900011111'},
    );
    final prefs = await SharedPreferences.getInstance();
    final documents = FakeRiderDocumentsRepository(submitted: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          riderDocumentsRepositoryProvider.overrideWithValue(documents),
        ],
        child: const DeliveryApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // No orders yet: the documents form comes first.
    expect(find.byType(RiderDocumentsScreen), findsOneWidget);
    expect(find.byType(OrdersScreen), findsNothing);

    // Nothing filled in: it does not go through.
    await _tapKey(tester, 'submit-documents-button');
    expect(find.text('Enter your full permanent address'), findsOneWidget);
    expect(find.text('Enter the 12-digit Aadhaar number'), findsOneWidget);
    expect(await documents.fetch('9900011111'), isNull);

    await _tapKey(tester, 'dob-field');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('address-field')),
      '18, 3rd Cross, Ejipura, Bengaluru 560047',
    );
    await tester.enterText(
      find.byKey(const ValueKey('licence-field')),
      'ka0120150012345',
    );
    await tester.enterText(
      find.byKey(const ValueKey('aadhaar-field')),
      '1234 1234 1234',
    );
    await _tapKey(tester, 'licence-camera');
    // One photo is not enough.
    await _tapKey(tester, 'submit-documents-button');
    expect(find.text('Add a photo of both documents.'), findsOneWidget);
    await _tapKey(tester, 'aadhaar-gallery');
    await _tapKey(tester, 'submit-documents-button');

    final saved = await documents.fetch('9900011111');
    expect(saved, isNotNull);
    expect(saved!.licenceNumber, 'KA0120150012345');
    expect(saved.aadhaarNumber, '123412341234');
    expect(saved.address, '18, 3rd Cross, Ejipura, Bengaluru 560047');
    expect(saved.licenceUrl, 'sample://licence');
    expect(saved.aadhaarUrl, 'sample://aadhaar');
    expect(
      RiderDocuments.ageOn(saved.dateOfBirth, DateTime.now()),
      greaterThanOrEqualTo(RiderDocuments.minimumAge),
    );
    // Submitted: the orders open.
    expect(find.byType(OrdersScreen), findsOneWidget);
  });

  test('rider documents: age and Aadhaar checks', () {
    expect(RiderDocuments.ageOn(DateTime(2000, 6, 15), DateTime(2026, 6, 14)), 25);
    expect(RiderDocuments.ageOn(DateTime(2000, 6, 15), DateTime(2026, 6, 15)), 26);
    expect(RiderDocuments.aadhaarProblem('1234 5678 9012'), isNull);
    expect(RiderDocuments.aadhaarProblem('12345'), isNotNull);
    final docs = RiderDocuments.fromMap(
      RiderDocuments(
        dateOfBirth: DateTime(1996, 4, 12),
        address: 'A',
        licenceNumber: 'L',
        aadhaarNumber: '123412341234',
      ).toMap(),
    );
    expect(docs.dateOfBirth, DateTime(1996, 4, 12));
  });

  testWidgets('rejecting removes the order after confirmation', (tester) async {
    await _pumpApp(tester);
    await _tapKey(tester, 'reject-M2D2041');
    // The order cannot be rejected without a reason.
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('confirm-reject-button')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('reject-reason-field')),
      'Bike has a puncture',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-reject-button')));
    await tester.pumpAndSettle();
    final repo = ProviderScope.containerOf(
      tester.element(find.byType(OrdersScreen)),
    ).read(deliveryRepositoryProvider) as FakeDeliveryRepository;
    expect(repo.rejections['M2D2041'], 'Bike has a puncture');
    expect(find.text('New (1)'), findsOneWidget);
    expect(find.text('Order #D2041'), findsNothing);
  });

  testWidgets('going offline hides new orders', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('duty-switch')));
    await tester.pumpAndSettle();
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('history and profile tabs open; logout returns to login', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Cash to hand over'), findsOneWidget);
    // Today's two cash orders; yesterday's cash was already handed over.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('cash-to-hand-over'))).data,
      '₹356',
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    // The name the admin registered the rider with.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('profile-name'))).data,
      'Suresh Kumar',
    );
    // Four of the sample deliveries were rated: 5, 4, 5 and 4 stars.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('profile-rating'))).data,
      '4.5 · 4 ratings',
    );
    await _tapKey(tester, 'logout-tile');
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('account deletion waits for open orders, then needs an OTP', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'delete-account-button');
    expect(find.text('Finish your orders first'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Clear the rider's orders: reject the new ones, deliver the active one.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeliveryApp)),
    );
    final repo = container.read(deliveryRepositoryProvider);
    // The sample repository answers after a short delay, so each call is
    // started, the clock moved on, and only then awaited.
    Future<void> run(Future<void> Function() action) async {
      final done = action();
      await tester.pump(const Duration(seconds: 1));
      await done;
    }

    for (final o in container.read(ordersProvider).value!) {
      if (o.isNew) await run(() => repo.reject(o.id, 'Leaving'));
      if (o.isActive) {
        if (o.status == DeliveryStatus.accepted) {
          await run(() => repo.confirmPickup(o.id));
        }
        await run(() => repo.markDelivered(o.id, photoUrl: 'sample://x'));
      }
    }
    await tester.pumpAndSettle();

    await _tapKey(tester, 'delete-account-button');
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('confirm-otp-field')),
      '123456',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-otp-button')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    final riders =
        container.read(riderRepositoryProvider) as FakeRiderRepository;
    expect(riders.deleted, {'9900011111'});
  });

  testWidgets('a new order waiting over five minutes is marked urgent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(
      {LocalStore.demoSessionKey: '+919900011111'},
    );
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Orders that were assigned six minutes ago.
          deliveryRepositoryProvider.overrideWithValue(
            FakeDeliveryRepository(
              now: DateTime.now().subtract(const Duration(minutes: 6)),
            ),
          ),
        ],
        child: const DeliveryApp(),
      ),
    );
    // The urgent border keeps blinking, so settle by time.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('urgent-M2D2041')), findsOneWidget);
    expect(find.byKey(const ValueKey('urgent-frame-M2D2041')), findsOneWidget);
    expect(find.textContaining('Urgent · waiting 6 min'), findsWidgets);
  });

  test('urgent when not accepted in 5 minutes or not picked up in 10', () {
    final now = DateTime(2026, 11, 20, 12);
    int ago(int minutes) =>
        now.subtract(Duration(minutes: minutes)).millisecondsSinceEpoch;
    DeliveryOrder order(
      DeliveryStatus status, {
      required int assigned,
      int? accepted,
    }) =>
        FirestoreDeliveryRepository.orderFromMap('o1', {
          'status': status.name,
          'createdAt': ago(60),
          'assignedAt': ago(assigned),
          if (accepted != null) 'acceptedAt': ago(accepted),
        });
    // New: five minutes from assignment.
    expect(order(DeliveryStatus.placed, assigned: 4).isUrgentAt(now), isFalse);
    expect(order(DeliveryStatus.placed, assigned: 5).isUrgentAt(now), isTrue);
    // Accepted: ten minutes from acceptance, however long ago it was assigned.
    expect(
      order(DeliveryStatus.accepted, assigned: 30, accepted: 9).isUrgentAt(now),
      isFalse,
    );
    expect(
      order(DeliveryStatus.accepted, assigned: 30, accepted: 10)
          .isUrgentAt(now),
      isTrue,
    );
    // Once picked up, the order is on its way and no longer flagged.
    expect(
      order(DeliveryStatus.pickedUp, assigned: 60, accepted: 50)
          .isUrgentAt(now),
      isFalse,
    );
  });

  testWidgets('going off duty tells the store, and the greeting uses the name',
      (tester) async {
    await _pumpApp(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('greeting'))).data,
      'Hello, Suresh',
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'profile-duty-switch');
    final riders = ProviderScope.containerOf(
      tester.element(find.byType(DeliveryApp)),
    ).read(riderRepositoryProvider) as FakeRiderRepository;
    expect(riders.availability, {'9900011111': false});
  });

  test('cash to hand over drops to zero once the store confirms it', () {
    DeliveryOrder order({required bool handedOver, String method = 'cod'}) =>
        FirestoreDeliveryRepository.orderFromMap('o', {
          'status': 'delivered',
          'paymentMethod': method,
          'totalPaise': 10000,
          'walletAppliedPaise': 2500,
          'cashHandedOver': handedOver,
        });
    // Only cash orders count, and only the part paid in cash.
    expect(
      cashToHandOver([
        order(handedOver: false),
        order(handedOver: false, method: 'online'),
      ]),
      7500,
    );
    expect(cashToHandOver([order(handedOver: true)]), 0);
  });

  test('rating is the average of the deliveries customers rated', () {
    DeliveryOrder rated(int? stars) => FirestoreDeliveryRepository.orderFromMap(
          'o',
          {'status': 'delivered', 'riderRating': stars},
        );
    final none = RatingSummary.of([rated(null)]);
    expect(none.count, 0);
    expect(none.label, 'New');
    final some = RatingSummary.of([rated(5), rated(4), rated(null), rated(4)]);
    expect(some.count, 3);
    expect(some.label, '4.3');
  });

  group('DayStats', () {
    test('counts only today\'s deliveries and their cash', () async {
      final now = DateTime(2026, 11, 19, 15);
      final orders = await FakeDeliveryRepository(now: now).watchOrders().first;
      final stats = DayStats.forDay(orders, now);
      // Seed: three delivered today (two cash), two delivered yesterday.
      expect(stats.deliveries, 3);
      expect(stats.cashPaise, 28400 + 7200);
    });

    test('paid-online orders have nothing to collect', () async {
      final orders = await FakeDeliveryRepository().watchOrders().first;
      final paid = orders.firstWhere((o) => !o.cashOnDelivery);
      expect(paid.cashToCollectPaise, 0);
      expect(
        orders.where((o) => o.status == DeliveryStatus.placed),
        hasLength(2),
      );
    });
  });

  test('Firestore order maps to what the rider collects and delivers', () {
    final order = FirestoreDeliveryRepository.orderFromMap('abc123XYZ', {
      'items': [
        {'name': 'Milk', 'unit': '500 ml', 'quantity': 2, 'pricePaise': 2700},
      ],
      'totalPaise': 9200,
      'walletAppliedPaise': 2500,
      'paymentMethod': 'cod',
      'status': 'accepted',
      'createdAt': 1795000000000,
      'address': {
        'name': 'Navi',
        'phone': '9876543210',
        'line1': '12, 4th Cross',
        'landmark': 'Near park',
        'pincode': '627004',
      },
    });
    expect(order.displayId, '#123XYZ');
    expect(order.itemCount, 2);
    // Cash at the door is the total less what the wallet already paid.
    expect(order.cashToCollectPaise, 6700);
    expect(order.isActive, isTrue);
    expect(order.fullAddress, '12, 4th Cross, Near park, 627004');
    expect(
      order.etaAt,
      DateTime.fromMillisecondsSinceEpoch(1795000000000)
          .add(const Duration(minutes: 30)),
    );

    final paidOnline = FirestoreDeliveryRepository.orderFromMap('x', {
      'totalPaise': 5000,
      'paymentMethod': 'online',
      'status': 'placed',
    });
    expect(paidOnline.cashToCollectPaise, 0);
    expect(paidOnline.isNew, isTrue);
  });

  testWidgets('a number the admin has not added is told how to get access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(
      {LocalStore.demoSessionKey: '+919900011111'},
    );
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          riderProfileProvider.overrideWith((ref) async => null),
        ],
        child: const DeliveryApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3)); // splash
    await tester.pumpAndSettle();
    expect(find.text('This number is not registered'), findsOneWidget);
    expect(find.textContaining('+919900011111'), findsOneWidget);
  });
  testWidgets('Help on the profile page lists the questions with answers', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'help-tile');
    expect(find.byKey(const ValueKey('help-list')), findsOneWidget);
    expect(find.text('How do I go offline?'), findsOneWidget);
    // The answer opens when the question is tapped.
    await tester.tap(find.text('How do I go offline?'));
    await tester.pumpAndSettle();
    expect(
      find.text('Switch off "Available for orders" on the Profile page.'),
      findsOneWidget,
    );
  });

  testWidgets('terms and privacy policy open from the profile page', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'terms-tile');
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('legal-body')))
          .data,
      'Sample terms and conditions text.',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tapKey(tester, 'privacy-tile');
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('legal-body')))
          .data,
      'Sample privacy policy text.',
    );
  });

}
