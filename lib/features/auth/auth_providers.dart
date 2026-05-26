import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_service.dart';

/// Live Firebase auth state. Emits the Firebase [User] or null after sign-out.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Convenience: current Firebase uid, or null while resolving / signed-out.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// Streams the Firestore profile for the signed-in user.
/// Null while [currentUidProvider] is null OR before the user has saved
/// their onboarding profile — the router treats both as "go to onboarding".
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// Drives anonymous sign-in on app start. The splash screen watches this
/// to show progress / retry if it fails.
class AuthBootstrap extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    final svc = ref.read(authServiceProvider);
    if (svc.currentUser != null) return;
    await svc.signInAnonymously();
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).signInAnonymously();
    });
  }
}

final authBootstrapProvider =
    AsyncNotifierProvider<AuthBootstrap, void>(AuthBootstrap.new);
