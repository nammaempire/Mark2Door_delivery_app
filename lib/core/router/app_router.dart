import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/orders/presentation/delivery_screen.dart';
import '../../features/orders/presentation/home_shell.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/orders/presentation/pickup_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../providers.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';

  /// The orders tab is the app's home.
  static const home = '/orders';
  static const history = '/history';
  static const profile = '/profile';

  static String pickup(String id) => '/orders/pickup/$id';
  static String deliver(String id) => '/orders/deliver/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref
    ..listen(authStateProvider, (_, __) => refresh.notify())
    ..onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == Routes.splash) return null;
      final loggedIn = ref.read(authRepositoryProvider).currentUser != null;
      final onAuthPage = location == Routes.login || location == Routes.otp;
      if (!loggedIn) return onAuthPage ? null : Routes.login;
      return onAuthPage ? Routes.home : null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        redirect: (context, state) =>
            state.extra is OtpArgs ? null : Routes.login,
        builder: (context, state) => OtpScreen(args: state.extra! as OtpArgs),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: 'pickup/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        PickupScreen(orderId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'deliver/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        DeliveryScreen(orderId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
