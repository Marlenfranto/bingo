import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'box_slot.dart';
import 'timestamp_converter.dart';

part 'session_model.freezed.dart';
part 'session_model.g.dart';

/// One user's progress in one game. Doc ID is the user's uid so
/// `games/{gameId}/sessions/{uid}` reads/writes are O(1).
@freezed
class SessionModel with _$SessionModel {
  const SessionModel._();

  const factory SessionModel({
    @JsonKey(includeToJson: false) required String uid,
    required String gameId,
    @Default('') String scannerName,
    @Default({}) Map<String, BoxSlot> slots,
    @Default(0) int completedCount,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  factory SessionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SessionModel.fromJson({...?doc.data(), 'uid': doc.id});

  /// True when the player has scanned the given user into any slot.
  /// Used to enforce `ALLOW_REPETITIVE_PERSON_SCAN`.
  bool hasScannedUid(String otherUid) =>
      slots.values.any((s) => s.scannedUid == otherUid);

  /// Look up a filled slot by 1-based slot index.
  BoxSlot? slotAt(int index) => slots[index.toString()];
}
