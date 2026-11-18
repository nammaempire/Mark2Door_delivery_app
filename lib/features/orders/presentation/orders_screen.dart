import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/application/auth_providers.dart';
import '../application/delivery_providers.dart';
import '../domain/delivery_order.dart';
import 'order_widgets.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _showActive = false;

  /// Ids with an accept/reject in flight, to block double taps.
  final _busy = <String>{};

  Future<void> _respond(DeliveryOrder order, {required bool accept}) async {
    if (_busy.contains(order.id)) return;
    setState(() => _busy.add(order.id));
    final repo = ref.read(deliveryRepositoryProvider);
    try {
      await (accept ? repo.accept(order.id) : repo.reject(order.id));
      if (!mounted) return;
      if (accept) setState(() => _showActive = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? '${order.displayId} accepted. Head to the store.'
                  : '${order.displayId} rejected',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't update that order. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(order.id));
    }
  }

  Future<void> _confirmReject(DeliveryOrder order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${order.displayId}?'),
        content: const Text(
          'The order goes back to the store to be given to another partner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok ?? false) await _respond(order, accept: false);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final onDuty = ref.watch(onDutyProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AsyncValueView(
          value: orders,
          onRetry: () => ref.invalidate(ordersProvider),
          data: (all) {
            final fresh = all.where((o) => o.isNew).toList();
            final active = all.where((o) => o.isActive).toList();
            final list = _showActive ? active : fresh;

            return Column(
              children: [
                _Header(stats: DayStats.forDay(all, DateTime.now())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _Tabs(
                    showActive: _showActive,
                    newCount: fresh.length,
                    activeCount: active.length,
                    onChanged: (v) => setState(() => _showActive = v),
                  ),
                ),
                Expanded(
                  child: !_showActive && !onDuty
                      ? const EmptyState(
                          icon: Icons.power_settings_new_rounded,
                          title: "You're offline",
                          message: 'Go online from the switch above to '
                              'receive new orders.',
                        )
                      : list.isEmpty
                          ? EmptyState(
                              icon: _showActive
                                  ? Icons.delivery_dining_rounded
                                  : Icons.inbox_rounded,
                              title: _showActive
                                  ? 'No active deliveries'
                                  : 'No new orders',
                              message: _showActive
                                  ? 'Orders you accept show up here.'
                                  : 'New orders appear here as soon as '
                                      'they are assigned to you.',
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: list.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, i) {
                                final o = list[i];
                                return _OrderCard(
                                  order: o,
                                  busy: _busy.contains(o.id),
                                  onAccept: () => _respond(o, accept: true),
                                  onReject: () => _confirmReject(o),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.stats});

  final DayStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDuty = ref.watch(onDutyProvider);
    final phone = ref.watch(currentUserProvider)?.phone ?? '';
    final topInset = MediaQuery.paddingOf(context).top;

    Widget stat(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 14, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14915A), AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hello, partner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      onDuty ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: onDuty ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        key: const ValueKey('duty-switch'),
                        value: onDuty,
                        onChanged: ref.read(onDutyProvider.notifier).set,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat(
                'Delivered today',
                '${stats.deliveries}',
                Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 12),
              stat(
                'Cash collected',
                formatPaise(stats.cashPaise),
                Icons.payments_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.showActive,
    required this.newCount,
    required this.activeCount,
    required this.onChanged,
  });

  final bool showActive;
  final int newCount;
  final int activeCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String key, String label, int count, bool selected, bool value) {
      return Expanded(
        child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: ValueKey(key),
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Text(
                '$label ($count)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          tab('tab-new', 'New', newCount, !showActive, false),
          tab('tab-active', 'Active', activeCount, showActive, true),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final DeliveryOrder order;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pickedUp = order.status == DeliveryStatus.pickedUp;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order ${order.displayId}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: PaymentPill(order: order)),
            ],
          ),
          if (order.isActive) ...[
            const SizedBox(height: 8),
            Pill(
              pickedUp ? 'On the way to customer' : 'Go to store for pickup',
              pickedUp ? const Color(0xFF4B2FCB) : const Color(0xFF155FCB),
              icon: pickedUp
                  ? Icons.delivery_dining_rounded
                  : Icons.storefront_rounded,
            ),
          ],
          const SizedBox(height: 14),
          RouteSummary(order: order),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          OrderFacts(order: order),
          const SizedBox(height: 14),
          if (order.isNew)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('reject-${order.id}'),
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: ValueKey('accept-${order.id}'),
                    onPressed: busy ? null : onAccept,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(busy ? 'Please wait…' : 'Accept order'),
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              key: ValueKey('continue-${order.id}'),
              onPressed: () {
                // A lingering "accepted" message would cover the next
                // page's bottom button.
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.push(
                  pickedUp
                      ? Routes.deliver(order.id)
                      : Routes.pickup(order.id),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: Icon(
                pickedUp ? Icons.navigation_rounded : Icons.checklist_rounded,
              ),
              label: Text(pickedUp ? 'Continue delivery' : 'Start pickup'),
            ),
        ],
      ),
    );
  }
}
