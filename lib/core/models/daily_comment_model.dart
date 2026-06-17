import 'package:cloud_firestore/cloud_firestore.dart';

class DailyCommentModel {
  final String commentTr;
  final String commentEn;
  final int love;
  final int money;
  final int career;
  final int energy;
  final DateTime generatedAt;

  DailyCommentModel({
    required this.commentTr,
    required this.commentEn,
    required this.love,
    required this.money,
    required this.career,
    required this.energy,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'comment_tr': commentTr,
      'comment_en': commentEn,
      'love': love,
      'money': money,
      'career': career,
      'energy': energy,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory DailyCommentModel.fromMap(Map<String, dynamic> map) {
    return DailyCommentModel(
      commentTr: map['comment_tr'] ?? '',
      commentEn: map['comment_en'] ?? '',
      love: map['love'] ?? 50,
      money: map['money'] ?? 50,
      career: map['career'] ?? 50,
      energy: map['energy'] ?? 50,
      generatedAt: map['generatedAt'] != null
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
