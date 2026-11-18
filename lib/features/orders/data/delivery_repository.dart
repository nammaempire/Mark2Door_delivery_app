import '../domain/delivery_order.dart';

abstract interface class DeliveryRepository {
  /// Every order assigned to the signed-in rider, newest first.
  Stream<List<DeliveryOrder>> watchOrders();

  Future<void> accept(String orderId);

  /// Hands the order back so the admin can assign someone else.
  Future<void> reject(String orderId);

  Future<void> confirmPickup(String orderId);

  Future<void> markDelivered(String orderId);
}
