import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';
import '../domain/delivery_order.dart';

final ordersProvider = StreamProvider<List<DeliveryOrder>>(
  (ref) => ref.watch(deliveryRepositoryProvider).watchOrders(),
);

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
  bool build() => ref.read(localStoreProvider).readString(_key) != 'false';

  void set(bool onDuty) {
    state = onDuty;
    ref.read(localStoreProvider).writeString(_key, '$onDuty');
  }
}

/// Totals for the header and the history page.
class DayStats {
  const DayStats({required this.deliveries, required this.cashPaise});

  final int deliveries;

  /// Cash collected on COD orders, to hand over to the store.
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
