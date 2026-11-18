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

  String get displayId =>
      '#${(id.length <= 6 ? id : id.substring(id.length - 6)).toUpperCase()}';

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  int get cashToCollectPaise => cashOnDelivery ? totalPaise : 0;

  String get fullAddress => [
        addressLine,
        if (landmark.isNotEmpty) landmark,
        pincode,
      ].join(', ');

  bool get isNew => status == DeliveryStatus.placed;
  bool get isActive =>
      status == DeliveryStatus.accepted || status == DeliveryStatus.pickedUp;

  DeliveryOrder copyWith({DeliveryStatus? status, DateTime? deliveredAt}) =>
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
      );
}
