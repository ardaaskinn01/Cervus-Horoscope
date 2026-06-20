import 'package:cloud_firestore/cloud_firestore.dart';

class TarotReadingModel {
  final String id;
  final String category;
  final List<TarotCardDraw> draws;
  final String commentTr;
  final String commentEn;
  final DateTime date;

  TarotReadingModel({
    required this.id,
    required this.category,
    required this.draws,
    required this.commentTr,
    required this.commentEn,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'draws': draws.map((x) => x.toMap()).toList(),
      'comment_tr': commentTr,
      'comment_en': commentEn,
      'date': Timestamp.fromDate(date),
    };
  }

  factory TarotReadingModel.fromMap(Map<String, dynamic> map, String docId) {
    return TarotReadingModel(
      id: docId,
      category: map['category'] ?? 'general',
      draws: List<TarotCardDraw>.from(
        (map['draws'] as List<dynamic>?)?.map((x) => TarotCardDraw.fromMap(x as Map<String, dynamic>)) ?? [],
      ),
      commentTr: map['comment_tr'] ?? '',
      commentEn: map['comment_en'] ?? '',
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}

class TarotCardDraw {
  final int cardId;
  final String cardNameTr;
  final String cardNameEn;
  final String symbol;
  final bool isUpright;
  final String position; // "past", "present", "future"

  TarotCardDraw({
    required this.cardId,
    required this.cardNameTr,
    required this.cardNameEn,
    required this.symbol,
    required this.isUpright,
    required this.position,
  });

  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'cardNameTr': cardNameTr,
      'cardNameEn': cardNameEn,
      'symbol': symbol,
      'isUpright': isUpright,
      'position': position,
    };
  }

  factory TarotCardDraw.fromMap(Map<String, dynamic> map) {
    return TarotCardDraw(
      cardId: (map['cardId'] as num?)?.toInt() ?? 0,
      cardNameTr: map['cardNameTr'] ?? '',
      cardNameEn: map['cardNameEn'] ?? '',
      symbol: map['symbol'] ?? '',
      isUpright: map['isUpright'] ?? true,
      position: map['position'] ?? 'present',
    );
  }
}
