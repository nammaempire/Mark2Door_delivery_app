import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/app_user.dart';

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Synchronous view of the signed-in rider for widgets.
final currentUserProvider = Provider<AppUser?>((ref) {
  ref.watch(authStateProvider); // rebuild on sign-in / sign-out
  return ref.watch(authRepositoryProvider).currentUser;
});
