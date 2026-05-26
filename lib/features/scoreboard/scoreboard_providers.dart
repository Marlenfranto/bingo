import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/question_repository.dart';
import '../../data/repositories/session_repository.dart';

/// All sessions for the active game, sorted for the scoreboard.
///
/// Sort order:
///   1. completedCount DESC (most slots filled wins)
///   2. updatedAt ASC      (among ties, earliest finisher wins)
///
/// Empty (0-slot) sessions are filtered out — they clutter the board
/// before anyone has scanned.
final scoreboardProvider = Provider<List<SessionModel>>((ref) {
  final sessions = ref.watch(_allSessionsProvider).valueOrNull ?? const [];
  final ranked = sessions.where((s) => s.completedCount > 0).toList()
    ..sort((a, b) {
      final byCount = b.completedCount.compareTo(a.completedCount);
      if (byCount != 0) return byCount;
      final aT = a.updatedAt?.millisecondsSinceEpoch ?? 1 << 62;
      final bT = b.updatedAt?.millisecondsSinceEpoch ?? 1 << 62;
      return aT.compareTo(bT);
    });
  return ranked;
});

/// First session to reach `completedCount == questionsCount`, by updatedAt.
/// Drives the winner banner. Null if no one has completed yet.
final winnerProvider = Provider<SessionModel?>((ref) {
  final ranked = ref.watch(scoreboardProvider);
  final total = ref.watch(questionsProvider).valueOrNull?.length ?? 0;
  if (total == 0) return null;
  final finishers =
      ranked.where((s) => s.completedCount >= total).toList(growable: false);
  if (finishers.isEmpty) return null;
  // ranked is already sorted earliest-finisher-first among ties.
  return finishers.first;
});

/// Total number of players who have at least one scan. Shown in the header.
final playerCountProvider = Provider<int>((ref) {
  return ref.watch(scoreboardProvider).length;
});

/// Internal — streams the raw session list. Kept private so consumers go
/// through the sorted/filtered [scoreboardProvider].
final _allSessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  return ref
      .watch(sessionRepositoryProvider)
      .watchAllSessions(Env.activeGameId);
});
