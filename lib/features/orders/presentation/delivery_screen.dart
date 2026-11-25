import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/delivery_providers.dart';
import '../application/pending_deliveries.dart';
import '../domain/delivery_order.dart';
import 'order_widgets.dart';
import 'qr_payment_sheet.dart';
import 'live_route_map.dart';
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
    // The sheet hands back where the delivery photo was saved on the phone,
    // once the rider has taken it (and, for cash orders, confirmed the
    // money).
    final photoPath = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _ConfirmSheet(order: order),
    );
    if (photoPath == null || !mounted || _saving) return;

    setState(() => _saving = true);
    try {
      // Sent now when there is signal; otherwise kept on the phone and
      // sent by itself later. Either way the rider is finished here.
      final sent = await ref
          .read(pendingDeliveriesProvider.notifier)
          .deliver(order.id, photoPath);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _DeliveredDialog(order: order, sentToStore: sent),
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
                    // A live Google Map on real orders; the drawn preview
                    // in sample-data mode, where there is no real address.
                    if (Env.useFirebase)
                      LiveRouteMap(
                        address: o.fullAddress,
                        pincode: o.pincode,
                        eta: formatTime(o.etaAt),
                        latitude: o.latitude,
                        longitude: o.longitude,
                      )
                    else
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
                                    latitude: o.latitude,
                                    longitude: o.longitude,
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
                    if (o.collectsCash && o.status == DeliveryStatus.pickedUp)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          key: const ValueKey('qr-pay-button'),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (_) => QrPaymentSheet(order: o),
                          ),
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Customer wants to pay by QR scan'),
                        ),
                      ),
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
    final cod = order.collectsCash;
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
                  cod
                      ? 'Collect cash from customer'
                      : order.paidByQr
                          ? 'Paid by QR scan'
                          : 'Already paid online',
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

/// Final check before an order is marked delivered. Every order needs a
/// photo of the handover as proof; cash orders also require the rider to
/// confirm the money was collected. Pops with where the photo was saved on
/// the phone. Taking the photo needs no signal.
class _ConfirmSheet extends ConsumerStatefulWidget {
  const _ConfirmSheet({required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<_ConfirmSheet> {
  bool _cashCollected = false;
  bool _uploading = false;
  String? _photoPath;
  String? _photoError;

  Future<void> _takePhoto() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _photoError = null;
    });
    try {
      final path = await ref
          .read(proofPhotoServiceProvider)
          .capture(widget.order.id);
      if (!mounted) return;
      // null: the rider closed the camera without taking a photo.
      setState(() => _photoPath = path ?? _photoPath);
    } on Exception {
      if (!mounted) return;
      setState(
        () => _photoError = "Couldn't save the photo. Try again.",
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final hasPhoto = _photoPath != null;
    final ready = hasPhoto && (!order.collectsCash || _cashCollected);

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
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const ValueKey('take-photo-button'),
              onPressed: _uploading ? null : _takePhoto,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      hasPhoto
                          ? Icons.check_circle_rounded
                          : Icons.photo_camera_rounded,
                      color: hasPhoto ? AppColors.success : null,
                    ),
              label: Text(
                _uploading
                    ? 'Saving photo…'
                    : hasPhoto
                        ? 'Photo added · tap to retake'
                        : 'Take delivery photo',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _photoError ??
                  'Photograph the order at the door or with the customer. '
                      'The store sees this photo.',
              key: const ValueKey('photo-hint'),
              style: TextStyle(
                fontSize: 12,
                color: _photoError == null
                    ? AppColors.textMuted
                    : AppColors.danger,
              ),
            ),
            if (order.collectsCash) ...[
              const SizedBox(height: 8),
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
              onPressed:
                  ready ? () => Navigator.of(context).pop(_photoPath) : null,
              child: const Text('Confirm delivered'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not yet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveredDialog extends StatelessWidget {
  const _DeliveredDialog({required this.order, required this.sentToStore});

  final DeliveryOrder order;

  /// False when there was no signal and the delivery is kept on the phone.
  final bool sentToStore;

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
            order.collectsCash
                ? 'Order ${order.displayId} is complete. '
                    '${formatPaise(order.totalPaise)} cash added to today\'s '
                    'collection.'
                : 'Order ${order.displayId} is complete.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.4, color: AppColors.textMuted),
          ),
          if (!sentToStore) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('saved-offline-note'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No signal. This delivery and its photo are saved on '
                      'your phone and will be sent to the store by '
                      'themselves when you are back online.',
                      style: TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
