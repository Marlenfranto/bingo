import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';
import '../auth/auth_providers.dart';

/// Live session for the current player + active game.
/// Emits null until the player records their first scan (we create the
/// session doc lazily inside the scan transaction).
final mySessionProvider = StreamProvider<SessionModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(sessionRepositoryProvider).watchSession(
        gameId: Env.activeGameId,
        uid: uid,
      );
});

/// Number of slots completed. Derived so widgets that only care about
/// the count don't rebuild when individual slot data changes.
final completedSlotCountProvider = Provider<int>((ref) {
  return ref.watch(mySessionProvider).valueOrNull?.completedCount ?? 0;
});
