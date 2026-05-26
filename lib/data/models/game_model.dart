import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'timestamp_converter.dart';

part 'game_model.freezed.dart';
part 'game_model.g.dart';

@freezed
class GameModel with _$GameModel {
  const GameModel._();

  const factory GameModel({
    @JsonKey(includeToJson: false) required String id,
    required String title,
    @Default(true) bool isActive,
    @Default(15) int slotCount,
    @TimestampConverter() DateTime? startsAt,
    @TimestampConverter() DateTime? endsAt,
    @TimestampConverter() DateTime? createdAt,
  }) = _GameModel;

  factory GameModel.fromJson(Map<String, dynamic> json) =>
      _$GameModelFromJson(json);

  factory GameModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      GameModel.fromJson({...?doc.data(), 'id': doc.id});
}
