import 'package:flutter/foundation.dart';

/// Lifecycle shared with the customer app and admin web. For a rider:
/// placed = assigned and waiting to be accepted, accepted = heading to the
/// store, pickedUp = on the way to the customer.
enum DeliveryStatus { placed, accepted, pickedUp, delivered, cancelled }

@immutable
class DeliveryItem {
  const DeliveryItem({
    required this.name,
    required this.unit,
    required this.quantity,
  });

  final String name;
  final String unit;
  final int quantity;
}

/// An order as the delivery partner needs to see it.
@immutable
class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.items,
    required this.totalPaise,
    required this.cashOnDelivery,
    required this.customerName,
    required this.customerPhone,
    required this.addressLine,
    required this.landmark,
    required this.pincode,
    required this.status,
    required this.createdAt,
    required this.etaAt,
    required this.distanceKm,
    this.deliveredAt,
    this.assignedAt,
    this.acceptedAt,
    this.rating,
    this.cashHandedOver = false,
    this.awaitingSync = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final List<DeliveryItem> items;
  final int totalPaise;

  /// true => collect [totalPaise] in cash; false => already paid online.
  final bool cashOnDelivery;
  final String customerName;
  final String customerPhone;
  final String addressLine;
  final String landmark;
  final String pincode;
  final DeliveryStatus status;
  final DateTime createdAt;

  /// Time promised to the customer.
  final DateTime etaAt;

  /// Store to customer, by road.
  final double distanceKm;
  final DateTime? deliveredAt;

  /// When the admin gave this order to the rider; null on orders assigned
  /// before this was recorded.
  final DateTime? assignedAt;

  /// When the rider accepted the order; null on orders accepted before this
  /// was recorded.
  final DateTime? acceptedAt;

  /// How long a new order may wait for the rider before it is urgent.
  static const urgentAfter = Duration(minutes: 5);

  /// How long an accepted order may wait at the store before it is urgent.
  static const pickupUrgentAfter = Duration(minutes: 10);

  /// When the order started waiting on the rider's next step: since it was
  /// assigned while new, since it was accepted while waiting for pickup.
  DateTime get waitingSince => status == DeliveryStatus.accepted
      ? acceptedAt ?? assignedAt ?? createdAt
      : assignedAt ?? createdAt;

  /// True once a new order has waited [urgentAfter] without being accepted,
  /// or an accepted one [pickupUrgentAfter] without being picked up.
  bool isUrgentAt(DateTime now) {
    final waited = now.difference(waitingSince);
    if (isNew) return waited >= urgentAfter;
    return status == DeliveryStatus.accepted && waited >= pickupUrgentAfter;
  }

  String get displayId =>
      '#${(id.length <= 6 ? id : id.substring(id.length - 6)).toUpperCase()}';

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  int get cashToCollectPaise => cashOnDelivery ? totalPaise : 0;

  /// Stars (1 to 5) the customer gave this delivery; null until rated.
  final int? rating;

  /// True once the store confirmed it received this order's cash.
  final bool cashHandedOver;

  /// Delivered with no signal: the app shows it as delivered, and the
  /// store is told as soon as the phone is back online.
  final bool awaitingSync;

  /// Exact spot the customer pinned for this address in their app; null
  /// when they did not, in which case the map looks the address up.
  final double? latitude;
  final double? longitude;

  bool get hasPin => latitude != null && longitude != null;

  /// Cash collected for this order that the rider still has to hand over.
  int get cashOwedPaise =>
      status == DeliveryStatus.delivered && !cashHandedOver
          ? cashToCollectPaise
          : 0;

  String get fullAddress => [
        addressLine,
        if (landmark.isNotEmpty) landmark,
        pincode,
      ].join(', ');

  bool get isNew => status == DeliveryStatus.placed;
  bool get isActive =>
      status == DeliveryStatus.accepted || status == DeliveryStatus.pickedUp;

  DeliveryOrder copyWith({
    DeliveryStatus? status,
    DateTime? deliveredAt,
    DateTime? acceptedAt,
    bool? awaitingSync,
  }) =>
      DeliveryOrder(
        id: id,
        items: items,
        totalPaise: totalPaise,
        cashOnDelivery: cashOnDelivery,
        customerName: customerName,
        customerPhone: customerPhone,
        addressLine: addressLine,
        landmark: landmark,
        pincode: pincode,
        status: status ?? this.status,
        createdAt: createdAt,
        etaAt: etaAt,
        distanceKm: distanceKm,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        assignedAt: assignedAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        rating: rating,
        cashHandedOver: cashHandedOver,
        awaitingSync: awaitingSync ?? this.awaitingSync,
        latitude: latitude,
        longitude: longitude,
      );
}
