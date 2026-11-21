import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';
import '../domain/delivery_order.dart';
import 'pending_deliveries.dart';

/// The rider's orders exactly as the store has them.
final serverOrdersProvider = StreamProvider<List<DeliveryOrder>>(
  (ref) => ref.watch(deliveryRepositoryProvider).watchOrders(),
);

/// The rider's orders as the app shows them: an order delivered with no
/// signal counts as delivered here straight away, before the store knows.
final ordersProvider = Provider<AsyncValue<List<DeliveryOrder>>>((ref) {
  final waiting = ref.watch(pendingDeliveriesProvider);
  return ref.watch(serverOrdersProvider).whenData(
        (orders) => waiting.isEmpty
            ? orders
            : [
                for (final o in orders)
                  waiting.containsKey(o.id) &&
                          o.status == DeliveryStatus.pickedUp
                      ? o.copyWith(
                          status: DeliveryStatus.delivered,
                          deliveredAt: waiting[o.id]!.deliveredAt,
                          awaitingSync: true,
                        )
                      : o,
              ],
      );
});

final orderProvider = Provider.family<AsyncValue<DeliveryOrder?>, String>(
  (ref, id) => ref.watch(ordersProvider).whenData((orders) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }),
);

/// Whether the rider is taking orders. Remembered across restarts.
final onDutyProvider = NotifierProvider<DutyController, bool>(
  DutyController.new,
);

class DutyController extends Notifier<bool> {
  static const _key = 'on_duty';

  @override
  bool build() {
    // The store's record wins when it loads, so a rider the admin marked
    // off duty sees that in the app too.
    ref.listen(riderProfileProvider, (_, next) {
      final active = next.valueOrNull?.active;
      if (active != null && active != state) _remember(active);
    });
    return ref.read(localStoreProvider).readString(_key) != 'false';
  }

  void _remember(bool onDuty) {
    state = onDuty;
    ref.read(localStoreProvider).writeString(_key, '$onDuty');
  }

  /// Switches duty on or off and tells the store, so the admin sees the
  /// rider as Available or Off duty. The switch still works offline; the
  /// store is told on a best-effort basis.
  void set(bool onDuty) {
    _remember(onDuty);
    final phone = ref.read(riderPhoneProvider).valueOrNull ?? '';
    if (phone.isEmpty) return;
    unawaited(
      ref
          .read(riderRepositoryProvider)
          .setActive(phone, active: onDuty)
          .catchError((Object _) {}),
    );
  }
}

/// Totals for the header and the history page.
class DayStats {
  const DayStats({required this.deliveries, required this.cashPaise});

  final int deliveries;

  /// Cash collected on COD orders delivered that day.
  final int cashPaise;

  factory DayStats.forDay(List<DeliveryOrder> orders, DateTime day) {
    var deliveries = 0, cash = 0;
    for (final o in orders) {
      final at = o.deliveredAt;
      if (o.status != DeliveryStatus.delivered || at == null) continue;
      if (at.year == day.year && at.month == day.month && at.day == day.day) {
        deliveries++;
        cash += o.cashToCollectPaise;
      }
    }
    return DayStats(deliveries: deliveries, cashPaise: cash);
  }
}

/// Cash from delivered cash-on-delivery orders that the store has not yet
/// confirmed receiving. Drops back to zero when the admin marks it received.
int cashToHandOver(List<DeliveryOrder> orders) =>
    orders.fold(0, (sum, o) => sum + o.cashOwedPaise);

/// The rider's star rating across every delivery a customer has rated.
class RatingSummary {
  const RatingSummary({required this.count, required this.average});

  factory RatingSummary.of(List<DeliveryOrder> orders) {
    final stars = [
      for (final o in orders)
        if (o.rating != null) o.rating!,
    ];
    return RatingSummary(
      count: stars.length,
      average: stars.isEmpty
          ? 0
          : stars.reduce((a, b) => a + b) / stars.length,
    );
  }

  final int count;

  /// 0 when nobody has rated yet.
  final double average;

  /// "4.6", or "New" before the first rating.
  String get label => count == 0 ? 'New' : average.toStringAsFixed(1);
}
