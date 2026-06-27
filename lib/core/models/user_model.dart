import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:horoscope/core/utils/astrology_utils.dart';

class UserModel {
  final String uid;
  final String? name;
  final DateTime? birthDate;
  final String? birthTime; // "SS:DD" biçiminde veya null
  final String? birthPlace;
  final String? gender; // "male", "female" vb.
  final String? zodiacSign; // e.g., "aries"
  final String localeCode;
  final DateTime createdAt;
  final bool isPremium;
  final int profileChangeCount;

  UserModel({
    required this.uid,
    this.name,
    this.birthDate,
    this.birthTime,
    this.birthPlace,
    this.gender,
    this.zodiacSign,
    required this.localeCode,
    required this.createdAt,
    this.isPremium = false,
    this.profileChangeCount = 0,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    DateTime? birthDate,
    String? birthTime,
    String? birthPlace,
    String? gender,
    String? zodiacSign,
    String? localeCode,
    DateTime? createdAt,
    bool? isPremium,
    int? profileChangeCount,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      birthPlace: birthPlace ?? this.birthPlace,
      gender: gender ?? this.gender,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      localeCode: localeCode ?? this.localeCode,
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      profileChangeCount: profileChangeCount ?? this.profileChangeCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'birthTime': birthTime,
      'birthPlace': birthPlace,
      'gender': gender,
      'zodiacSign': zodiacSign,
      'localeCode': localeCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPremium': isPremium,
      'profileChangeCount': profileChangeCount,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'birthDate': birthDate?.toIso8601String(),
      'birthTime': birthTime,
      'birthPlace': birthPlace,
      'gender': gender,
      'zodiacSign': zodiacSign,
      'localeCode': localeCode,
      'createdAt': createdAt.toIso8601String(),
      'isPremium': isPremium,
      'profileChangeCount': profileChangeCount,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedBirthDate;
    if (map['birthDate'] != null) {
      if (map['birthDate'] is Timestamp) {
        final utcDateTime = (map['birthDate'] as Timestamp).toDate().toUtc();
        parsedBirthDate = AstrologyUtils.convertUtcToTurkeyLocal(utcDateTime);
      } else if (map['birthDate'] is String) {
        final parsed = DateTime.tryParse(map['birthDate'] as String);
        if (parsed != null) {
          parsedBirthDate = parsed.isUtc 
              ? AstrologyUtils.convertUtcToTurkeyLocal(parsed) 
              : AstrologyUtils.convertUtcToTurkeyLocal(parsed.toUtc());
        }
      } else if (map['birthDate'] is int) {
        final parsed = DateTime.fromMillisecondsSinceEpoch(map['birthDate'] as int).toUtc();
        parsedBirthDate = AstrologyUtils.convertUtcToTurkeyLocal(parsed);
      }
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now();
      } else if (map['createdAt'] is int) {
        parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int);
      }
    }

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'],
      birthDate: parsedBirthDate,
      birthTime: map['birthTime'],
      birthPlace: map['birthPlace'],
      gender: map['gender'],
      zodiacSign: map['zodiacSign'],
      localeCode: map['localeCode'] ?? 'tr',
      createdAt: parsedCreatedAt,
      isPremium: map['isPremium'] ?? false,
      profileChangeCount: map['profileChangeCount'] ?? 0,
    );
  }
}
