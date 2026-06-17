import 'package:cloud_firestore/cloud_firestore.dart';

class CharacterAnalysisModel {
  final int intuitiveScore;
  final int passionateScore;
  final int analyticalScore;
  final List<String> strengthsTr;
  final List<String> strengthsEn;
  final List<String> weaknessesTr;
  final List<String> weaknessesEn;
  final Map<String, int> loveLanguages; // touch, words, time, etc.
  final List<String> careersTr;
  final List<String> careersEn;
  final String secretSelfTr;
  final String secretSelfEn;
  final String spiritualJourneyTr;
  final String spiritualJourneyEn;
  final DateTime generatedAt;

  CharacterAnalysisModel({
    required this.intuitiveScore,
    required this.passionateScore,
    required this.analyticalScore,
    required this.strengthsTr,
    required this.strengthsEn,
    required this.weaknessesTr,
    required this.weaknessesEn,
    required this.loveLanguages,
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
      'intuitiveScore': intuitiveScore,
      'passionateScore': passionateScore,
      'analyticalScore': analyticalScore,
      'strengthsTr': strengthsTr,
      'strengthsEn': strengthsEn,
      'weaknessesTr': weaknessesTr,
      'weaknessesEn': weaknessesEn,
      'loveLanguages': loveLanguages,
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
    return CharacterAnalysisModel(
      intuitiveScore: map['intuitiveScore'] ?? 50,
      passionateScore: map['passionateScore'] ?? 50,
      analyticalScore: map['analyticalScore'] ?? 50,
      strengthsTr: List<String>.from(map['strengthsTr'] ?? []),
      strengthsEn: List<String>.from(map['strengthsEn'] ?? []),
      weaknessesTr: List<String>.from(map['weaknessesTr'] ?? []),
      weaknessesEn: List<String>.from(map['weaknessesEn'] ?? []),
      loveLanguages: Map<String, int>.from(map['loveLanguages']?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ?? {}),
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
