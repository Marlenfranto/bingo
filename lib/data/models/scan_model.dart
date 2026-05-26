import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'timestamp_converter.dart';

part 'scan_model.freezed.dart';
part 'scan_model.g.dart';

/// Append-only log of every successful scan. Kept separate from sessions
/// so analytics queries don't bloat the session document.
@freezed
class ScanModel with _$ScanModel {
  const ScanModel._();

  const factory ScanModel({
    @JsonKey(includeToJson: false) required String id,
    required String scannerUid,
    required String scannedUid,
    required String gameId,
    required int slotIndex,
    required String questionId,
    @TimestampConverter() required DateTime scannedAt,
  }) = _ScanModel;

  factory ScanModel.fromJson(Map<String, dynamic> json) =>
      _$ScanModelFromJson(json);

  factory ScanModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ScanModel.fromJson({...?doc.data(), 'id': doc.id});
}
