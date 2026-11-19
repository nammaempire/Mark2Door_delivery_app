import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../orders/application/delivery_providers.dart';
import '../orders/domain/delivery_order.dart';
import '../orders/presentation/order_widgets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery history')),
      body: AsyncValueView(
        value: orders,
        onRetry: () => ref.invalidate(ordersProvider),
        data: (all) {
          final now = DateTime.now();
          final done = all
              .where((o) =>
                  o.status == DeliveryStatus.delivered && o.deliveredAt != null)
              .toList()
            ..sort((a, b) => b.deliveredAt!.compareTo(a.deliveredAt!));
          if (done.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No deliveries yet',
              message: 'Orders you deliver are listed here.',
            );
          }
          bool isToday(DeliveryOrder o) {
            final d = o.deliveredAt!;
            return d.year == now.year && d.month == now.month && d.day == now.day;
          }

          final today = done.where(isToday).toList();
          final earlier = done.where((o) => !isToday(o)).toList();
          final stats = DayStats.forDay(all, now);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _SummaryTile(
                    label: 'Delivered today',
                    value: '${stats.deliveries}',
                    icon: Icons.check_circle_rounded,
                    colors: const [AppColors.primaryLight, AppColors.primaryDark],
                  ),
                  const SizedBox(width: 12),
                  _SummaryTile(
                    label: 'Cash to hand over',
                    value: formatPaise(stats.cashPaise),
                    icon: Icons.payments_rounded,
                    colors: const [Color(0xFFFFA94D), Color(0xFFF2600C)],
                  ),
                ],
              ),
              if (today.isNotEmpty) ...[
                const _GroupLabel('Today'),
                for (final o in today) _HistoryRow(order: o),
              ],
              if (earlier.isNotEmpty) ...[
                const _GroupLabel('Earlier'),
                for (final o in earlier) _HistoryRow(order: o),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.displayId} · ${order.customerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Delivered ${formatOrderDate(order.deliveredAt!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPaise(order.totalPaise),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.cashOnDelivery ? 'Cash' : 'Paid online',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: order.cashOnDelivery
                        ? AppColors.accentDark
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
