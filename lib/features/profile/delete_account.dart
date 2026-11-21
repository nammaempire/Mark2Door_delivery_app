import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../auth/domain/app_user.dart';
import '../auth/presentation/otp_confirm_dialog.dart';
import '../orders/application/delivery_providers.dart';

/// Deletes the rider's account after they confirm and re-enter an OTP.
///
/// Removes the login and the rider's record, so the store no longer sees
/// them under Riders. Orders they delivered keep their name. Not allowed
/// while an order is still assigned to them.
Future<void> deleteRiderAccount(BuildContext context) async {
  // The profile page is gone by the time this finishes, so everything is
  // read from the app-wide container, not from the page.
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final auth = container.read(authRepositoryProvider);
  final user = auth.currentUser;
  if (user == null) return;

  final orders = container.read(ordersProvider).valueOrNull ?? const [];
  if (orders.any((o) => o.isNew || o.isActive)) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish your orders first'),
        content: const Text(
          'You still have orders assigned to you. Deliver or reject them, '
          'then delete your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This cannot be undone.\n\n'
        '• Your login and your delivery partner record are removed.\n'
        '• The store can no longer assign orders to you.\n'
        '• Orders you delivered stay in the store\'s records with your '
        'name.\n\n'
        'Hand over any cash you collected before you delete.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep account'),
        ),
        TextButton(
          key: const ValueKey('confirm-delete-account'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false) || !context.mounted) return;

  if (!auth.signedInRecently) {
    final verified =
        await confirmWithOtp(context, auth: auth, phone: user.phone);
    if (!verified) return;
  }

  try {
    await container
        .read(riderRepositoryProvider)
        .deleteRider(user.phone.replaceFirst(AppConfig.countryCode, ''))
        .timeout(const Duration(seconds: 20));
    final phone = user.phone.replaceFirst(AppConfig.countryCode, '');
    try {
      await container
          .read(pushServiceProvider)
          .unregister(phone)
          .timeout(const Duration(seconds: 5));
    } on Exception {
      // The alert registration is cleaned up on a best-effort basis.
    }
    await auth.deleteAccount();
  } on AuthFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  } on Exception {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not delete your account. Check your internet connection '
          'and try again.',
        ),
      ),
    );
    return;
  }
  messenger.showSnackBar(
    const SnackBar(content: Text('Your account has been deleted.')),
  );
}
