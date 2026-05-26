import 'package:freezed_annotation/freezed_annotation.dart';

import 'timestamp_converter.dart';

part 'box_slot.freezed.dart';
part 'box_slot.g.dart';

/// A single filled slot on a player's bingo board. Lives as a value inside
/// `SessionModel.slots` keyed by slot index (stringified for JSON).
///
/// `questionText` is denormalized intentionally — the question may be edited
/// or removed in Firestore later, but the player's board should preserve
/// what they actually saw at the time of the scan.
@freezed
class BoxSlot with _$BoxSlot {
  const BoxSlot._();

  const factory BoxSlot({
    required int slotIndex,
    required String scannedUid,
    required String scannedName,
    String? scannedLinkedinUrl,
    required String questionId,
    required String questionText,
    @TimestampConverter() required DateTime scannedAt,
  }) = _BoxSlot;

  factory BoxSlot.fromJson(Map<String, dynamic> json) =>
      _$BoxSlotFromJson(json);
}
