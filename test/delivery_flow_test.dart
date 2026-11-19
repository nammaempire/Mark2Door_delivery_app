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
import 'package:mart2door_delivery/features/orders/domain/delivery_order.dart';
import 'package:mart2door_delivery/features/orders/presentation/delivery_screen.dart';
import 'package:mart2door_delivery/features/orders/presentation/orders_screen.dart';
import 'package:mart2door_delivery/features/orders/presentation/pickup_screen.dart';
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
    // Cash orders need the "collected" tick first.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-delivered-button')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('cash-collected-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delivered-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delivered-done-button')));
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.text('Active (1)'), findsOneWidget);
  });

  testWidgets('rejecting removes the order after confirmation', (tester) async {
    await _pumpApp(tester);
    await _tapKey(tester, 'reject-M2D2041');
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'logout-tile');
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
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
}
