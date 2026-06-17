import 'package:cloud_firestore/cloud_firestore.dart';

class CompatibilityModel {
  final String partnerName;
  final DateTime partnerBirthDate;
  final String? partnerBirthTime;
  final String? partnerBirthPlace;
  final String partnerGender;
  final String partnerZodiacSign;
  final String type; // "love" | "friendship"
  final int overallScore;
  final Map<String, int> scores; // Category scores (e.g. loveScore, sexualityScore)
  final String commentTr;
  final String commentEn;
  final DateTime generatedAt;

  CompatibilityModel({
    required this.partnerName,
    required this.partnerBirthDate,
    this.partnerBirthTime,
    this.partnerBirthPlace,
    required this.partnerGender,
    required this.partnerZodiacSign,
    required this.type,
    required this.overallScore,
    required this.scores,
    required this.commentTr,
    required this.commentEn,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'partnerName': partnerName,
      'partnerBirthDate': Timestamp.fromDate(partnerBirthDate),
      'partnerBirthTime': partnerBirthTime,
      'partnerBirthPlace': partnerBirthPlace,
      'partnerGender': partnerGender,
      'partnerZodiacSign': partnerZodiacSign,
      'type': type,
      'overallScore': overallScore,
      'scores': scores,
      'comment_tr': commentTr,
      'comment_en': commentEn,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory CompatibilityModel.fromMap(Map<String, dynamic> map) {
    return CompatibilityModel(
      partnerName: map['partnerName'] ?? '',
      partnerBirthDate: map['partnerBirthDate'] != null
          ? (map['partnerBirthDate'] as Timestamp).toDate()
          : DateTime.now(),
      partnerBirthTime: map['partnerBirthTime'] as String?,
      partnerBirthPlace: map['partnerBirthPlace'] as String?,
      partnerGender: map['partnerGender'] ?? 'female',
      partnerZodiacSign: map['partnerZodiacSign'] ?? 'aries',
      type: map['type'] ?? 'love',
      overallScore: map['overallScore'] ?? 50,
      scores: Map<String, int>.from(map['scores']?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ?? {}),
      commentTr: map['comment_tr'] ?? '',
      commentEn: map['comment_en'] ?? '',
      generatedAt: map['generatedAt'] != null
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
