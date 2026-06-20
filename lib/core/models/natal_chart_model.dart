import 'package:cloud_firestore/cloud_firestore.dart';

class NatalChartModel {
  final String sunSign;
  final String moonSign;
  final String risingSign;
  final Map<String, String> planetPositions; // e.g. {'Güneş': 'Koç Burcu, 10. Ev', 'Mars': 'Akrep Burcu, 3. Ev'}
  final Map<String, double> planetAngles; // e.g. {'Güneş': 15.5, 'Ay': 124.2} - 0-360 derece arası boylam
  final Map<String, dynamic>? planetDetails; // Detailed planet coordinates map
  final Map<String, dynamic>? houseDetails; // Detailed houses coordinates map
  final Map<String, dynamic>? aspects; // Calculated planetary aspects
  final Map<String, int>? elements; // Fire, Earth, Air, Water counts
  final Map<String, int>? modalities; // Cardinal, Fixed, Mutable counts
  final Map<String, dynamic> interpretations; // AI generated interpretations per planet
  final String? gender; // 'male' or 'female'
  final DateTime calculatedAt;

  NatalChartModel({
    required this.sunSign,
    required this.moonSign,
    required this.risingSign,
    required this.planetPositions,
    required this.planetAngles,
    this.planetDetails,
    this.houseDetails,
    this.aspects,
    this.elements,
    this.modalities,
    Map<String, dynamic>? interpretations,
    this.gender,
    required this.calculatedAt,
  })  : interpretations = interpretations ?? <String, dynamic>{},
        super();

  Map<String, dynamic> toMap() {
    return {
      'sunSign': sunSign,
      'moonSign': moonSign,
      'risingSign': risingSign,
      'planetPositions': planetPositions,
      'planetAngles': planetAngles,
      if (planetDetails != null) 'planetDetails': planetDetails,
      if (houseDetails != null) 'houseDetails': houseDetails,
      if (aspects != null) 'aspects': aspects,
      if (elements != null) 'elements': elements,
      if (modalities != null) 'modalities': modalities,
      'interpretations': interpretations,
      if (gender != null) 'gender': gender,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }

  factory NatalChartModel.fromMap(Map<String, dynamic> map) {
    // String keys to double map conversion helper
    final Map<String, double> angles = {};
    if (map['planetAngles'] != null) {
      (map['planetAngles'] as Map<dynamic, dynamic>).forEach((key, value) {
        angles[key.toString()] = (value as num).toDouble();
      });
    }

    final Map<String, String> positions = {};
    if (map['planetPositions'] != null) {
      (map['planetPositions'] as Map<dynamic, dynamic>).forEach((key, value) {
        positions[key.toString()] = value.toString();
      });
    }

    return NatalChartModel(
      sunSign: map['sunSign'] ?? '',
      moonSign: map['moonSign'] ?? '',
      risingSign: map['risingSign'] ?? '',
      planetPositions: positions,
      planetAngles: angles,
      planetDetails: map['planetDetails'] != null ? Map<String, dynamic>.from(map['planetDetails']) : null,
      houseDetails: map['houseDetails'] != null ? Map<String, dynamic>.from(map['houseDetails']) : null,
      aspects: map['aspects'] != null ? Map<String, dynamic>.from(map['aspects']) : null,
      elements: map['elements'] != null ? Map<String, int>.from(map['elements']) : null,
      modalities: map['modalities'] != null ? Map<String, int>.from(map['modalities']) : null,
      interpretations: map['interpretations'] != null ? Map<String, dynamic>.from(map['interpretations']) : <String, dynamic>{},
      gender: map['gender'],
      calculatedAt: map['calculatedAt'] != null
          ? (map['calculatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
