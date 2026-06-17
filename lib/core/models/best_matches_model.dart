import 'package:cloud_firestore/cloud_firestore.dart';

class MatchDetail {
  final String zodiacSign;
  final String reasonTr;
  final String reasonEn;

  MatchDetail({
    required this.zodiacSign,
    required this.reasonTr,
    required this.reasonEn,
  });

  Map<String, dynamic> toMap() {
    return {
      'zodiacSign': zodiacSign,
      'reasonTr': reasonTr,
      'reasonEn': reasonEn,
    };
  }

  factory MatchDetail.fromMap(Map<String, dynamic> map) {
    return MatchDetail(
      zodiacSign: map['zodiacSign'] ?? 'aries',
      reasonTr: map['reasonTr'] ?? '',
      reasonEn: map['reasonEn'] ?? '',
    );
  }
}

class BestMatchesModel {
  final List<MatchDetail> romanticMatches;
  final List<MatchDetail> friendMatches;
  final DateTime generatedAt;

  BestMatchesModel({
    required this.romanticMatches,
    required this.friendMatches,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'romanticMatches': romanticMatches.map((m) => m.toMap()).toList(),
      'friendMatches': friendMatches.map((m) => m.toMap()).toList(),
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory BestMatchesModel.fromMap(Map<String, dynamic> map) {
    return BestMatchesModel(
      romanticMatches: (map['romanticMatches'] as List?)
              ?.map((m) => MatchDetail.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      friendMatches: (map['friendMatches'] as List?)
              ?.map((m) => MatchDetail.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
      generatedAt: map['generatedAt'] != null
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
