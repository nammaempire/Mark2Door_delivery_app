import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../auth/application/auth_providers.dart';
import '../auth/presentation/auth_header.dart';
import '../orders/application/delivery_providers.dart';
import '../orders/presentation/order_widgets.dart';
import 'delete_account.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You won't receive orders until you log in again."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      // Stop new-order alerts to this phone, then end the session. The
      // router redirect sends the rider to login once it ends.
      final phone = ref.read(riderPhoneProvider).valueOrNull ?? '';
      try {
        await ref
            .read(pushServiceProvider)
            .unregister(phone)
            .timeout(const Duration(seconds: 5));
      } on Exception {
        // Offline: logging out still goes ahead.
      }
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeInfoProvider);
    final user = ref.watch(currentUserProvider);
    final onDuty = ref.watch(onDutyProvider);
    // The name the admin entered for this rider under Riders.
    final riderName =
        ref.watch(riderProfileProvider).valueOrNull?.name.trim() ?? '';
    final rating = RatingSummary.of(
      ref.watch(ordersProvider).valueOrNull ?? const [],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(
                    Icons.delivery_dining_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        riderName.isEmpty ? 'Delivery partner' : riderName,
                        key: const ValueKey('profile-name'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        user?.phone ?? '',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 20,
                            color: Color(0xFFE8A200),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              rating.count == 0
                                  ? 'No ratings yet'
                                  : '${rating.label} · ${rating.count} '
                                      'rating${rating.count == 1 ? '' : 's'}',
                              key: const ValueKey('profile-rating'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('profile-duty-switch'),
                  secondary: const Icon(Icons.power_settings_new_rounded),
                  title: const Text(
                    'Available for orders',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(onDuty ? 'You are online' : 'You are offline'),
                  value: onDuty,
                  onChanged: ref.read(onDutyProvider.notifier).set,
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(
                    store.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Pickup point · ${store.address}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              key: const ValueKey('logout-tile'),
              leading:
                  const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text(
                'Log out',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              key: const ValueKey('delete-account-button'),
              onPressed: () => deleteRiderAccount(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
              ),
              child: const Text('Delete account'),
            ),
          ),
          if (!Env.useFirebase) ...[
            const SizedBox(height: 16),
            const HintBanner(
              'Sample-data mode: these orders are examples stored on this '
              'phone and reset when the app restarts.',
            ),
          ],
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '${AppConfig.appName} · v1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
