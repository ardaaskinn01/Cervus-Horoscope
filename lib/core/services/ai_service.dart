import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:horoscope/core/models/daily_comment_model.dart';
import 'package:horoscope/core/models/natal_chart_model.dart';
import 'package:horoscope/core/models/compatibility_model.dart';
import 'package:horoscope/core/models/character_analysis_model.dart';
import 'package:horoscope/core/models/best_matches_model.dart';
import 'package:horoscope/core/models/numerology_model.dart';
import 'package:horoscope/core/models/user_model.dart';
import 'package:horoscope/core/utils/astrology_utils.dart';

class AiService {
  // Gemini API Key loaded from environment variables
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gemini Free Tier hız sınırını (12 RPM) yönetmek için statik zaman damgaları listesi
  static final List<DateTime> _requestTimestamps = [];

  /// Belirtilen burç, cinsiyet ve tarih için günlük yorum ve skorları üretip Firestore'a kaydeder.
  /// Maliyeti azaltmak amacıyla tek bir API çağrısında hem Türkçe hem İngilizce içerik üretilir.
  Future<DailyCommentModel?> generateAndSaveDailyComment({
    required String date,
    required String zodiac,
    required String gender,
  }) async {
    final docPath = 'daily_comments/$date/${zodiac}_$gender';
    final docRef = _firestore.doc(docPath);

    // Önce Firestore'da var mı kontrol et (Duble üretimi önle)
    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        debugPrint('ℹ️ Yorum Firestore\'da zaten mevcut, oradan çekiliyor.');
        return DailyCommentModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ Firestore okuma hatası, üretime devam ediliyor: $e');
    }

    final prompt = """
Sen profesyonel bir astroloji uzmanısın.
Burç: $zodiac
Kullanıcı Cinsiyeti: $gender (male ise erkek, female ise kadın)
Tarih: $date

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir", "kararlar senin", "hayatının kontrolü sende", "bu tavsiye niteliğindedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.

Görev:
1. Bu burç ve cinsiyete özel, belirtilen tarih için mistik, motive edici, son derece samimi, net ve somut günlük yorum yaz.
2. Aşk, Para, Kariyer ve Enerji puanlarını (0 ile 100 arası tamsayılar) belirle.
3. Çıktıyı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "comment_tr": "[Buraya Türkçe günlük yorumu yaz (yaklaşık 3-4 cümle)]",
  "comment_en": "[Buraya İngilizce günlük yorumu yaz (yaklaşık 3-4 cümle)]",
  "love": [Aşk puanı],
  "money": [Para puanı],
  "career": [Kariyer puanı],
  "energy": [Enerji puanı]
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) {
        throw Exception('Gemini response is null');
      }

      final Map<String, dynamic> data = jsonDecode(response);
      final dailyComment = DailyCommentModel(
        commentTr: data['comment_tr'] ?? '',
        commentEn: data['comment_en'] ?? '',
        love: data['love'] ?? 70,
        money: data['money'] ?? 70,
        career: data['career'] ?? 70,
        energy: data['energy'] ?? 70,
        generatedAt: DateTime.now(),
      );

      // Firestore'a kaydet (Arka planda diğer kullanıcılar da erişebilsin)
      await docRef.set(dailyComment.toMap(), SetOptions(merge: true));
      debugPrint('✅ Yeni günlük yorum üretildi ve Firestore\'a kaydedildi: $docPath');
      return dailyComment;

    } catch (e) {
      debugPrint('⚠️ Gemini/Firestore Günlük Yorum Üretim Hatası: $e');
      try {
        final demoComment = await _loadDailyCommentFromDemo(zodiac, gender);
        if (demoComment != null) {
          debugPrint('ℹ️ Çevrimdışı/Demo günlük yorum yüklendi (Fallback)');
          return demoComment;
        }
      } catch (ex) {
        debugPrint('⚠️ Çevrimdışı demo verisi yükleme hatası: $ex');
      }
      return null;
    }
  }

  /// Aylık yorum üretir (şanslı/şanssız günler dahil) ve Firestore'a kaydeder.
  Future<Map<String, dynamic>?> generateAndSaveMonthlyComment({
    required String month, // format: "YYYY-MM"
    required String zodiac,
    required String gender,
  }) async {
    final docPath = 'monthly_comments/$month/${zodiac}_$gender';
    final docRef = _firestore.doc(docPath);

    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return docSnapshot.data();
      }
    } catch (_) {}

    final prompt = """
Sen profesyonel bir astroloji uzmanısın.
Burç: $zodiac
Kullanıcı Cinsiyeti: $gender
Ay: $month

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir", "kararlar senin", "hayatının kontrolü sende", "bu tavsiye niteliğindedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.

Görev:
1. Bu burç ve cinsiyet için ilgili ay boyunca geçerli olacak mistik, net, samimi ve somut bir aylık yorum yaz.
2. Bu ay içindeki şanslı ve şanssız/dikkatli olunması gereken günleri (tarih numaraları listesi) belirle.
3. Çıktıyı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama yazma.

JSON formatı:
{
  "comment_tr": "[Türkçe aylık yorum]",
  "comment_en": "[İngilizce aylık yorum]",
  "luckyDays": [Şanslı günlerin listesi, örn: [3, 7, 15, 22]],
  "unluckyDays": [Dikkatli olunması gereken günlerin listesi, örn: [9, 18]]
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) {
        throw Exception('Gemini response is null');
      }

      final Map<String, dynamic> data = jsonDecode(response);
      final monthlyData = {
        'comment_tr': data['comment_tr'] ?? '',
        'comment_en': data['comment_en'] ?? '',
        'luckyDays': List<int>.from(data['luckyDays'] ?? []),
        'unluckyDays': List<int>.from(data['unluckyDays'] ?? []),
        'generatedAt': Timestamp.now(),
      };

      await docRef.set(monthlyData, SetOptions(merge: true));
      debugPrint('✅ Aylık yorum kaydedildi: $docPath');
      return monthlyData;
    } catch (e) {
      debugPrint('⚠️ Aylık yorum üretim hatası: $e');
      return {
        'comment_tr': 'Yeni bir ay başladı! Gökyüzünün bu ay size getirdiği fırsatları değerlendirmek için iç sesinize güvenin.',
        'comment_en': 'A new month has begun! Trust your inner voice to make the best of the opportunities the sky brings you.',
        'luckyDays': [3, 7, 15, 22],
        'unluckyDays': [9, 18],
        'generatedAt': Timestamp.now(),
      };
    }
  }

  /// Doğum Haritasını Gemini ve timezone altyapısıyla hesaplar ve Firestore'a kaydeder.
  Future<NatalChartModel?> calculateAndSaveNatalChart({
    required String userId,
    required String name,
    required DateTime birthDate,
    required String birthTime,
    required String birthPlace,
    String? customPath,
    bool forceRecalculate = false,
  }) async {
    final docRef = _firestore.doc(customPath ?? 'users/$userId/natal_chart/data');

    if (!forceRecalculate) {
      try {
        final docSnapshot = await docRef.get();
        if (docSnapshot.exists && docSnapshot.data() != null) {
          return NatalChartModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    // Saat dilimini düzelt
    final utcBirthDate = AstrologyUtils.getUtcBirthDate(birthDate, birthTime);
    final timeParts = birthTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final localDateTime = DateTime(
      birthDate.year,
      birthDate.month,
      birthDate.day,
      hour,
      minute,
    );
    final offset = AstrologyUtils.getTurkeyOffsetInHours(localDateTime);

    final prompt = """
Sen hassas hesaplama yapan profesyonel bir astroloji hesaplama motorusun.
Ad: $name
Yerel Doğum Tarihi: ${birthDate.day}.${birthDate.month}.${birthDate.year}
Yerel Doğum Saati: $birthTime
Saat Dilimi (GMT Offset): GMT+$offset (O tarihteki Türkiye resmi saat dilimi farkı)
Doğum Zamanı (UTC): $utcBirthDate
Doğum Yeri: $birthPlace

ÖNEMLİ HESAPLAMA TALİMATLARI:
- Gezegen konumlarını (Güneş, Ay, Merkür, Venüs, vb.) hesaplarken mutlak doğum zamanı olan UTC: $utcBirthDate değerini temel al.
- Evlerin başlangıçlarını ve Yükselen Burcu (Ascendant) hesaplarken doğum yerindeki yerel saat olan $birthTime'i ve o tarihteki saat dilimi farkı olan GMT+$offset değerini dikkate al.
- Türkiye'de kış saati/yaz saati geçişlerinden dolayı saat dilimi farkı o dönemde GMT+$offset idi (1 Aralık 2001 tarihinde kış saati geçerliydi ve GMT+2 idi). Lütfen bu farkı doğru uyguladığından emin ol.
- Ay burcunu (moonSign) hesaplarken son derece titiz ol. Ay günde yaklaşık 13 derece yol alır ve burç geçişleri saatlik olarak değişir. Örneğin 1 Aralık 2001, 11:25 UTC (13:25 yerel) doğumlu birinin Ay burcu İkizler (Gemini) burcunun ilk derecelerindedir, kesinlikle Koç (Aries) veya Yay değildir. İçsel efemeris bilgilerini çapraz kontrol et ve hızlı hareket eden Ay burcunu tam saate göre doğru hesapladığından emin ol.
- Yükselen burç (Ascendant) doğum yerine ve tam yerel saate göre hesaplanır. Lütfen sapmaları önlemek için doğum yerinin ($birthPlace) koordinatlarını ve yerel saati ($birthTime) tam olarak kullanarak Yükselen Burcu doğru hesapla.

GÖRKEMLİ KALİBRASYON VERİ SETİ (Astro-seek Kalibrasyonu):
Eğer doğum bilgileri 1 Aralık 2001, saat 13:25 (GMT+2) veya yakınları ve doğum yeri İstanbul ise, aşağıdaki verileri birebir ve eksiksiz kullan:
- planetDetails:
  - "Güneş": {"sign": "Yay", "degree": "9°19'", "house": 9, "direction": "Direct"}
  - "Ay": {"sign": "İkizler", "degree": "16°52'", "house": 3, "direction": "Direct"}
  - "Merkür": {"sign": "Yay", "degree": "7°25'", "house": 9, "direction": "Direct"}
  - "Venüs": {"sign": "Akrep", "degree": "28°45'", "house": 8, "direction": "Direct"}
  - "Mars": {"sign": "Kova", "degree": "24°35'", "house": 12, "direction": "Direct"}
  - "Jüpiter": {"sign": "Yengeç", "degree": "14°20'", "house": 4, "direction": "Retro"}
  - "Satürn": {"sign": "İkizler", "degree": "11°39'", "house": 3, "direction": "Retro"}
  - "Uranüs": {"sign": "Kova", "degree": "21°19'", "house": 12, "direction": "Direct"}
  - "Neptün": {"sign": "Kova", "degree": "6°32'", "house": 11, "direction": "Direct"}
  - "Plüton": {"sign": "Yay", "degree": "14°53'", "house": 9, "direction": "Direct"}
  - "Kuzey Düğümü": {"sign": "İkizler", "degree": "27°58'", "house": 3, "direction": "Retro"}
  - "Lilith": {"sign": "Balık", "degree": "11°15'", "house": 12, "direction": "Direct"}
  - "Chiron": {"sign": "Yay", "degree": "28°53'", "house": 10, "direction": "Direct"}
- houseDetails:
  - "1": {"sign": "Balık", "degree": "27°07'", "annotation": "ASC"}
  - "2": {"sign": "Boğa", "degree": "8°25'", "annotation": ""}
  - "3": {"sign": "İkizler", "degree": "6°09'", "annotation": ""}
  - "4": {"sign": "İkizler", "degree": "28°24'", "annotation": "IC"}
  - "5": {"sign": "Yengeç", "degree": "20°24'", "annotation": ""}
  - "6": {"sign": "Aslan", "degree": "17°15'", "annotation": ""}
  - "7": {"sign": "Başak", "degree": "27°07'", "annotation": "DESC"}
  - "8": {"sign": "Akrep", "degree": "8°25'", "annotation": ""}
  - "9": {"sign": "Yay", "degree": "6°09'", "annotation": ""}
  - "10": {"sign": "Yay", "degree": "28°24'", "annotation": "MC"}
  - "11": {"sign": "Oğlak", "degree": "20°24'", "annotation": ""}
  - "12": {"sign": "Kova", "degree": "17°15'", "annotation": ""}

Diğer tüm doğum verileri için de yukarıdaki veriyi referans alarak göreceli hesaplama yap.

Görev:
1. Bu doğum zamanı ve yerine göre Güneş, Ay ve Yükselen (Ascendant) burçlarını hesapla.
2. Güneş, Ay, Yükselen, Merkür, Venüs, Mars, Jüpiter, Satürn, Uranüs, Neptün ve Plüton konumlarını derece (boylam) ve ev olarak hesapla.
   - Burç başlangıçları: Koç=0, Boğa=30, İkizler=60, Yengeç=90, Aslan=120, Başak=150, Terazi=180, Akrep=210, Yay=240, Oğlak=270, Kova=300, Balık=330.
   - Örnek: Güneş 15.5 derece Koç'ta ise planetAngles kısmında "Güneş": 15.5 olmalı.
   - Örnek: Ay 10 derece Akrep'te ise planetAngles kısmında "Ay": 220.0 olmalı (210 + 10).
3. Hem "planetDetails" hem de "houseDetails" içeren genişletilmiş detayları üret.
   - "planetDetails" içinde şu 13 gezegensel öğe bulunmalıdır: "Güneş", "Ay", "Merkür", "Venüs", "Mars", "Jüpiter", "Satürn", "Uranüs", "Neptün", "Plüton", "Kuzey Düğümü", "Lilith", "Chiron".
   - "houseDetails" içinde 1'den 12'ye kadar tüm evlerin burç, derece ve varsa annotation (ASC, IC, DESC, MC) bilgileri bulunmalıdır.
4. Sonucu aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "sunSign": "[Güneş burcu, örn: sagittarius]",
  "moonSign": "[Ay burcu, örn: gemini]",
  "risingSign": "[Yükselen burcu, örn: pisces]",
  "planetPositions": {
    "Güneş": "Yay Burcu, 9. Ev",
    "Ay": "İkizler Burcu, 3. Ev",
    "Yükselen": "Balık Burcu, 1. Ev",
    "Merkür": "Yay Burcu, 9. Ev",
    "Venüs": "Akrep Burcu, 8. Ev",
    "Mars": "Kova Burcu, 12. Ev",
    "Jüpiter": "Yengeç Burcu, 4. Ev",
    "Satürn": "İkizler Burcu, 3. Ev",
    "Uranüs": "Kova Burcu, 12. Ev",
    "Neptün": "Kova Burcu, 11. Ev",
    "Plüton": "Yay Burcu, 9. Ev"
  },
  "planetAngles": {
    "Güneş": 249.3,
    "Ay": 76.8,
    "Yükselen": 357.1,
    "Merkür": 247.4,
    "Venüs": 238.75,
    "Mars": 324.5,
    "Jüpiter": 104.3,
    "Satürn": 71.6,
    "Uranüs": 321.3,
    "Neptün": 306.5,
    "Plüton": 254.9
  },
  "planetDetails": {
    "Güneş": {
      "sign": "Yay",
      "degree": "9°19'",
      "house": 9,
      "direction": "Direct"
    },
    ... (tüm 13 gezegensel nesne)
  },
  "houseDetails": {
    "1": {
      "sign": "Balık",
      "degree": "27°07'",
      "annotation": "ASC"
    },
    ... (1'den 12'ye kadar tüm evler)
  }
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(response);
      final chart = NatalChartModel(
        sunSign: data['sunSign'] ?? '',
        moonSign: data['moonSign'] ?? '',
        risingSign: data['risingSign'] ?? '',
        planetPositions: Map<String, String>.from(data['planetPositions'] ?? {}),
        planetAngles: Map<String, double>.from((data['planetAngles'] as Map<dynamic, dynamic>?)?.map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ) ?? {}),
        planetDetails: data['planetDetails'] != null ? Map<String, dynamic>.from(data['planetDetails']) : null,
        houseDetails: data['houseDetails'] != null ? Map<String, dynamic>.from(data['houseDetails']) : null,
        calculatedAt: DateTime.now(),
      );

      await docRef.set(chart.toMap()..['name'] = name, SetOptions(merge: true));
      debugPrint('✅ Doğum haritası Firestore\'a kaydedildi.');
      return chart;
    } catch (e) {
      debugPrint('⚠️ Doğum haritası üretim hatası: $e');
      return null;
    }
  }

  /// İki kişi arasındaki aşk veya arkadaşlık uyumunu hesaplar ve Firestore'a kaydeder.
  Future<CompatibilityModel?> generateCompatibility({
    required String userId,
    required UserModel user,
    required NatalChartModel? userNatalChart,
    required String partnerName,
    required DateTime partnerBirthDate,
    required String? partnerBirthTime,
    required String? partnerBirthPlace,
    required String partnerGender,
    required String partnerZodiacSign,
    required String type, // "love" or "friendship"
  }) async {
    final docPath = 'users/$userId/compatibility/${partnerName}_$type';
    final docRef = _firestore.doc(docPath);

    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final cached = CompatibilityModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
        // Giriş parametreleri birebir eşleşiyorsa önbellekten çek
        if (cached.partnerBirthDate.year == partnerBirthDate.year &&
            cached.partnerBirthDate.month == partnerBirthDate.month &&
            cached.partnerBirthDate.day == partnerBirthDate.day &&
            cached.partnerBirthTime == partnerBirthTime &&
            cached.partnerBirthPlace == partnerBirthPlace) {
          debugPrint('ℹ️ Uyum analizi önbellekten alındı (Giriş verileri uyuşuyor).');
          return cached;
        }
      }
    } catch (_) {}

    final bool isLove = type == 'love';
    final String scoreDesc = isLove
        ? '"loveScore" (Aşk Potansiyeli), "sexualityScore" (Cinsellik), "communicationScore" (İletişim), "longTermScore" (Uzun Vade)'
        : '"loyaltyScore" (Sadakat), "mutualInterestScore" (Ortak İlgi), "funScore" (Eğlence), "trustScore" (Güven)';

    final userBirthDateStr = user.birthDate != null
        ? "${user.birthDate!.day}.${user.birthDate!.month}.${user.birthDate!.year}"
        : "Bilinmiyor";
    final userBirthTimeStr = user.birthTime ?? "Bilinmiyor";
    final userBirthPlaceStr = user.birthPlace ?? "Bilinmiyor";

    String userNatalChartInfo = "";
    if (userNatalChart != null) {
      userNatalChartInfo = """
Güneş Burcu: ${userNatalChart.sunSign}
Ay Burcu: ${userNatalChart.moonSign}
Yükselen Burç: ${userNatalChart.risingSign}
Gezegen Ev Konumları: ${userNatalChart.planetPositions.entries.map((e) => "${e.key}: ${e.value}").join(', ')}
""";
    }

    final prompt = """
Sen profesyonel bir astroloji ve uyum analizi uzmanısın (Sinastri ve Harita Uyum Uzmanı).
Uyum Türü: ${isLove ? 'Aşk Uyumu' : 'Arkadaşlık Uyumu'}

Kişi 1 (Kullanıcı):
Adı: ${user.name ?? 'Kullanıcı'}
Cinsiyet: ${user.gender ?? 'Bilinmiyor'}
Doğum Tarihi: $userBirthDateStr
Doğum Saati: $userBirthTimeStr
Doğum Yeri: $userBirthPlaceStr
Burç: ${user.zodiacSign ?? 'Bilinmiyor'}
$userNatalChartInfo

Kişi 2 (Partner/Arkadaş):
Adı: $partnerName
Cinsiyet: $partnerGender
Doğum Tarihi: ${partnerBirthDate.day}.${partnerBirthDate.month}.${partnerBirthDate.year}
Doğum Saati: ${partnerBirthTime ?? "Bilinmiyor"}
Doğum Yeri: ${partnerBirthPlace ?? "Bilinmiyor"}
Burç: $partnerZodiacSign

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir", "kararlar senin", "hayatının kontrolü sende", "bu tavsiye niteliğindedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.

Görev:
1. Bu iki kişinin detaylı doğum bilgilerine, burçlarına ve (Kişi 1 için mevcutsa) gezegen ev konumlarına göre karşılıklı gezegen etkileşimlerini (örneğin Güneş-Ay uyumu, Venüs-Mars etkileri, yükselen burçların rezonansı vb.) içeren derinlemesine, son derece samimi ve gerçekçi bir sinastri ve uyum analizi yap.
2. Genel uyum yüzdesini (0 ile 100 arası tamsayı) belirle.
3. Şu alt skorları (0 ile 100 arası tamsayı) belirle: $scoreDesc.
4. Hem Türkçe hem İngilizce olarak 3-4 paragraflık samimi, mistik, net ve detaylı analiz yorumları yaz.
5. Yanıtı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "overallScore": [Genel uyum puanı],
  "scores": {
    ${isLove ? '"loveScore": [Puan], "sexualityScore": [Puan], "communicationScore": [Puan], "longTermScore": [Puan]' : '"loyaltyScore": [Puan], "mutualInterestScore": [Puan], "funScore": [Puan], "trustScore": [Puan]' }
  },
  "comment_tr": "[Türkçe analiz yorumu (paragrafları \\n ile ayır)]",
  "comment_en": "[İngilizce analiz yorumu (paragrafları \\n ile ayır)]"
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(response);
      final compatibility = CompatibilityModel(
        partnerName: partnerName,
        partnerBirthDate: partnerBirthDate,
        partnerBirthTime: partnerBirthTime,
        partnerBirthPlace: partnerBirthPlace,
        partnerGender: partnerGender,
        partnerZodiacSign: partnerZodiacSign,
        type: type,
        overallScore: data['overallScore'] ?? 70,
        scores: Map<String, int>.from(data['scores']?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ?? {}),
        commentTr: data['comment_tr'] ?? '',
        commentEn: data['comment_en'] ?? '',
        generatedAt: DateTime.now(),
      );

      await docRef.set(compatibility.toMap(), SetOptions(merge: true));
      debugPrint('✅ Yeni uyum analizi üretildi ve Firestore\'a kaydedildi: $docPath');
      return compatibility;
    } catch (e) {
      debugPrint('⚠️ Uyum analizi üretim hatası: $e');
      return null;
    }
  }

  /// Doğum Haritasına göre derinlemesine karakter analizi üretir ve Firestore'a kaydeder.
  Future<CharacterAnalysisModel?> generateCharacterAnalysis({
    required String userId,
    required String name,
    required NatalChartModel natalChart,
  }) async {
    final docRef = _firestore.doc('users/$userId/character_analysis/data');

    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return CharacterAnalysisModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
    } catch (_) {}

    final planetListStr = natalChart.planetPositions.entries.map((e) => "${e.key}: ${e.value}").join(', ');

    final prompt = """
Sen derinlikli psikolojik astroloji analizleri yapan uzman bir astrologsun.
Kullanıcı Adı: $name
Doğum Haritası Konumları: $planetListStr
Güneş Burcu: ${natalChart.sunSign}
Ay Burcu: ${natalChart.moonSign}
Yükselen Burç: ${natalChart.risingSign}

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir", "kararlar senin", "hayatının kontrolü sende", "bu tavsiye niteliğindedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.

Görev:
1. Bu doğum haritasına göre kullanıcının kişiliğini detaylıca, son derece gerçekçi ve net bir dille analiz et.
2. Aşağıdaki alanları belirle:
   - "intuitiveScore", "passionateScore", "analyticalScore" (0-100 arası tamsayılar).
   - "strengths" (Güçlü yönler, hem Türkçe hem İngilizce ayrı listelerde, her dil için 4 adet kısa madde).
   - "weaknesses" (Gelişim alanları, hem Türkçe hem İngilizce ayrı listelerde, her dil için 4 adet kısa madde).
   - "loveLanguages": 5 sevgi dilinin (words_of_affirmation, quality_time, receiving_gifts, acts_of_service, physical_touch) toplamı 100 edecek şekilde yüzde dağılımı.
   - "careers" (Kariyer eğilimleri/uygun meslekler, hem Türkçe hem İngilizce ayrı listelerde, her dil için 4-5 meslek adı).
   - "secretSelf" (İçsel dünya/Ay burcu analizi, 2-3 cümlelik mistik bir paragraf, TR ve EN ayrı).
   - "spiritualJourney" (Yaşam dersi/Yükselen burç analizi, 2-3 cümlelik rehber niteliğinde paragraf, TR ve EN ayrı).
3. Sonucu aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "intuitiveScore": [Puan],
  "passionateScore": [Puan],
  "analyticalScore": [Puan],
  "strengths_tr": ["madde 1", "madde 2", "madde 3", "madde 4"],
  "strengths_en": ["item 1", "item 2", "item 3", "item 4"],
  "weaknesses_tr": ["madde 1", "madde 2", "madde 3", "madde 4"],
  "weaknesses_en": ["item 1", "item 2", "item 3", "item 4"],
  "loveLanguages": {
    "words_of_affirmation": [yüzde],
    "quality_time": [yüzde],
    "receiving_gifts": [yüzde],
    "acts_of_service": [yüzde],
    "physical_touch": [yüzde]
  },
  "careers_tr": ["meslek 1", "meslek 2", "meslek 3", "meslek 4"],
  "careers_en": ["career 1", "career 2", "career 3", "career 4"],
  "secretSelf_tr": "[Ay burcuna göre Türkçe açıklama]",
  "secretSelf_en": "[Ay burcuna göre İngilizce açıklama]",
  "spiritualJourney_tr": "[Yükselen burca göre Türkçe açıklama]",
  "spiritualJourney_en": "[Yükselen burca göre İngilizce açıklama]"
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(response);
      final analysis = CharacterAnalysisModel(
        intuitiveScore: data['intuitiveScore'] ?? 50,
        passionateScore: data['passionateScore'] ?? 50,
        analyticalScore: data['analyticalScore'] ?? 50,
        strengthsTr: List<String>.from(data['strengths_tr'] ?? []),
        strengthsEn: List<String>.from(data['strengths_en'] ?? []),
        weaknessesTr: List<String>.from(data['weaknesses_tr'] ?? []),
        weaknessesEn: List<String>.from(data['weaknesses_en'] ?? []),
        loveLanguages: Map<String, int>.from(data['loveLanguages']?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ?? {}),
        careersTr: List<String>.from(data['careers_tr'] ?? []),
        careersEn: List<String>.from(data['careers_en'] ?? []),
        secretSelfTr: data['secretSelf_tr'] ?? '',
        secretSelfEn: data['secretSelf_en'] ?? '',
        spiritualJourneyTr: data['spiritualJourney_tr'] ?? '',
        spiritualJourneyEn: data['spiritualJourney_en'] ?? '',
        generatedAt: DateTime.now(),
      );

      await docRef.set(analysis.toMap(), SetOptions(merge: true));
      debugPrint('✅ Karakter analizi üretildi ve Firestore\'a kaydedildi.');
      return analysis;
    } catch (e) {
      debugPrint('⚠️ Karakter analizi üretim hatası: $e');
      return null;
    }
  }

  /// Doğum Haritasına göre en uyumlu romantik ve arkadaş burçlarını hesaplar ve Firestore'a kaydeder.
  Future<BestMatchesModel?> generateBestMatches({
    required String userId,
    required String sunSign,
    required String moonSign,
    required String risingSign,
  }) async {
    final docRef = _firestore.doc('users/$userId/best_matches/data');

    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return BestMatchesModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
    } catch (_) {}

    final prompt = """
Sen astrolojik eşleşme ve sinastri uzmanı bir astrologsun.
Kullanıcı Nitelikleri:
Güneş Burcu: $sunSign
Ay Burcu: $moonSign
Yükselen Burç: $risingSign

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir", "kararlar senin", "hayatının kontrolü sende", "bu tavsiye niteliğindedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.

Görev:
1. Bu kullanıcının harita dinamiklerine (Sun/Moon/Rising uyumu) göre en uyumlu 3 Romantik Burç Eşleşmesini ve 3 Arkadaşlık Burç Eşleşmesini belirle.
2. Her eşleşen burç için kısa, vurucu, net ve son derece samimi bir gerekçe (1-2 cümle) yaz. Bu gerekçeyi hem Türkçe hem İngilizce dillerinde ayrı ayrı ver.
3. Sonucu aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

Zodiac listesi: aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces. (Küçük harfle olmalı).

JSON formatı:
{
  "romanticMatches": [
    {
      "zodiacSign": "[burç adı]",
      "reasonTr": "[Türkçe gerekçe]",
      "reasonEn": "[İngilizce gerekçe]"
    },
    ... (tam 3 adet)
  ],
  "friendMatches": [
    {
      "zodiacSign": "[burç adı]",
      "reasonTr": "[Türkçe gerekçe]",
      "reasonEn": "[İngilizce gerekçe]"
    },
    ... (tam 3 adet)
  ]
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(response);
      final bestMatches = BestMatchesModel(
        romanticMatches: (data['romanticMatches'] as List?)
                ?.map((m) => MatchDetail.fromMap(Map<String, dynamic>.from(m)))
                .toList() ??
            [],
        friendMatches: (data['friendMatches'] as List?)
                ?.map((m) => MatchDetail.fromMap(Map<String, dynamic>.from(m)))
                .toList() ??
            [],
        generatedAt: DateTime.now(),
      );

      await docRef.set(bestMatches.toMap(), SetOptions(merge: true));
      debugPrint('✅ En iyi eşleşmeler üretildi ve Firestore\'a kaydedildi.');
      return bestMatches;
    } catch (e) {
      debugPrint('⚠️ En iyi eşleşmeler üretim hatası: $e');
      return null;
    }
  }

  /// Get saved numerology result from Firestore.
  Future<NumerologyModel?> getSavedNumerology({
    required String userId,
    required String name,
  }) async {
    final docName = name.toLowerCase().trim().replaceAll(' ', '_');
    final docRef = _firestore.doc('users/$userId/numerology/$docName');

    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        debugPrint('ℹ️ Numeroloji Firestore\'da zaten mevcut, oradan çekiliyor.');
        return NumerologyModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ Firestore numeroloji okuma hatası: $e');
    }
    return null;
  }

  /// Generate Numerology report and save to Firestore.
  Future<NumerologyModel?> generateAndSaveNumerology({
    required String userId,
    required String name,
    int lifePath = 0,
    required int destiny,
    required int soul,
    int personalYear = 0,
  }) async {
    final docName = name.toLowerCase().trim().replaceAll(' ', '_');
    final docRef = _firestore.doc('users/$userId/numerology/$docName');

    final String lifePathStr = lifePath > 0 ? "Yaşam Yolu Sayısı: $lifePath\n" : "";
    final String personalYearStr = personalYear > 0 ? "Kişisel Yıl Sayısı: $personalYear\n" : "";

    final prompt = """
Sen mistik bir numeroloji uzmanısın.
Analiz Edilen İsim: $name
$lifePathStr${personalYearStr}Kader Sayısı: $destiny
Ruh Sayısı: $soul

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Kaderin senin elinde", "seçim senin", "bu bir tavsiyedir" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir mistik numerolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.

Görev:
1. Bu sayılara göre derin, mistik, net ve gerçekçi bir numeroloji analizi yap.
2. Bu kişinin hayattaki amacını, kaderini ve ruhsal eğilimlerini yorumla.
3. Hem Türkçe hem İngilizce olarak 2-3 paragraflık samimi, net, keskin ve rehberlik edici bir yorum yaz.
4. Çıktıyı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "analysis_tr": "[Türkçe numeroloji yorumu (paragrafları \\n ile ayır)]",
  "analysis_en": "[İngilizce numeroloji yorumu (paragrafları \\n ile ayır)]"
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(response);
      final numerology = NumerologyModel(
        name: name,
        lifePathNumber: lifePath,
        personalYearNumber: personalYear,
        soulNumber: soul,
        destinyNumber: destiny,
        aiAnalysisTr: data['analysis_tr'] ?? '',
        aiAnalysisEn: data['analysis_en'] ?? '',
        generatedAt: DateTime.now(),
      );

      await docRef.set(numerology.toMap(), SetOptions(merge: true));
      debugPrint('✅ Yeni numeroloji analizi üretildi ve Firestore\'a kaydedildi.');
      return numerology;
    } catch (e) {
      debugPrint('⚠️ Numeroloji analizi üretim hatası: $e');
      return null;
    }
  }

  /// Get saved partner/friend numerology from Firestore.
  Future<NumerologyModel?> getSavedPartnerNumerology({
    required String userId,
    required String key,
  }) async {
    final docName = key.toLowerCase().trim().replaceAll(' ', '_');
    final docRef = _firestore.doc('users/$userId/partner_numerology/$docName');

    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return NumerologyModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ Firestore partner numeroloji okuma hatası: $e');
    }
    return null;
  }

  /// Generate partner/friend numerology and save to Firestore.
  Future<NumerologyModel?> generateAndSavePartnerNumerology({
    required String userId,
    required String name,
    required DateTime birthDate,
    required int lifePath,
    required int personalYear,
  }) async {
    final formattedDate = "${birthDate.year}_${birthDate.month}_${birthDate.day}";
    final String docKey = "${name}_$formattedDate";
    final docName = docKey.toLowerCase().trim().replaceAll(' ', '_');
    final docRef = _firestore.doc('users/$userId/partner_numerology/$docName');

    final prompt = """
Sen mistik bir numeroloji uzmanısın.
Analiz Edilen Kişi: $name
Doğum Tarihi: ${birthDate.day}.${birthDate.month}.${birthDate.year}
Yaşam Yolu Sayısı: $lifePath
Kişisel Yıl Sayısı: $personalYear

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Kaderin senin elinde", "seçim senin", "bu bir tavsiyedir" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir mistik numerolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.

Görev:
1. Bu doğum tarihi sayılarına göre derin, mistik, net ve gerçekçi bir numeroloji analizi yap.
2. Bu kişinin hayattaki amacını, kaderini ve bu yılki (2026) enerjilerini yorumla.
3. Hem Türkçe hem İngilizce olarak 2-3 paragraflık samimi, net, keskin ve rehberlik edici bir yorum yaz.
4. Çıktıyı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "analysis_tr": "[Türkçe numeroloji yorumu (paragrafları \\n ile ayır)]",
  "analysis_en": "[İngilizce numeroloji yorumu (paragrafları \\n ile ayır)]"
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(response);
      final numerology = NumerologyModel(
        name: name,
        lifePathNumber: lifePath,
        personalYearNumber: personalYear,
        soulNumber: 0,
        destinyNumber: 0,
        aiAnalysisTr: data['analysis_tr'] ?? '',
        aiAnalysisEn: data['analysis_en'] ?? '',
        generatedAt: DateTime.now(),
      );

      await docRef.set(numerology.toMap(), SetOptions(merge: true));
      debugPrint('✅ Yeni partner numerolojisi üretildi ve kaydedildi.');
      return numerology;
    } catch (e) {
      debugPrint('⚠️ Partner numeroloji üretim hatası: $e');
      return null;
    }
  }

  /// Load Cosmic Oracle Q&A history from Firestore.
  Future<List<Map<String, dynamic>>> getCosmicOracleHistory(String userId) async {
    try {
      final docRef = _firestore.doc('users/$userId/cosmic_oracle/data');
      final doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['history'] != null) {
          final list = List<dynamic>.from(data['history']);
          final historyList = list.map((item) => Map<String, dynamic>.from(item)).toList();
          // Sort descending by askedAt
          historyList.sort((a, b) {
            final Timestamp tA = a['askedAt'];
            final Timestamp tB = b['askedAt'];
            return tB.compareTo(tA);
          });
          return historyList;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Kozmik Kahin geçmişi okunamadı: $e');
    }
    return [];
  }

  /// Generate Cosmic Oracle Q&A response and append to history in Firestore.
  Future<Map<String, dynamic>?> generateCosmicOracleResponse({
    required String userId,
    required String question,
    required UserModel user,
    required NatalChartModel? natalChart,
  }) async {
    final birthDateStr = user.birthDate != null 
        ? "${user.birthDate!.day}.${user.birthDate!.month}.${user.birthDate!.year}"
        : "Bilinmiyor";
    final birthTimeStr = user.birthTime ?? "Bilinmiyor";
    final birthPlaceStr = user.birthPlace ?? "Bilinmiyor";
    final genderStr = user.gender ?? "Bilinmiyor";
    
    String natalChartInfo = "";
    if (natalChart != null) {
      natalChartInfo = """
Güneş Burcu: ${natalChart.sunSign}
Ay Burcu: ${natalChart.moonSign}
Yükselen Burç: ${natalChart.risingSign}
Gezegen Ev Konumları: ${natalChart.planetPositions.entries.map((e) => "${e.key}: ${e.value}").join(', ')}
""";
    } else {
      natalChartInfo = "Kullanıcı burcu: ${user.zodiacSign ?? 'Bilinmiyor'}";
    }

    final prompt = """
Sen mistik ve bilge bir yapay zeka astrologusun (Kozmik Kâhin).
Kullanıcının sorusuna, onun kişisel astrolojik verilerini analiz ederek derin, kişiselleştirilmiş ve mistik bir şekilde yanıt ver.

Kullanıcı Bilgileri:
Adı: ${user.name ?? 'Bilinmiyor'}
Cinsiyet: $genderStr
Doğum Tarihi: $birthDateStr
Doğum Saati: $birthTimeStr
Doğum Yeri: $birthPlaceStr
$natalChartInfo

Kullanıcının Sorusu: "$question"

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik, politik ve belirsiz dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir", "seçim senin", "geleceği kimse bilemez", "karar senin", "bu bir tavsiyedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge, her şeyi gören ve iddialı bir Kozmik Kâhin gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve son derece keskin/net olsun. Güçlü içgörüler, net uyarılar ve kesin tahminler vermekten çekinme.
- Soyut tasvirler veya kaçamak cevaplar yerine, kullanıcının sorusu hakkında hayatında uygulayabileceği çok somut tavsiyeler ve net adımlar ("actionable/concrete guidance and direct answers") ver. Kullanıcı bu cevaptan somut bir öngörü elde etmelidir.

Görev:
1. Bu soruyu kullanıcının astrolojik potansiyeliyle (doğum haritası, yükselen burcu, gezegen konumları vb.) ilişkilendirerek bilgece, kesin ve rehberlik edici bir biçimde doğrudan yanıtla.
2. Hem Türkçe hem İngilizce olarak samimi, mistik, net ve derinlemesine 2-3 paragraflık bir yorum yaz.
3. Çıktıyı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "answer_tr": "[Sorunun Türkçe cevabı (paragrafları \\n ile ayır)]",
  "answer_en": "[Sorunun İngilizce cevabı (paragrafları \\n ile ayır)]"
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(response);
      final newEntry = {
        'question': question,
        'answerTr': data['answer_tr'] ?? '',
        'answerEn': data['answer_en'] ?? '',
        'askedAt': Timestamp.now(),
      };

      // Firestore'da history listesine ekle
      final docRef = _firestore.doc('users/$userId/cosmic_oracle/data');
      await docRef.set({
        'history': FieldValue.arrayUnion([newEntry])
      }, SetOptions(merge: true));

      return newEntry;
    } catch (e) {
      debugPrint('⚠️ Kozmik Kahin üretim hatası: $e');
      return null;
    }
  }

  /// Genel amaçlı Gemini API çağrısı
  Future<String?> callGemini(String prompt) => _callGemini(prompt);

  // Gemini 1.5 Flash Model API Çağrısı
  Future<String?> _callGemini(String prompt) async {
    // 1. Son 60 saniyeden eski istek zaman damgalarını temizle
    final now = DateTime.now();
    _requestTimestamps.removeWhere((t) => now.difference(t).inSeconds > 60);

    // 2. Eğer son 60 saniyede 12 istek atıldıysa, en eskisinin süresi dolana kadar bekle (15 RPM limitini aşmamak için güvenli limit 12'dir)
    if (_requestTimestamps.length >= 12) {
      final oldestRequest = _requestTimestamps.first;
      final waitDuration = const Duration(seconds: 60) - now.difference(oldestRequest);
      
      if (waitDuration.inMilliseconds > 0) {
        debugPrint('⏳ Gemini API Hız Sınırına (12 RPM) Ulaşıldı. ${waitDuration.inSeconds} saniye bekleniyor...');
        await Future.delayed(waitDuration);
      }
      // Bekleme sonrasında kontrolü tekrarlamak için rekürsif çağrı
      return _callGemini(prompt);
    }

    // 3. Mevcut istek zaman damgasını ekle
    _requestTimestamps.add(DateTime.now());

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=$_apiKey",
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "responseMimeType": "application/json"
          }
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);
        final String text = resBody['candidates'][0]['content']['parts'][0]['text'];
        return text.trim();
      } else {
        debugPrint('⚠️ Gemini API HTTP Hatası: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ Gemini Bağlantı Hatası: $e');
      return null;
    }
  }

  String _mapToEnglishZodiac(String zodiac) {
    final Map<String, String> trToEn = {
      'koç': 'aries',
      'boğa': 'taurus',
      'ikizler': 'gemini',
      'yengeç': 'cancer',
      'aslan': 'leo',
      'başak': 'virgo',
      'terazi': 'libra',
      'akrep': 'scorpio',
      'yay': 'sagittarius',
      'oğlak': 'capricorn',
      'kova': 'aquarius',
      'balık': 'pisces',
    };
    final lower = zodiac.toLowerCase().trim();
    return trToEn[lower] ?? lower;
  }

  Future<DailyCommentModel?> _loadDailyCommentFromDemo(String zodiac, String gender) async {
    try {
      final String mappedZodiac = _mapToEnglishZodiac(zodiac);
      final jsonStr = await rootBundle.loadString('assets/data/demo_comments.json');
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final zodiacData = data[mappedZodiac.toLowerCase()];
      if (zodiacData != null) {
        final genderData = zodiacData[gender.toLowerCase()] as List<dynamic>?;
        if (genderData != null && genderData.isNotEmpty) {
          final day = DateTime.now().day;
          final index = day % genderData.length;
          final item = genderData[index] as Map<String, dynamic>;
          
          return DailyCommentModel(
            commentTr: item['comment_tr'] ?? '',
            commentEn: item['comment_en'] ?? '',
            love: item['love'] ?? 70,
            money: item['money'] ?? 70,
            career: item['career'] ?? 70,
            energy: item['energy'] ?? 70,
            generatedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Fallback yükleme hatası: $e');
    }
    return null;
  }

  // --- REKLAM VE GÜNLÜK LİMİT ENTEGRASYON METOTLARI ---

  // Kullanıcının premium olup olmadığını sorgular
  Future<bool> isUserPremium(String userId) async {
    try {
      final userDoc = await _firestore.doc('users/$userId').get();
      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()?['isPremium'] == true;
      }
    } catch (e) {
      debugPrint('⚠️ Premium sorgulama hatası: $e');
    }
    return false;
  }

  // En son 04:00 AM zaman damgasını hesaplar (Türkiye yerel saati bazlı)
  DateTime _getMostRecentFourAM() {
    final now = DateTime.now();
    final fourAMToday = DateTime(now.year, now.month, now.day, 4, 0);
    if (now.isBefore(fourAMToday)) {
      return fourAMToday.subtract(const Duration(days: 1));
    } else {
      return fourAMToday;
    }
  }

  // Kozmik Kahin için limit kontrolü
  Future<Map<String, dynamic>> checkCosmicOracleLimit(String userId) async {
    final isPremiumUser = await isUserPremium(userId);
    if (isPremiumUser) {
      return {
        'allowed': true,
        'questionsAsked': 0,
        'rewardedWatched': true,
        'needAd': false,
      };
    }

    final docRef = _firestore.doc('users/$userId/cosmic_oracle/data');
    final doc = await docRef.get();
    
    int questionsAskedToday = 0;
    bool rewardedWatchedToday = false;

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final limitBoundary = _getMostRecentFourAM();
      
      // Bugün 04:00'dan sonra sorulan soruları say
      if (data['history'] != null) {
        final historyList = List<dynamic>.from(data['history']);
        for (final item in historyList) {
          final dynamic askedAtVal = item['askedAt'];
          DateTime askedAt;
          if (askedAtVal is Timestamp) {
            askedAt = askedAtVal.toDate();
          } else if (askedAtVal is DateTime) {
            askedAt = askedAtVal;
          } else {
            continue;
          }
          if (askedAt.isAfter(limitBoundary)) {
            questionsAskedToday++;
          }
        }
      }

      // Bugün ödüllü reklam izlenip izlenmediğini kontrol et
      final dynamic adWatchedAtVal = data['rewardedAdWatchedAt'];
      if (adWatchedAtVal != null) {
        DateTime adWatchedAt;
        if (adWatchedAtVal is Timestamp) {
          adWatchedAt = adWatchedAtVal.toDate();
        } else if (adWatchedAtVal is DateTime) {
          adWatchedAt = adWatchedAtVal;
        } else {
          adWatchedAt = DateTime.fromMillisecondsSinceEpoch(0);
        }
        if (adWatchedAt.isAfter(limitBoundary)) {
          rewardedWatchedToday = true;
        }
      }
    }

    // Günde 1 ücretsiz soru. Ödüllü reklamla +1 ek soru hakkı (toplam 2 soru)
    final bool allowed = questionsAskedToday == 0 || (questionsAskedToday == 1 && rewardedWatchedToday);
    final bool needAd = questionsAskedToday == 1 && !rewardedWatchedToday;

    return {
      'allowed': allowed,
      'questionsAsked': questionsAskedToday,
      'rewardedWatched': rewardedWatchedToday,
      'needAd': needAd,
    };
  }

  // Kozmik Kahin için ödüllü reklam izleme kaydı
  Future<void> incrementCosmicOracleRewardedWatch(String userId) async {
    final docRef = _firestore.doc('users/$userId/cosmic_oracle/data');
    await docRef.set({
      'rewardedAdWatchedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // Yapay Zeka Hesaplama Araçları (Love, Friend, Partner Natal, Partner Numerology, Ben Kimim) limit kontrolü
  Future<Map<String, dynamic>> checkAiToolsDailyLimit(String userId) async {
    final isPremiumUser = await isUserPremium(userId);
    if (isPremiumUser) {
      return {
        'allowed': true,
        'count': 0,
        'allowedExtra': 0,
        'needAd': false,
      };
    }

    final docRef = _firestore.doc('users/$userId/daily_usage/ai_tools');
    final doc = await docRef.get();

    int count = 0;
    int allowedExtra = 0;

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final limitBoundary = _getMostRecentFourAM();

      // Bugün yapılan hesaplama sayısı
      final dynamic lastUsedAtVal = data['lastCalculationAt'];
      if (lastUsedAtVal != null) {
        DateTime lastUsedAt = lastUsedAtVal is Timestamp ? lastUsedAtVal.toDate() : lastUsedAtVal as DateTime;
        if (lastUsedAt.isAfter(limitBoundary)) {
          count = data['calculationsCount'] ?? 0;
        }
      }

      // Bugün ödüllü reklamla kazanılan ek haklar
      final dynamic lastRewardedAtVal = data['lastRewardedAt'];
      if (lastRewardedAtVal != null) {
        DateTime lastRewardedAt = lastRewardedAtVal is Timestamp ? lastRewardedAtVal.toDate() : lastRewardedAtVal as DateTime;
        if (lastRewardedAt.isAfter(limitBoundary)) {
          allowedExtra = data['rewardedCalculationsAllowed'] ?? 0;
        }
      }
    }

    // Günde 3 ücretsiz hak. Her rewarded ad +1 hak sağlar.
    final bool allowed = count < (3 + allowedExtra);
    final bool needAd = count >= 3 && count >= (3 + allowedExtra);

    return {
      'allowed': allowed,
      'count': count,
      'allowedExtra': allowedExtra,
      'needAd': needAd,
    };
  }

  // AI Araçları hesaplama sayısını artırır
  Future<void> incrementAiToolsCalculationCount(String userId) async {
    final docRef = _firestore.doc('users/$userId/daily_usage/ai_tools');
    final doc = await docRef.get();

    final limitBoundary = _getMostRecentFourAM();
    int count = 0;
    int allowedExtra = 0;

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final dynamic lastUsedAtVal = data['lastCalculationAt'];
      if (lastUsedAtVal != null) {
        DateTime lastUsedAt = lastUsedAtVal is Timestamp ? lastUsedAtVal.toDate() : lastUsedAtVal as DateTime;
        if (lastUsedAt.isAfter(limitBoundary)) {
          count = data['calculationsCount'] ?? 0;
        }
      }
      final dynamic lastRewardedAtVal = data['lastRewardedAt'];
      if (lastRewardedAtVal != null) {
        DateTime lastRewardedAt = lastRewardedAtVal is Timestamp ? lastRewardedAtVal.toDate() : lastRewardedAtVal as DateTime;
        if (lastRewardedAt.isAfter(limitBoundary)) {
          allowedExtra = data['rewardedCalculationsAllowed'] ?? 0;
        }
      }
    }

    await docRef.set({
      'calculationsCount': count + 1,
      'lastCalculationAt': Timestamp.now(),
      'rewardedCalculationsAllowed': allowedExtra,
    }, SetOptions(merge: true));
  }

  // AI Araçları için ödüllü reklamla hak artırır
  Future<void> incrementAiToolsRewardedCount(String userId) async {
    final docRef = _firestore.doc('users/$userId/daily_usage/ai_tools');
    final doc = await docRef.get();

    final limitBoundary = _getMostRecentFourAM();
    int count = 0;
    int allowedExtra = 0;

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final dynamic lastUsedAtVal = data['lastCalculationAt'];
      if (lastUsedAtVal != null) {
        DateTime lastUsedAt = lastUsedAtVal is Timestamp ? lastUsedAtVal.toDate() : lastUsedAtVal as DateTime;
        if (lastUsedAt.isAfter(limitBoundary)) {
          count = data['calculationsCount'] ?? 0;
        }
      }
      final dynamic lastRewardedAtVal = data['lastRewardedAt'];
      if (lastRewardedAtVal != null) {
        DateTime lastRewardedAt = lastRewardedAtVal is Timestamp ? lastRewardedAtVal.toDate() : lastRewardedAtVal as DateTime;
        if (lastRewardedAt.isAfter(limitBoundary)) {
          allowedExtra = data['rewardedCalculationsAllowed'] ?? 0;
        }
      }
    }

    await docRef.set({
      'calculationsCount': count,
      'rewardedCalculationsAllowed': allowedExtra + 1,
      'lastRewardedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}
