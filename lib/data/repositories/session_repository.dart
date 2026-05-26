import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../models/box_slot.dart';
import '../models/session_model.dart';
import '../sources/firestore_service.dart';

class SessionRepository {
  SessionRepository(this._firestore);

  final FirestoreService _firestore;

  /// Stream the current user's session for a given game. Emits null until
  /// the player records their first scan (we lazily create the doc).
  Stream<SessionModel?> watchSession({
    required String gameId,
    required String uid,
  }) {
    return _firestore.sessions(gameId).doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SessionModel.fromDoc(doc);
    });
  }

  /// Stream every session for the game. Drives the live scoreboard.
  /// At event scale (≤200 players) this is cheap: ~200 reads on connect,
  /// then 1 delta per scan. No server-side ordering — sort client-side so
  /// no composite index is needed.
  Stream<List<SessionModel>> watchAllSessions(String gameId) {
    return _firestore
        .sessions(gameId)
        .snapshots()
        .map((snap) => snap.docs.map(SessionModel.fromDoc).toList());
  }

  /// Atomically:
  ///   1. read the player's session
  ///   2. validate the slot isn't filled and the person isn't already scanned
  ///   3. write the new slot + bump completedCount
  ///   4. append a scan-log entry
  ///
  /// Returns [ConflictException] on duplicate slot/person, [NetworkException]
  /// on Firestore failures. The whole operation runs in a single transaction
  /// so the session doc and scans log can't disagree.
  Future<Result<SessionModel>> recordScan({
    required String gameId,
    required String scannerUid,
    required String scannerName,
    required int slotIndex,
    required String scannedUid,
    required String scannedName,
    String? scannedLinkedinUrl,
    required String questionId,
    required String questionText,
    bool allowRepetitivePersonScan = false,
  }) async {
    try {
      // We can NOT throw a custom Dart exception out of `runTransaction` on
      // Flutter Web — cloud_firestore_web pipes the handler result through
      // JS interop and crashes with "Attempting to box non-Dart object" if
      // the thrown type isn't a JS-known class. So conflicts are returned
      // as a (session, conflictMessage) tuple and translated outside.
      final outcome =
          await _firestore.runTransaction<(SessionModel?, String?)>((tx) async {
        final sessionRef = _firestore.sessions(gameId).doc(scannerUid);
        final scanRef = _firestore.scans(gameId).doc();
        final sessionSnap = await tx.get(sessionRef);
        final now = DateTime.now();

        final slot = BoxSlot(
          slotIndex: slotIndex,
          scannedUid: scannedUid,
          scannedName: scannedName,
          scannedLinkedinUrl: scannedLinkedinUrl,
          questionId: questionId,
          questionText: questionText,
          scannedAt: now,
        );

        late SessionModel session;
        if (sessionSnap.exists) {
          session = SessionModel.fromDoc(sessionSnap);

          if (session.slots.containsKey(slotIndex.toString())) {
            return (null, 'That slot is already filled.');
          }
          if (!allowRepetitivePersonScan &&
              session.hasScannedUid(scannedUid)) {
            return (
              null,
              "You've already added this person to your board.",
            );
          }

          session = session.copyWith(
            // Keep scannerName fresh in case the player edited their profile.
            scannerName: scannerName,
            slots: {...session.slots, slotIndex.toString(): slot},
            completedCount: session.completedCount + 1,
            updatedAt: now,
          );
          tx.set(sessionRef, session.toJson(), SetOptions(merge: true));
        } else {
          session = SessionModel(
            uid: scannerUid,
            gameId: gameId,
            scannerName: scannerName,
            slots: {slotIndex.toString(): slot},
            completedCount: 1,
            createdAt: now,
            updatedAt: now,
          );
          tx.set(sessionRef, session.toJson());
        }

        tx.set(scanRef, {
          'scannerUid': scannerUid,
          'scannedUid': scannedUid,
          'gameId': gameId,
          'slotIndex': slotIndex,
          'questionId': questionId,
          'scannedAt': Timestamp.fromDate(now),
        });

        return (session, null);
      });

      final (session, conflict) = outcome;
      if (conflict != null) return Result.err(ConflictException(conflict));
      return Result.ok(session!);
    } on FirebaseException catch (e, st) {
      AppLogger.e('recordScan failed', error: e, stackTrace: st);
      return Result.err(NetworkException(
          e.message ?? 'Failed to record scan',
          cause: e,
          stackTrace: st));
    }
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(firestoreServiceProvider));
});
