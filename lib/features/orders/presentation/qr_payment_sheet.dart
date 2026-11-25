import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../domain/delivery_order.dart';

/// For a cash order whose customer would rather pay by UPI: shows the
/// store's QR code for the customer to scan, then takes the rider's photo
/// of the customer's "payment successful" screen as proof.
///
/// Once confirmed, the order counts as paid by QR: the rider is not asked
/// to collect cash for it and it is left out of the cash to hand over.
class QrPaymentSheet extends ConsumerStatefulWidget {
  const QrPaymentSheet({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<QrPaymentSheet> createState() => _QrPaymentSheetState();
}

class _QrPaymentSheetState extends ConsumerState<QrPaymentSheet> {
  String? _proofPath;
  bool _busy = false;
  String? _error;

  /// A separate photo name, so it never replaces the delivery photo.
  String get _proofName => '${widget.order.id}_payment';

  Future<void> _takeProof() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path =
          await ref.read(proofPhotoServiceProvider).capture(_proofName);
      if (mounted) setState(() => _proofPath = path ?? _proofPath);
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Could not open the camera. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final path = _proofPath;
    if (path == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url =
          await ref.read(proofPhotoServiceProvider).upload(_proofName, path);
      await ref
          .read(deliveryRepositoryProvider)
          .recordQrPayment(widget.order.id, proofUrl: url);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('QR payment recorded for the store')),
        );
    } on Exception {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not send the proof. Check the signal and try '
              'again, or collect cash.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = ref.watch(storeInfoProvider).paymentQrUrl;
    final hasProof = _proofPath != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pay by QR scan',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ask the customer to scan this code and pay '
              '${formatPaise(widget.order.totalPaise)}.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            if (qr.isEmpty)
              Container(
                key: const ValueKey('qr-missing'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'The store has not added its payment QR code yet. Collect '
                  'cash for this order, or call the store.',
                  style: TextStyle(height: 1.4, color: AppColors.textDark),
                ),
              )
            else ...[
              Center(
                child: Container(
                  key: const ValueKey('store-qr'),
                  width: 240,
                  height: 240,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Image.network(
                    qr,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'The QR code could not be loaded. Check the signal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'After they pay, take a photo of the "payment successful" '
                'screen on the customer\'s phone. The store checks it against '
                'its bank account.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('qr-proof-button'),
                onPressed: _busy ? null : _takeProof,
                icon: Icon(
                  hasProof
                      ? Icons.check_circle_rounded
                      : Icons.photo_camera_rounded,
                  color: hasProof ? AppColors.success : null,
                ),
                label: Text(
                  hasProof
                      ? 'Photo taken. Tap to retake'
                      : 'Take photo of the payment screen',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const ValueKey('qr-error'),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 10),
              FilledButton(
                key: const ValueKey('qr-confirm-button'),
                onPressed: hasProof && !_busy ? _confirm : null,
                child: Text(_busy ? 'Please wait…' : 'Payment received'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
