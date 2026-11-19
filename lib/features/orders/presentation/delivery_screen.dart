import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/delivery_providers.dart';
import '../domain/delivery_order.dart';
import 'order_widgets.dart';
import 'route_map.dart';

/// On the way to the customer: route, contact, what to collect, and the
/// final "delivered" confirmation.
class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  bool _saving = false;

  Future<void> _markDelivered(DeliveryOrder order) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _ConfirmSheet(order: order),
    );
    if (!(confirmed ?? false) || !mounted || _saving) return;

    setState(() => _saving = true);
    try {
      await ref.read(deliveryRepositoryProvider).markDelivered(order.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _DeliveredDialog(order: order),
      );
      if (mounted) context.go(Routes.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't update the order. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery')),
      body: AsyncValueView(
        value: order,
        data: (o) {
          if (o == null) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message: 'It may have been reassigned.',
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    RouteMap(
                      distanceKm: o.distanceKm,
                      eta: formatTime(o.etaAt),
                    ),
                    const SizedBox(height: 16),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order ${o.displayId}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                        Flexible(child: PaymentPill(order: o)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            o.customerName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            o.fullAddress,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const ValueKey('call-button'),
                                  onPressed: () => Launchers.call(
                                    context,
                                    o.customerPhone,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  icon: const Icon(Icons.call_rounded),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  key: const ValueKey('navigate-button'),
                                  onPressed: () => Launchers.navigateTo(
                                    context,
                                    o.fullAddress,
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    backgroundColor: const Color(0xFF155FCB),
                                  ),
                                  icon: const Icon(Icons.navigation_rounded),
                                  label: const Text('Navigate'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CashCard(order: o),
                    const SizedBox(height: 14),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Theme(
                        // Removes ExpansionTile's default divider lines.
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          title: Text(
                            '${o.itemCount} '
                            'item${o.itemCount == 1 ? '' : 's'} in this order',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          children: [
                            for (final item in o.items)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.name} (${item.unit})',
                                      ),
                                    ),
                                    Text(
                                      '× ${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (o.status == DeliveryStatus.pickedUp)
                BottomActionBar(
                  child: FilledButton.icon(
                    key: const ValueKey('mark-delivered-button'),
                    onPressed: _saving ? null : () => _markDelivered(o),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(_saving ? 'Please wait…' : 'Mark delivered'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final cod = order.cashOnDelivery;
    final colors = cod
        ? const [Color(0xFFFFA94D), Color(0xFFF2600C)]
        // Paid: success green, not the brand colour.
        : const [Color(0xFF27A86B), Color(0xFF14784A)];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: colors),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              cod ? Icons.payments_rounded : Icons.verified_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cod ? 'Collect cash from customer' : 'Already paid online',
                  style: const TextStyle(
                    color: Color(0xF2FFFFFF),
                    fontSize: 13,
                  ),
                ),
                Text(
                  cod ? formatPaise(order.totalPaise) : 'Nothing to collect',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Final check before an order is marked delivered. Cash orders require
/// the rider to confirm the money was collected.
class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({required this.order});

  final DeliveryOrder order;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  bool _cashCollected = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final ready = !order.cashOnDelivery || _cashCollected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hand over order ${order.displayId}?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Delivering to ${order.customerName}. This cannot be undone.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            if (order.cashOnDelivery) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const ValueKey('cash-collected-checkbox'),
                value: _cashCollected,
                onChanged: (v) => setState(() => _cashCollected = v ?? false),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'I collected ${formatPaise(order.totalPaise)} in cash',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('confirm-delivered-button'),
              onPressed: ready ? () => Navigator.of(context).pop(true) : null,
              child: const Text('Confirm delivered'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveredDialog extends StatelessWidget {
  const _DeliveredDialog({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 52,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Delivered',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            order.cashOnDelivery
                ? 'Order ${order.displayId} is complete. '
                    '${formatPaise(order.totalPaise)} cash added to today\'s '
                    'collection.'
                : 'Order ${order.displayId} is complete.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.4, color: AppColors.textMuted),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          key: const ValueKey('delivered-done-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to orders'),
        ),
      ],
    );
  }
}
