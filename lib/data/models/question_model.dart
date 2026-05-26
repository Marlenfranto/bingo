import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_model.freezed.dart';
part 'question_model.g.dart';

@freezed
class QuestionModel with _$QuestionModel {
  const QuestionModel._();

  const factory QuestionModel({
    @JsonKey(includeToJson: false) required String id,
    required String text,
    required int order,
    @Default(true) bool isActive,
  }) = _QuestionModel;

  factory QuestionModel.fromJson(Map<String, dynamic> json) =>
      _$QuestionModelFromJson(json);

  factory QuestionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      QuestionModel.fromJson({...?doc.data(), 'id': doc.id});
}
