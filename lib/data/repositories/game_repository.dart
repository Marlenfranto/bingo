import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/env.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../models/game_model.dart';
import '../sources/firestore_service.dart';

class GameRepository {
  GameRepository(this._firestore);

  final FirestoreService _firestore;

  /// Stream the configured active game. We use a fixed ID rather than a
  /// query because (a) reads are O(1), (b) it works offline, and (c) it
  /// avoids the composite index a `where isActive == true` query would need.
  Stream<GameModel?> watchActiveGame() {
    return _firestore.game(Env.activeGameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GameModel.fromDoc(doc);
    });
  }

  Future<Result<GameModel?>> getActiveGame() async {
    try {
      final doc = await _firestore.game(Env.activeGameId).get();
      if (!doc.exists) return const Result.ok(null);
      return Result.ok(GameModel.fromDoc(doc));
    } on FirebaseException catch (e, st) {
      AppLogger.e('getActiveGame failed', error: e, stackTrace: st);
      return Result.err(NetworkException(e.message ?? 'Failed to load game',
          cause: e, stackTrace: st));
    }
  }
}

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.watch(firestoreServiceProvider));
});

/// Live-updating active game. Consumed by AuthGate and dashboard.
final activeGameProvider = StreamProvider<GameModel?>((ref) {
  return ref.watch(gameRepositoryProvider).watchActiveGame();
});
