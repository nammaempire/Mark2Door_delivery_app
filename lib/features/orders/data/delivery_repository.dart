import '../domain/delivery_order.dart';

abstract interface class DeliveryRepository {
  /// Every order assigned to the signed-in rider, newest first.
  Stream<List<DeliveryOrder>> watchOrders();

  Future<void> accept(String orderId);

  /// Hands the order back so the admin can assign someone else. [reason]
  /// is the rider's explanation, shown to the admin.
  Future<void> reject(String orderId, String reason);

  Future<void> confirmPickup(String orderId);

  /// [deliveredAt] is when the order was handed over; it is earlier than
  /// now when the rider had no signal and the update is sent later.
  Future<void> markDelivered(
    String orderId, {
    required String photoUrl,
    DateTime? deliveredAt,
  });
}
