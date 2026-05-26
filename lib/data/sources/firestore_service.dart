import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single touchpoint for raw Firestore collection refs. Repositories depend
/// on this, not on `FirebaseFirestore.instance`, so tests can substitute a
/// fake. Keeps collection paths discoverable in one place.
class FirestoreService {
  FirestoreService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get games =>
      _firestore.collection('games');

  DocumentReference<Map<String, dynamic>> game(String gameId) =>
      games.doc(gameId);

  CollectionReference<Map<String, dynamic>> questions(String gameId) =>
      game(gameId).collection('questions');

  CollectionReference<Map<String, dynamic>> sessions(String gameId) =>
      game(gameId).collection('sessions');

  CollectionReference<Map<String, dynamic>> scans(String gameId) =>
      game(gameId).collection('scans');

  WriteBatch batch() => _firestore.batch();

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction tx) handler,
  ) =>
      _firestore.runTransaction(handler);
}

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});
