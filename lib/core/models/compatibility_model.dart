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

  // Sinastri (Synastry) alanları — opsiyonel, geriye dönük uyumlu
  final List<Map<String, dynamic>>? synastrAspects; // Hesaplanan sinastri açıları
  final Map<String, dynamic>? userPlanetPositions;    // Kişi 1 gezegen konumları
  final Map<String, dynamic>? partnerPlanetPositions; // Kişi 2 gezegen konumları
  final List<Map<String, dynamic>>? synastriHighlights; // Gemini yorumlanan öne çıkan açılar

  // Gelişmiş Sinastri / Detaylı analiz alanları
  final String? karmicBondsTr;
  final String? karmicBondsEn;
  final String? conflictResolutionTr;
  final String? conflictResolutionEn;
  final String? growthTimelineTr;
  final String? growthTimelineEn;

  final String? relationshipStatus; // "dating" | "new_relationship" | "long_term_relationship" | "newlywed" | "long_term_marriage" | "ex_relationship"

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
    this.synastrAspects,
    this.userPlanetPositions,
    this.partnerPlanetPositions,
    this.synastriHighlights,
    this.karmicBondsTr,
    this.karmicBondsEn,
    this.conflictResolutionTr,
    this.conflictResolutionEn,
    this.growthTimelineTr,
    this.growthTimelineEn,
    this.relationshipStatus,
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
      if (synastrAspects != null) 'synastrAspects': synastrAspects,
      if (userPlanetPositions != null) 'userPlanetPositions': userPlanetPositions,
      if (partnerPlanetPositions != null) 'partnerPlanetPositions': partnerPlanetPositions,
      if (synastriHighlights != null) 'synastriHighlights': synastriHighlights,
      if (karmicBondsTr != null) 'karmicBondsTr': karmicBondsTr,
      if (karmicBondsEn != null) 'karmicBondsEn': karmicBondsEn,
      if (conflictResolutionTr != null) 'conflictResolutionTr': conflictResolutionTr,
      if (conflictResolutionEn != null) 'conflictResolutionEn': conflictResolutionEn,
      if (growthTimelineTr != null) 'growthTimelineTr': growthTimelineTr,
      if (growthTimelineEn != null) 'growthTimelineEn': growthTimelineEn,
      if (relationshipStatus != null) 'relationshipStatus': relationshipStatus,
    };
  }

  factory CompatibilityModel.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>>? parsedSynastrAspects;
    if (map['synastrAspects'] != null) {
      parsedSynastrAspects = List<Map<String, dynamic>>.from(
        (map['synastrAspects'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }

    List<Map<String, dynamic>>? parsedHighlights;
    if (map['synastriHighlights'] != null) {
      parsedHighlights = List<Map<String, dynamic>>.from(
        (map['synastriHighlights'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }

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
      synastrAspects: parsedSynastrAspects,
      userPlanetPositions: map['userPlanetPositions'] != null
          ? Map<String, dynamic>.from(map['userPlanetPositions'])
          : null,
      partnerPlanetPositions: map['partnerPlanetPositions'] != null
          ? Map<String, dynamic>.from(map['partnerPlanetPositions'])
          : null,
      synastriHighlights: parsedHighlights,
      karmicBondsTr: map['karmicBondsTr'] as String?,
      karmicBondsEn: map['karmicBondsEn'] as String?,
      conflictResolutionTr: map['conflictResolutionTr'] as String?,
      conflictResolutionEn: map['conflictResolutionEn'] as String?,
      growthTimelineTr: map['growthTimelineTr'] as String?,
      growthTimelineEn: map['growthTimelineEn'] as String?,
      relationshipStatus: map['relationshipStatus'] as String?,
    );
  }
}
