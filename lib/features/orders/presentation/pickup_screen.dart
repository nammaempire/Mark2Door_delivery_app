import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/delivery_providers.dart';
import '../domain/delivery_order.dart';
import 'order_widgets.dart';

/// Pickup checklist: every item must be ticked before the order can leave
/// the store.
class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  final _checked = <int>{};
  bool _saving = false;

  Future<void> _confirm(DeliveryOrder order) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(deliveryRepositoryProvider).confirmPickup(order.id);
      if (!mounted) return;
      // Replace this page so "back" from delivery returns to the order list.
      context.pushReplacement(Routes.deliver(order.id));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't confirm pickup. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup')),
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
          final allChecked = _checked.length == o.items.length;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order ${o.displayId}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: PaymentPill(order: o)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SoftCard(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.accentDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pick up from',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  AppConfig.storeName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  AppConfig.storeAddress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Navigate to store',
                            icon: const Icon(Icons.navigation_rounded),
                            onPressed: () => Launchers.navigateTo(
                              context,
                              AppConfig.storeAddress,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pickup list',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Text(
                          '${_checked.length} of ${o.items.length} picked',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (final (i, item) in o.items.indexed) ...[
                            if (i > 0)
                              const Divider(indent: 16, endIndent: 16),
                            CheckboxListTile(
                              key: ValueKey('item-$i'),
                              value: _checked.contains(i),
                              onChanged: (v) => setState(
                                () => (v ?? false)
                                    ? _checked.add(i)
                                    : _checked.remove(i),
                              ),
                              activeColor: AppColors.primary,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: _checked.contains(i)
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(item.unit),
                              secondary: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '× ${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              BottomActionBar(
                child: FilledButton(
                  key: const ValueKey('confirm-pickup-button'),
                  onPressed: allChecked && !_saving ? () => _confirm(o) : null,
                  child: Text(
                    _saving
                        ? 'Please wait…'
                        : allChecked
                            ? 'Confirm pickup'
                            : 'Tick all items to continue',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
