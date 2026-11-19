import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/delivery_order.dart';
import 'delivery_repository.dart';

/// Reads and updates the same `orders/{id}` documents as the customer app
/// and the admin web.
///
/// An order belongs to a rider through `riderPhone` (10 digits), which the
/// admin web copies onto the order when it assigns the rider. Security
/// rules compare that field with the signed-in rider's own phone number.
class FirestoreDeliveryRepository implements DeliveryRepository {
  FirestoreDeliveryRepository(this._db, {required this.riderPhone});

  final FirebaseFirestore _db;

  /// Signed-in rider's number without the country code; empty when signed
  /// out, in which case there are no orders to show.
  final String riderPhone;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');

  @override
  Stream<List<DeliveryOrder>> watchOrders() {
    if (riderPhone.isEmpty) return Stream.value(const []);
    // Sorted here rather than in the query so no composite index is needed.
    return _orders
        .where('riderPhone', isEqualTo: riderPhone)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => orderFromMap(d.id, d.data()))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  @override
  Future<void> accept(String orderId) =>
      _orders.doc(orderId).update({'status': DeliveryStatus.accepted.name});

  /// Clears the assignment so the admin can give the order to someone else.
  @override
  Future<void> reject(String orderId) => _orders.doc(orderId).update({
        'riderId': null,
        'riderName': null,
        'riderPhone': null,
      });

  @override
  Future<void> confirmPickup(String orderId) =>
      _orders.doc(orderId).update({'status': DeliveryStatus.pickedUp.name});

  @override
  Future<void> markDelivered(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    final cash = doc.data()?['paymentMethod'] == 'cod';
    await _orders.doc(orderId).update({
      'status': DeliveryStatus.delivered.name,
      'deliveredAt': DateTime.now().millisecondsSinceEpoch,
      // Cash is collected at the door, so a COD order is paid on delivery.
      if (cash) 'paymentStatus': 'paid',
    });
  }

  /// Maps an `orders/{id}` document to what the rider needs.
  static DeliveryOrder orderFromMap(String id, Map<String, dynamic> map) {
    int number(String key) => (map[key] as num?)?.toInt() ?? 0;
    DateTime? time(String key) => map[key] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((map[key] as num).toInt());

    final address =
        Map<String, dynamic>.from((map['address'] as Map?) ?? const {});
    final createdAt = time('createdAt') ?? DateTime.now();
    final status = DeliveryStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => DeliveryStatus.placed,
    );
    return DeliveryOrder(
      id: id,
      items: [
        for (final raw in (map['items'] as List?) ?? const [])
          DeliveryItem(
            name: (raw as Map)['name'] as String? ?? '',
            unit: raw['unit'] as String? ?? '',
            quantity: (raw['quantity'] as num?)?.toInt() ?? 0,
          ),
      ],
      // What is still owed at the door: the total less anything the
      // customer already paid from their m2d wallet.
      totalPaise: number('totalPaise') - number('walletAppliedPaise'),
      cashOnDelivery: map['paymentMethod'] == 'cod',
      customerName: address['name'] as String? ?? '',
      customerPhone: address['phone'] as String? ?? '',
      addressLine: address['line1'] as String? ?? '',
      landmark: address['landmark'] as String? ?? '',
      pincode: address['pincode'] as String? ?? '',
      status: status,
      createdAt: createdAt,
      etaAt: time('etaAt') ?? createdAt.add(const Duration(minutes: 30)),
      // Road distance needs the map integration, which is not connected
      // yet; 0 hides the distance on screen.
      distanceKm: 0,
      deliveredAt: time('deliveredAt'),
    );
  }
}
