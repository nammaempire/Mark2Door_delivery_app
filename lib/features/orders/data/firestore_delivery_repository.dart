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

  /// Firestore saves a change on the phone straight away and sends it to
  /// the server when there is signal, also after the app is reopened. The
  /// write only "finishes" once the server has it, so waiting for that
  /// would freeze the screen with no signal. This waits a few seconds and
  /// then lets the rider carry on; the change is already safe on the phone.
  Future<void> _send(Future<void> write) =>
      write.timeout(const Duration(seconds: 4), onTimeout: () {});

  /// Reads an order from what is already on the phone, so it also works
  /// with no signal; asks the server only if the phone does not have it.
  Future<Map<String, dynamic>?> _read(String orderId) async {
    final doc = _orders.doc(orderId);
    try {
      final cached = await doc.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached.data();
    } on FirebaseException {
      // Not on the phone yet.
    }
    return (await doc.get()).data();
  }

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
  Future<void> accept(String orderId) => _send(
        _orders.doc(orderId).update({
          'status': DeliveryStatus.accepted.name,
          // Starts the clock for picking the order up from the store.
          'acceptedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );

  /// Clears the assignment so the admin can give the order to someone
  /// else, and leaves the rider's reason on the order for the admin.
  @override
  Future<void> reject(String orderId, String reason) async {
    final riderName = (await _read(orderId))?['riderName'];
    await _send(
      _orders.doc(orderId).update({
        'riderId': null,
        'riderName': null,
        'riderPhone': null,
        'assignedAt': null,
        'rejectReason': reason,
        'rejectedByName': riderName is String ? riderName : '',
        'rejectedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  @override
  Future<void> confirmPickup(String orderId) => _send(
        _orders.doc(orderId).update({'status': DeliveryStatus.pickedUp.name}),
      );

  @override
  Future<void> markDelivered(
    String orderId, {
    required String photoUrl,
    DateTime? deliveredAt,
  }) async {
    final cash = (await _read(orderId))?['paymentMethod'] == 'cod';
    await _send(
      _orders.doc(orderId).update({
        'status': DeliveryStatus.delivered.name,
        'deliveredAt':
            (deliveredAt ?? DateTime.now()).millisecondsSinceEpoch,
        // Proof of handover, shown to the admin on the order.
        'deliveryPhotoUrl': photoUrl,
        // Cash is collected at the door, so a COD order is paid on delivery.
        if (cash) 'paymentStatus': 'paid',
      }),
    );
  }

  @override
  Future<void> recordQrPayment(String orderId, {required String proofUrl}) =>
      // Not queued for later: the customer has just paid online, so there
      // is signal, and the store should see the proof straight away.
      _orders.doc(orderId).update({
        'codPaidBy': 'qr',
        'paymentProofUrl': proofUrl,
        'codPaidAt': DateTime.now().millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 20));

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
      paidByQr: map['codPaidBy'] == 'qr',
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
      assignedAt: time('assignedAt'),
      acceptedAt: time('acceptedAt'),
      rating: (map['riderRating'] as num?)?.toInt(),
      cashHandedOver: map['cashHandedOver'] as bool? ?? false,
      // The customer's own pin for the address, when they shared one.
      latitude: (address['lat'] as num?)?.toDouble(),
      longitude: (address['lng'] as num?)?.toDouble(),
    );
  }
}
