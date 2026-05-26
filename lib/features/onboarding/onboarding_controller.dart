import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/result.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../auth/auth_providers.dart';

/// Drives the onboarding submit action. Exposes `AsyncValue<void>` so the
/// submit button can render loading + error inline.
class OnboardingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submit({
    required String name,
    required String email,
    String? company,
    String? designation,
    String? linkedinUrl,
  }) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      state = AsyncError(
        const AuthException('Not signed in. Please retry from the splash screen.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading();

    final user = UserModel(
      id: uid,
      name: name.trim(),
      email: email.trim(),
      company: _orNull(company),
      designation: _orNull(designation),
      linkedinUrl: _orNull(linkedinUrl),
    );

    final result = await ref.read(userRepositoryProvider).upsertProfile(user);
    switch (result) {
      case Ok():
        state = const AsyncData(null);
        return true;
      case Err(:final error):
        state = AsyncError(error, StackTrace.current);
        return false;
    }
  }

  String? _orNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, void>(OnboardingController.new);
