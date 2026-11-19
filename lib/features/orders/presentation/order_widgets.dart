import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../domain/delivery_order.dart';

/// Soft elevated card used across the app.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x24800020),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      // A Material (not a coloured Container) so list tiles and ink
      // splashes inside the card paint correctly.
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, this.color, {super.key, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Collect ₹132" for cash orders, "Paid online" otherwise.
class PaymentPill extends StatelessWidget {
  const PaymentPill({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return order.cashOnDelivery
        ? Pill(
            'Collect ${formatPaise(order.totalPaise)}',
            AppColors.accentDark,
            icon: Icons.payments_rounded,
          )
        : const Pill(
            'Paid online',
            AppColors.success,
            icon: Icons.check_circle_rounded,
          );
  }
}

/// Store -> customer, drawn as two stops joined by a line.
class RouteSummary extends StatelessWidget {
  const RouteSummary({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    Widget stop(IconData icon, Color color, String title, String subtitle) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        stop(
          Icons.storefront_rounded,
          AppColors.accentDark,
          AppConfig.storeName,
          AppConfig.storeAddress,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(left: 15, top: 3, bottom: 3),
            width: 2,
            height: 14,
            color: AppColors.border,
          ),
        ),
        stop(
          Icons.location_on_rounded,
          AppColors.primary,
          order.customerName,
          order.fullAddress,
        ),
      ],
    );
  }
}

/// Small facts row: distance, item count, promised time.
class OrderFacts extends StatelessWidget {
  const OrderFacts({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    Widget fact(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        fact(Icons.near_me_rounded, '${order.distanceKm.toStringAsFixed(1)} km'),
        fact(
          Icons.shopping_bag_outlined,
          '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
        ),
        fact(Icons.schedule_rounded, 'By ${formatTime(order.etaAt)}'),
      ],
    );
  }
}

/// Pinned bottom bar with one primary action.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}
