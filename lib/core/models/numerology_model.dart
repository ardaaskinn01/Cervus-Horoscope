import 'package:cloud_firestore/cloud_firestore.dart';

class NumerologyModel {
  final String name;
  final int lifePathNumber;
  final int personalYearNumber;
  final int soulNumber;
  final int destinyNumber;
  final String aiAnalysisTr;
  final String aiAnalysisEn;
  final DateTime generatedAt;

  NumerologyModel({
    required this.name,
    required this.lifePathNumber,
    required this.personalYearNumber,
    required this.soulNumber,
    required this.destinyNumber,
    required this.aiAnalysisTr,
    required this.aiAnalysisEn,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lifePathNumber': lifePathNumber,
      'personalYearNumber': personalYearNumber,
      'soulNumber': soulNumber,
      'destinyNumber': destinyNumber,
      'aiAnalysisTr': aiAnalysisTr,
      'aiAnalysisEn': aiAnalysisEn,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory NumerologyModel.fromMap(Map<String, dynamic> map) {
    return NumerologyModel(
      name: map['name'] ?? '',
      lifePathNumber: map['lifePathNumber'] ?? 0,
      personalYearNumber: map['personalYearNumber'] ?? 0,
      soulNumber: map['soulNumber'] ?? 0,
      destinyNumber: map['destinyNumber'] ?? 0,
      aiAnalysisTr: map['aiAnalysisTr'] ?? '',
      aiAnalysisEn: map['aiAnalysisEn'] ?? '',
      generatedAt: map['generatedAt'] != null
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
