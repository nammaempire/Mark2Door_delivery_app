import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_providers.dart';
import '../application/pending_deliveries.dart';

/// Bottom-navigation scaffold; each tab keeps its own navigation state.
///
/// Only numbers the admin has added under Riders may use the app. Anyone
/// else who signs in sees how to get access instead of an empty order list.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = ref.watch(riderProfileProvider);
    // Keeps this phone registered for new-order notifications.
    ref.watch(pushRegistrationProvider);
    // Starts sending any delivery that was finished without signal.
    ref.watch(pendingDeliveriesProvider);
    // `hasValue` with null data means the lookup finished and found nobody.
    if (rider.hasValue && rider.value == null) return const _NotRegistered();

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _NotRegistered extends ConsumerWidget {
  const _NotRegistered();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(currentUserProvider)?.phone ?? '';
    return Scaffold(
      key: const ValueKey('not-registered'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'This number is not registered',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$phone is not on the delivery partner list. Ask the store '
                'to add this number under Riders, then try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.invalidate(riderProfileProvider),
                child: const Text('Try again'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
