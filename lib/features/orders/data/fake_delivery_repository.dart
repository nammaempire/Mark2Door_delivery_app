import 'dart:async';

import '../domain/delivery_order.dart';
import 'delivery_repository.dart';

/// In-memory orders so every screen can be used without a backend. State
/// resets when the app restarts.
class FakeDeliveryRepository implements DeliveryRepository {
  FakeDeliveryRepository({DateTime? now}) : _orders = _seed(now ?? DateTime.now());

  List<DeliveryOrder> _orders;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<DeliveryOrder>> watchOrders() async* {
    yield _orders;
    yield* _changes.stream.map((_) => _orders);
  }

  Future<void> _update(
    String id,
    DeliveryOrder? Function(DeliveryOrder order) change,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final next = <DeliveryOrder>[];
    for (final o in _orders) {
      final updated = o.id == id ? change(o) : o;
      if (updated != null) next.add(updated); // null removes the order
    }
    _orders = next;
    _changes.add(null);
  }

  @override
  Future<void> accept(String orderId) =>
      _update(
        orderId,
        (o) => o.copyWith(
          status: DeliveryStatus.accepted,
          acceptedAt: DateTime.now(),
        ),
      );

  /// Reasons given for rejected orders, by order id.
  final rejections = <String, String>{};

  @override
  Future<void> reject(String orderId, String reason) {
    rejections[orderId] = reason;
    return _update(orderId, (_) => null);
  }

  @override
  Future<void> confirmPickup(String orderId) =>
      _update(orderId, (o) => o.copyWith(status: DeliveryStatus.pickedUp));

  /// Delivery photos handed in, by order id.
  final proofPhotos = <String, String>{};

  @override
  Future<void> markDelivered(
    String orderId, {
    required String photoUrl,
    DateTime? deliveredAt,
  }) {
    proofPhotos[orderId] = photoUrl;
    return _update(
      orderId,
      (o) => o.copyWith(
        status: DeliveryStatus.delivered,
        deliveredAt: deliveredAt ?? DateTime.now(),
      ),
    );
  }

  static List<DeliveryOrder> _seed(DateTime now) {
    DeliveryOrder order(
      String id,
      DeliveryStatus status,
      int minutesAgo,
      int totalPaise,
      bool cod,
      String name,
      String phone,
      String line,
      String landmark,
      String pincode,
      double km,
      List<DeliveryItem> items, {
      int? deliveredMinutesAgo,
      int? rating,
    }) {
      final placed = now.subtract(Duration(minutes: minutesAgo));
      return DeliveryOrder(
        id: id,
        items: items,
        totalPaise: totalPaise,
        cashOnDelivery: cod,
        customerName: name,
        customerPhone: phone,
        addressLine: line,
        landmark: landmark,
        pincode: pincode,
        status: status,
        createdAt: placed,
        // Sample orders count as just assigned, so they turn urgent after
        // five minutes on screen.
        assignedAt: now,
        etaAt: placed.add(const Duration(minutes: 30)),
        distanceKm: km,
        deliveredAt: deliveredMinutesAgo == null
            ? null
            : now.subtract(Duration(minutes: deliveredMinutesAgo)),
        rating: rating,
        // Cash from before today has already been handed to the store.
        cashHandedOver:
            deliveredMinutesAgo != null && deliveredMinutesAgo > 1000,
      );
    }

    const milk = DeliveryItem(name: 'Toned Milk', unit: '500 ml', quantity: 2);
    const eggs = DeliveryItem(name: 'Farm Eggs', unit: '6 pcs', quantity: 1);
    const atta = DeliveryItem(name: 'Chakki Atta', unit: '5 kg', quantity: 1);
    const tomato = DeliveryItem(name: 'Tomato Local', unit: '500 g', quantity: 2);
    const banana = DeliveryItem(name: 'Banana Robusta', unit: '6 pcs', quantity: 1);
    const oil = DeliveryItem(name: 'Sunflower Oil', unit: '1 L', quantity: 1);
    const tea = DeliveryItem(name: 'Assam Tea', unit: '250 g', quantity: 1);
    const chips = DeliveryItem(name: 'Potato Chips', unit: '90 g', quantity: 3);

    return [
      order('M2D2041', DeliveryStatus.placed, 3, 13200, true, 'Ananya Rao',
          '9845012345', '14, 2nd Main, Koramangala 4th Block', 'Near BDA Complex',
          '560034', 1.2, const [milk, eggs, tomato]),
      order('M2D2040', DeliveryStatus.placed, 7, 41700, false, 'Rahul Shetty',
          '9900123456', '7, Wind Tunnel Road, Murugeshpalya', '', '560038', 4.6,
          const [atta, oil, tea]),
      order('M2D2038', DeliveryStatus.accepted, 12, 9600, true, 'Meera Iyer',
          '9741098765', '221, 5th Cross, HSR Layout Sector 2', 'Opp. Park',
          '560102', 3.1, const [banana, milk]),
      order('M2D2035', DeliveryStatus.delivered, 95, 28400, true, 'Imran Khan',
          '9880456123', '3, Residency Road', '', '560001', 5.4,
          const [atta, eggs], deliveredMinutesAgo: 68, rating: 5),
      order('M2D2031', DeliveryStatus.delivered, 170, 17800, false,
          'Divya Nair', '9538011223', '45, Hosur Main Road, Bommanahalli', '',
          '560068', 4.0, const [oil, chips], deliveredMinutesAgo: 141),
      order('M2D2027', DeliveryStatus.delivered, 260, 7200, true,
          'Karthik Gowda', '9620334455', '18, 80 Feet Road, Koramangala', '',
          '560034', 0.8, const [tomato, banana], deliveredMinutesAgo: 236, rating: 4),
      order('M2D1998', DeliveryStatus.delivered, 1500, 52900, true,
          'Ananya Rao', '9845012345', '14, 2nd Main, Koramangala 4th Block', '',
          '560034', 1.2, const [atta, oil, tea, milk],
          deliveredMinutesAgo: 1472, rating: 5),
      order('M2D1993', DeliveryStatus.delivered, 1620, 11400, false,
          'Meera Iyer', '9741098765', '221, 5th Cross, HSR Layout Sector 2', '',
          '560102', 3.1, const [chips, eggs], deliveredMinutesAgo: 1590, rating: 4),
    ];
  }
}
