import 'package:cloud_firestore/cloud_firestore.dart';

/// Her boyut için sol tarafın yüzdesi (0-100).
/// Örnek: IntrovertExtrovert için 70 → %70 İçe Dönük, %30 Dışa Dönük
class PersonalityDimension {
  final String leftLabelTr;
  final String rightLabelTr;
  final String leftLabelEn;
  final String rightLabelEn;
  final int leftPercent; // 0-100

  PersonalityDimension({
    required this.leftLabelTr,
    required this.rightLabelTr,
    required this.leftLabelEn,
    required this.rightLabelEn,
    required this.leftPercent,
  });

  Map<String, dynamic> toMap() => {
        'leftLabelTr': leftLabelTr,
        'rightLabelTr': rightLabelTr,
        'leftLabelEn': leftLabelEn,
        'rightLabelEn': rightLabelEn,
        'leftPercent': leftPercent,
      };

  factory PersonalityDimension.fromMap(Map<String, dynamic> map) =>
      PersonalityDimension(
        leftLabelTr: map['leftLabelTr'] ?? '',
        rightLabelTr: map['rightLabelTr'] ?? '',
        leftLabelEn: map['leftLabelEn'] ?? '',
        rightLabelEn: map['rightLabelEn'] ?? '',
        leftPercent: (map['leftPercent'] as num?)?.toInt() ?? 50,
      );
}

class CharacterAnalysisModel {
  final List<PersonalityDimension> personalityDimensions;
  final List<String> strengthsTr;
  final List<String> strengthsEn;
  final List<String> weaknessesTr;
  final List<String> weaknessesEn;
  final List<String> careersTr;
  final List<String> careersEn;
  final String secretSelfTr;
  final String secretSelfEn;
  final String spiritualJourneyTr;
  final String spiritualJourneyEn;
  final DateTime generatedAt;

  CharacterAnalysisModel({
    required this.personalityDimensions,
    required this.strengthsTr,
    required this.strengthsEn,
    required this.weaknessesTr,
    required this.weaknessesEn,
    required this.careersTr,
    required this.careersEn,
    required this.secretSelfTr,
    required this.secretSelfEn,
    required this.spiritualJourneyTr,
    required this.spiritualJourneyEn,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'personalityDimensions': personalityDimensions.map((d) => d.toMap()).toList(),
      'strengthsTr': strengthsTr,
      'strengthsEn': strengthsEn,
      'weaknessesTr': weaknessesTr,
      'weaknessesEn': weaknessesEn,
      'careersTr': careersTr,
      'careersEn': careersEn,
      'secretSelfTr': secretSelfTr,
      'secretSelfEn': secretSelfEn,
      'spiritualJourneyTr': spiritualJourneyTr,
      'spiritualJourneyEn': spiritualJourneyEn,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory CharacterAnalysisModel.fromMap(Map<String, dynamic> map) {
    List<PersonalityDimension> dims = [];
    if (map['personalityDimensions'] != null) {
      dims = (map['personalityDimensions'] as List)
          .map((d) => PersonalityDimension.fromMap(Map<String, dynamic>.from(d)))
          .toList();
    }

    return CharacterAnalysisModel(
      personalityDimensions: dims,
      strengthsTr: List<String>.from(map['strengthsTr'] ?? []),
      strengthsEn: List<String>.from(map['strengthsEn'] ?? []),
      weaknessesTr: List<String>.from(map['weaknessesTr'] ?? []),
      weaknessesEn: List<String>.from(map['weaknessesEn'] ?? []),
      careersTr: List<String>.from(map['careersTr'] ?? []),
      careersEn: List<String>.from(map['careersEn'] ?? []),
      secretSelfTr: map['secretSelfTr'] ?? '',
      secretSelfEn: map['secretSelfEn'] ?? '',
      spiritualJourneyTr: map['spiritualJourneyTr'] ?? '',
      spiritualJourneyEn: map['spiritualJourneyEn'] ?? '',
      generatedAt: map['generatedAt'] != null
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
