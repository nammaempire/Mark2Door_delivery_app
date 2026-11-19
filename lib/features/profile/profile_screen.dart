import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../auth/application/auth_providers.dart';
import '../auth/presentation/auth_header.dart';
import '../orders/application/delivery_providers.dart';
import '../orders/presentation/order_widgets.dart';

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
      // The router redirect sends the rider to login once the session ends.
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeInfoProvider);
    final user = ref.watch(currentUserProvider);
    final onDuty = ref.watch(onDutyProvider);

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
                      const Text(
                        'Delivery partner',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        user?.phone ?? '',
                        style: const TextStyle(color: AppColors.textMuted),
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
