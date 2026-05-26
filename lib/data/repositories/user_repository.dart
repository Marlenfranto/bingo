import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_exception.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../models/user_model.dart';
import '../sources/firestore_service.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirestoreService _firestore;

  /// Stream a single user doc. Emits null if the doc doesn't exist yet
  /// (e.g. just after sign-in, before onboarding writes the profile).
  Stream<UserModel?> watchUser(String uid) {
    return _firestore.users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromDoc(doc);
    });
  }

  Future<Result<UserModel?>> getUser(String uid) async {
    try {
      final doc = await _firestore.users.doc(uid).get();
      if (!doc.exists) return const Result.ok(null);
      return Result.ok(UserModel.fromDoc(doc));
    } on FirebaseException catch (e, st) {
      AppLogger.e('getUser failed', error: e, stackTrace: st);
      return Result.err(NetworkException(e.message ?? 'Failed to load profile',
          cause: e, stackTrace: st));
    }
  }

  /// Upsert profile. Sets `createdAt` on first write, always updates `updatedAt`.
  Future<Result<UserModel>> upsertProfile(UserModel user) async {
    try {
      final ref = _firestore.users.doc(user.id);
      final existing = await ref.get();
      final now = DateTime.now();

      final toWrite = user.copyWith(
        createdAt: existing.exists
            ? (user.createdAt ??
                UserModel.fromDoc(existing).createdAt ??
                now)
            : now,
        updatedAt: now,
      );

      await ref.set(toWrite.toJson(), SetOptions(merge: true));
      return Result.ok(toWrite);
    } on FirebaseException catch (e, st) {
      AppLogger.e('upsertProfile failed', error: e, stackTrace: st);
      return Result.err(NetworkException(e.message ?? 'Failed to save profile',
          cause: e, stackTrace: st));
    }
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreServiceProvider));
});
