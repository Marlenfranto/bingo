import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/env.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../models/question_model.dart';
import '../sources/firestore_service.dart';

class QuestionRepository {
  QuestionRepository(this._firestore);

  final FirestoreService _firestore;

  /// Stream all active questions for the given game, ordered by `order`.
  /// Inactive questions are filtered server-side so we don't pay download
  /// cost on archived items.
  Stream<List<QuestionModel>> watchQuestions(String gameId) {
    return _firestore
        .questions(gameId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(QuestionModel.fromDoc).toList());
  }

  Future<Result<List<QuestionModel>>> getQuestions(String gameId) async {
    try {
      final snap = await _firestore
          .questions(gameId)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      return Result.ok(snap.docs.map(QuestionModel.fromDoc).toList());
    } on FirebaseException catch (e, st) {
      AppLogger.e('getQuestions failed', error: e, stackTrace: st);
      return Result.err(NetworkException(
          e.message ?? 'Failed to load questions',
          cause: e,
          stackTrace: st));
    }
  }
}

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepository(ref.watch(firestoreServiceProvider));
});

/// Live-updating list of questions for the active game.
final questionsProvider = StreamProvider<List<QuestionModel>>((ref) {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.watchQuestions(Env.activeGameId);
});
