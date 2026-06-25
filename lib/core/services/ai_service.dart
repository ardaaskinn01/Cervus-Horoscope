import 'dart:convert';
import 'dart:async';
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
import 'package:horoscope/core/models/tarot_reading_model.dart';
import 'package:horoscope/core/utils/astrology_utils.dart';
import 'package:horoscope/core/utils/birth_place_coords.dart';
import 'package:horoscope/core/utils/firestore_extension.dart';
import 'package:sweph/sweph.dart';

class AiService {
  // Gemini API Key loaded from environment variables
  // final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gemini Free Tier hız sınırını (12 RPM) yönetmek için statik zaman damgaları listesi
  static final List<DateTime> _requestTimestamps = [];
  
  // Çoklu API anahtarı havuzundaki aktif anahtarın indeksi
  // static int _currentKeyIndex = 0;

  /// Belirtilen burç, cinsiyet ve tarih için günlük yorum ve skorları üretip Firestore'a kaydeder.
  /// Maliyeti azaltmak amacıyla tek bir API çağrısında hem Türkçe hem İngilizce içerik üretilir.
  Future<DailyCommentModel?> generateAndSaveDailyComment({
    required String date,
    required String zodiac,
    required String gender,
  }) async {
    final docPath = 'daily_comments/${date}_${zodiac}_$gender';
    final docRef = _firestore.doc(docPath);

    // Önce Firestore'da var mı kontrol et (Duble üretimi önle)
    try {
      debugPrint('🔮 Firestore Kontrolü Başlıyor: $docPath');
      final docSnapshot = await docRef.safeGet(timeout: const Duration(seconds: 4));
      debugPrint('🔮 Firestore Kontrolü Tamamlandı. Var mı: ${docSnapshot.exists}');
      if (docSnapshot.exists && docSnapshot.data() != null) {
        debugPrint('ℹ️ Yorum Firestore\'da zaten mevcut, oradan çekiliyor.');
        return DailyCommentModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ Firestore okuma hatası, üretime devam ediliyor: $e');
    }

    // Deterministic hash based on date and zodiac (and optionally gender)
    int getDeterministicHash(String input) {
      int hash = 0;
      for (int i = 0; i < input.length; i++) {
        hash = input.codeUnitAt(i) + ((hash << 5) - hash);
      }
      return hash.abs();
    }

    final hashInput = '${date}_${zodiac.toLowerCase()}';
    final hash = getDeterministicHash(hashInput);

    // List of 15 daily planetary transit focus themes
    final transitThemes = [
      "Ay'ın İkizler burcundaki transiti ve Merkür açısı: Bugün zihinsel dağınıklık veya yoğun merak getirebilir, zihnimizi tek bir konuya odaklamak zor olabilir.",
      "Güneş ve Uranüs arasındaki uyumlu sekstil açı: Bugün beklenmedik güzel sürprizler, orijinal fikirler ve rutinin dışına çıkma arzusu yüksek.",
      "Venüs ve Satürn kare açısı: Duygusal konularda veya ilişkilerde mesafeli hissetme, sorumlulukların duyguların önüne geçmesi olası.",
      "Mars'ın Koç burcundaki güçlü konumu: İçsel motivasyon ve cesaret yüksek, ancak ani tepkiler vermeye veya aceleci davranmaya meyilliyiz.",
      "Merkür retrosunun son günleri: İletişim kazalarına karşı dikkatli olunması gereken, geçmişteki konuların tekrar gündeme gelebileceği bir gün.",
      "Ay ve Neptün kavuşumu: Sezgilerin çok güçlü olduğu, sanatsal veya yaratıcı uğraşlar için ideal ama gerçeklerden kaçma isteği uyandıran bir gün.",
      "Jüpiter'in olumlu etkileşimi: Şans ve büyüme enerjisi devrede, sosyal ortamlarda veya eğitim/iş alanlarında yeni fırsatlar doğabilir.",
      "Satürn'ün disipline edici transiti: Sabır ve planlama gerektiren konular ön planda, kısa vadeli kazançlar yerine uzun vadeli adımlar kazandırır.",
      "Yeni Ay enerjisinin getirdiği taze başlangıçlar: Hayatınızda yeni hedefler belirlemek, temiz bir sayfa açmak ve niyet etmek için harika bir gün.",
      "Dolunay'ın doruk noktası: Duyguların tavan yaptığı, uzun süredir sürüncemede kalan konuların netleşerek sonuca bağlandığı bir süreç.",
      "Venüs'ün Boğa burcundaki konforlu transiti: Maddi konulara, huzura, konfora ve ikili ilişkilerde güvene odaklandığımız sakin bir gün.",
      "Merkür ve Jüpiter üçgen açısı: Büyük resmi görmek, yeni fikirler üretmek, anlaşmalar yapmak veya eğitimde başarı elde etmek için elverişli.",
      "Plüton'un dönüştürücü gücü: Eski alışkanlıkları geride bırakmak, içsel gücümüzü fark etmek ve derin bir yenilenme yaşamak için bir fırsat.",
      "Ay'ın Başak burcundaki transiti: Detaylara odaklanmak, evi veya çalışma alanını düzenlemek, sağlığımıza özen göstermek için çok uygun.",
      "Güneş ve Neptün karşıtlığı: Kararsızlık, kafa karışıklığı veya hayal kırıklığı riski. Gerçekçi adımlar atmaya özen gösterilmeli."
    ];

    final theme = transitThemes[hash % transitThemes.length];

    // Compute dynamic ratings (range: 40 to 95)
    final loveScore = 40 + (hash % 56);
    final moneyScore = 40 + ((hash >> 2) % 56);
    final careerScore = 40 + ((hash >> 4) % 56);
    final energyScore = 45 + ((hash >> 6) % 51);

    final prompt = """
Sen profesyonel bir astroloji uzmanısın.
Burç: $zodiac
Kullanıcı Cinsiyeti: $gender (male ise erkek, female ise kadın)
Tarih: $date

Bugünün Göksel Transit Teması: $theme

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir", "kararlar senin", "hayatının kontrolü sende", "bu tavsiye niteliğindedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma.
- Üslup (Çok Önemli): Pozitif, samimi, chill (rahat), arkadaşça ve rahatlatıcı bir dil kullan. Mentor veya kişisel gelişim uzmanı havasından (örneğin "şunu yapmalısın, böyle davranmalısın, kendini geliştir, vizyonunu belirle" gibi üstten bakan, ders veren tavsiyelerden) kesinlikle kaçın. Karşındaki insanla bir dost gibi konuş, ona destek ver ve içini ferahlat.
- Yaşam Alanları (Çok Önemli): Sadece kurumsal iş hayatına odaklanma. Kullanıcı okulda, üniversitede, sınavlara hazırlık sürecinde veya kendi günlük projeleriyle meşgul olabilir. Bu yüzden "iş veya okul hayatı", "çalışmaların/günlük işlerin", "akademik ya da mesleki sorumlulukların" gibi kapsayıcı ifadeler kullan.
- Dil ve Cümle Yapısı: Sade, net, doğrudan ve anlaşılır cümleler kur. Edebi, süslü, ağdalı veya şiirsel betimlemelerden kesinlikle kaçın. Kullanıcının hızlıca okuyup somut bir rahatlama ve yön bulma çıkarabileceği doğrudan ve sade bir dil kullan.

Görev:
1. Bu burç ve cinsiyete özel, belirtilen tarih için bugünün göksel transit temasını temel alan, son derece samimi, motive edici, rahatlatıcı ve net günlük yorum yaz. Yorum mutlaka detaylı, derinlemesine ve en az 10 satır (yaklaşık 8-10 cümle) uzunluğunda olmalıdır.
2. Aşk, Para, Kariyer ve Enerji puanlarını şu değerler olarak belirle:
   - Aşk (love): $loveScore
   - Para (money): $moneyScore
   - Kariyer (career): $careerScore
   - Enerji (energy): $energyScore
   (JSON çıktısında bu puanları aynen kullanmalısın.)
3. Çıktıyı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "comment_tr": "[Buraya en az 10 satır uzunluğunda detaylı Türkçe günlük yorumu yaz]",
  "comment_en": "[Buraya en az 10 satır uzunluğunda detaylı İngilizce günlük yorumu yaz]",
  "love": $loveScore,
  "money": $moneyScore,
  "career": $careerScore,
  "energy": $energyScore
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) {
        throw Exception('Gemini response is null');
      }

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));
      final dailyComment = DailyCommentModel(
        commentTr: data['comment_tr'] ?? '',
        commentEn: data['comment_en'] ?? '',
        love: loveScore,
        money: moneyScore,
        career: careerScore,
        energy: energyScore,
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
    final docPath = 'monthly_comments/${month}_${zodiac}_$gender';
    final docRef = _firestore.doc(docPath);

    try {
      final docSnapshot = await docRef.safeGet();
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
- Edebi ve Yorucu Cümlelerden Kaçınma Kuralı: Ağdalı, aşırı edebi, sanatsal veya şiirsel tasvirlerden kesinlikle kaçın. Uzun, karmaşık ve yorucu cümleler yerine; kısa, son derece net, doğrudan ve anlaşılır cümleler kur. Derin sanatsal betimlemeler yapmak yerine kullanıcının hızlıca okuyup somut bir sonuç çıkarabileceği doğrudan ve sade bir dil kullan.

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

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));
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

  /// Doğum Haritasını Swiss Ephemeris ile yerel olarak hesaplar ve Firestore'a kaydeder.
  /// Gemini AI artık hesaplama yapmaz; sadece yorumlama amacıyla kullanılır.
  Future<NatalChartModel?> calculateAndSaveNatalChart({
    required String userId,
    required String name,
    required DateTime birthDate,
    required String birthTime,
    required String birthPlace,
    String? customPath,
    String? gender,
    bool forceRecalculate = false,
  }) async {
    final docRef = _firestore.doc(customPath ?? 'users/$userId/natal_chart/data');

    if (!forceRecalculate) {
      try {
        final docSnapshot = await docRef.safeGet();
        if (docSnapshot.exists && docSnapshot.data() != null) {
          return NatalChartModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    try {
      // ── 1. UTC doğum zamanını hesapla ─────────────────────────────────────
      final timeParts = birthTime.split(':');
      final localHour = int.parse(timeParts[0]);
      final localMinute = int.parse(timeParts[1]);
      final localDateTime = DateTime(birthDate.year, birthDate.month, birthDate.day, localHour, localMinute);
      final offset = AstrologyUtils.getTurkeyOffsetInHours(localDateTime);
      final utcDateTime = localDateTime.subtract(Duration(hours: offset));

      // ── 2. Julian Day (UT) hesapla ─────────────────────────────────────────
      final double utHour = utcDateTime.hour + utcDateTime.minute / 60.0;
      final double julDay = Sweph.swe_julday(
        utcDateTime.year,
        utcDateTime.month,
        utcDateTime.day,
        utHour,
        CalendarType.SE_GREG_CAL,
      );

      // ── 3. Koordinatları bul ───────────────────────────────────────────────
      final coords = BirthPlaceCoords.getCoords(birthPlace);
      final double lat = coords[0];
      final double lon = coords[1];

      // ── 4. Ev hesabı (Placidus) ────────────────────────────────────────────
      final HouseCuspData houseData = Sweph.swe_houses(
        julDay,
        lat,
        lon,
        Hsys.P,
      );

      // cusps[0] = house 1, cusps[11] = house 12
      final List<double> cusps = houseData.cusps.sublist(1, 13); // index 1..12
      final double ascLon = houseData.ascmc[0]; // index 0 is Ascendant

      // ── 5. Gezegen bilgilerini hesapla ─────────────────────────────────────
      // SwephFlag: SEFLG_SPEED to detect retrograde from speedInLongitude
      final SwephFlag flags = SwephFlag.SEFLG_SPEED;

      // (body id, Turkish name, English)
      final List<List<dynamic>> bodies = [
        [HeavenlyBody.SE_SUN,       'Güneş',        'sun'],
        [HeavenlyBody.SE_MOON,      'Ay',            'moon'],
        [HeavenlyBody.SE_MERCURY,   'Merkür',        'mercury'],
        [HeavenlyBody.SE_VENUS,     'Venüs',         'venus'],
        [HeavenlyBody.SE_MARS,      'Mars',          'mars'],
        [HeavenlyBody.SE_JUPITER,   'Jüpiter',       'jupiter'],
        [HeavenlyBody.SE_SATURN,    'Satürn',        'saturn'],
        [HeavenlyBody.SE_URANUS,    'Uranüs',        'uranus'],
        [HeavenlyBody.SE_NEPTUNE,   'Neptün',        'neptune'],
        [HeavenlyBody.SE_PLUTO,     'Plüton',        'pluto'],
        [HeavenlyBody.SE_TRUE_NODE, 'Kuzey Düğümü', 'true_node'],
        [HeavenlyBody.SE_MEAN_APOG, 'Lilith',        'lilith'],
        [HeavenlyBody.SE_CHIRON,    'Chiron',        'chiron'],
      ];

      // Burç isimleri (Türkçe)
      final List<String> signNamesTr = [
        'Koç', 'Boğa', 'İkizler', 'Yengeç', 'Aslan', 'Başak',
        'Terazi', 'Akrep', 'Yay', 'Oğlak', 'Kova', 'Balık',
      ];
      // Burç isimleri (İngilizce, küçük harf — sunSign/moonSign/risingSign için)
      final List<String> signNamesEn = [
        'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
        'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces',
      ];

      String lonToSignTr(double lon) {
        final idx = (lon / 30.0).floor() % 12;
        return signNamesTr[idx];
      }

      String lonToSignEn(double lon) {
        final idx = (lon / 30.0).floor() % 12;
        return signNamesEn[idx];
      }

      String lonToDegStr(double lon) {
        final degInSign = lon % 30.0;
        final deg = degInSign.floor();
        final min = ((degInSign - deg) * 60).round();
        return "$deg°${min.toString().padLeft(2, '0')}'";
      }

      /// Returns the house number (1-12) for a given ecliptic longitude.
      int findHouse(double lon, List<double> cusps) {
        for (int i = 0; i < 12; i++) {
          final start = cusps[i];
          final end = cusps[(i + 1) % 12];
          // Handle wraparound (e.g. cusp in Pisces, next in Aries)
          if (end > start) {
            if (lon >= start && lon < end) return i + 1;
          } else {
            if (lon >= start || lon < end) return i + 1;
          }
        }
        return 1;
      }

      final Map<String, dynamic> planetDetails = {};
      final Map<String, double>  planetAngles  = {};
      final Map<String, String>  planetPositions = {};

      for (final body in bodies) {
        final HeavenlyBody bodyId = body[0] as HeavenlyBody;
        final String nameTr  = body[1] as String;

        try {
          final CoordinatesWithSpeed pos = Sweph.swe_calc_ut(julDay, bodyId, flags);
          final double lon2 = pos.longitude % 360.0;
          final double speed = pos.speedInLongitude;
          final bool retrograde = speed < 0;
          final String signTr  = lonToSignTr(lon2);
          final String degStr  = lonToDegStr(lon2);
          final int houseNum   = findHouse(lon2, cusps);

          planetDetails[nameTr] = {
            'sign': signTr,
            'degree': degStr,
            'house': houseNum,
            'direction': retrograde ? 'Retro' : 'Direct',
          };
          planetAngles[nameTr] = lon2;
          planetPositions[nameTr] = '$signTr Burcu, $houseNum. Ev';
        } catch (e) {
          debugPrint('⚠️ $nameTr hesaplanamadı: $e');
        }
      }

      // ── 6. Yükselen (ASC) ─────────────────────────────────────────────────
      final String risingSignTr = lonToSignTr(ascLon);
      final String risingSignEn = lonToSignEn(ascLon);
      planetAngles['Yükselen'] = ascLon;
      planetPositions['Yükselen'] = '$risingSignTr Burcu, 1. Ev';

      // ── 7. Ev tablosunu oluştur ────────────────────────────────────────────
      const List<String> houseAnnotations = ['ASC', '', '', 'IC', '', '', 'DESC', '', '', 'MC', '', ''];
      final Map<String, dynamic> houseDetails = {};
      for (int i = 0; i < 12; i++) {
        final double cuspLon = cusps[i];
        houseDetails['${i + 1}'] = {
          'sign': lonToSignTr(cuspLon),
          'degree': lonToDegStr(cuspLon),
          'annotation': houseAnnotations[i],
        };
      }

      // ── 8. Güneş / Ay burçları ─────────────────────────────────────────────
      final double sunLon  = planetAngles['Güneş'] ?? 0.0;
      final double moonLon = planetAngles['Ay'] ?? 0.0;
      final String sunSignEn  = lonToSignEn(sunLon);
      final String moonSignEn = lonToSignEn(moonLon);

      // ── 9. Element, Modalite, Aspektler ───────────────────────────────────
      final elMod     = AstrologyUtils.calculateElementsAndModalities(planetDetails);
      final elements  = elMod['elements'];
      final modalities = elMod['modalities'];
      final aspects   = AstrologyUtils.calculateAspects(planetAngles);

      // ── 10. Model oluştur ve Firestore'a kaydet ────────────────────────────
      final chart = NatalChartModel(
        sunSign: sunSignEn,
        moonSign: moonSignEn,
        risingSign: risingSignEn,
        planetPositions: planetPositions,
        planetAngles: planetAngles,
        planetDetails: planetDetails,
        houseDetails: houseDetails,
        aspects: aspects,
        elements: elements,
        modalities: modalities,
        gender: gender,
        calculatedAt: DateTime.now(),
      );

      await docRef.set(chart.toMap()..['name'] = name, SetOptions(merge: true));
      debugPrint('✅ Doğum haritası Swiss Ephemeris ile hesaplandı ve Firestore\'a kaydedildi.');
      return chart;

    } catch (e) {
      debugPrint('⚠️ Doğum haritası hesaplama hatası (sweph): $e');
      return null;
    }
  }


  /// İki kişi arasındaki aşk veya arkadaşlık uyumunu hesaplar ve Firestore'a kaydeder.
  /// Artık her iki kişi için de tam natal chart hesaplanır, gerçek sinastri açıları bulunur
  /// ve Gemini'ye derinlemesine analiz için tüm veriler iletilir.
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
      final docSnapshot = await docRef.safeGet();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final cached = CompatibilityModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
        // Giriş parametreleri birebir eşleşiyorsa önbellekten çek
        // Sinastri verisi de varsa cache'i kullan
        if (cached.partnerBirthDate.year == partnerBirthDate.year &&
            cached.partnerBirthDate.month == partnerBirthDate.month &&
            cached.partnerBirthDate.day == partnerBirthDate.day &&
            cached.partnerBirthTime == partnerBirthTime &&
            cached.partnerBirthPlace == partnerBirthPlace &&
            cached.synastrAspects != null) {
          debugPrint('ℹ️ Uyum analizi (sinastri dahil) önbellekten alındı.');
          return cached;
        }
      }
    } catch (_) {}

    final bool isLove = type == 'love';
    final String scoreDesc = isLove
        ? '"loveScore" (Aşk Potansiyeli), "sexualityScore" (Cinsellik), "communicationScore" (İletişim), "longTermScore" (Uzun Vade)'
        : '"loyaltyScore" (Sadakat), "mutualInterestScore" (Ortak İlgi), "funScore" (Eğlence), "trustScore" (Güven)';

    // ── 1. Partner natal chart'ı Swiss Ephemeris ile hesapla ──────────────
    NatalChartModel? partnerNatalChart;
    if (partnerBirthTime != null && partnerBirthTime != 'Bilinmiyor' && partnerBirthPlace != null) {
      final normalizedName = partnerName.toLowerCase().replaceAll(' ', '_');
      final partnerChartPath = 'users/$userId/compatibility_partner_charts/$normalizedName';
      try {
        partnerNatalChart = await calculateAndSaveNatalChart(
          userId: userId,
          name: partnerName,
          birthDate: partnerBirthDate,
          birthTime: partnerBirthTime,
          birthPlace: partnerBirthPlace,
          customPath: partnerChartPath,
          gender: partnerGender,
        );
        debugPrint('✅ Partner natal chart hesaplandı: ${partnerNatalChart?.sunSign}');
      } catch (e) {
        debugPrint('⚠️ Partner natal chart hesaplama hatası: $e');
      }
    }

    // ── 2. Sinastri açılarını hesapla ────────────────────────────────────
    List<Map<String, dynamic>> synastrAspects = [];
    if (userNatalChart != null && partnerNatalChart != null) {
      synastrAspects = AstrologyUtils.calculateSynastriAspects(
        userNatalChart.planetAngles,
        partnerNatalChart.planetAngles,
      );
      debugPrint('✅ ${synastrAspects.length} sinastri açısı hesaplandı.');
    }

    // ── 3. Prompt için veri hazırla ───────────────────────────────────────
    final userBirthDateStr = user.birthDate != null
        ? "${user.birthDate!.day}.${user.birthDate!.month}.${user.birthDate!.year}"
        : "Bilinmiyor";

    // Kişi 1 natal chart bilgisi
    String userChartInfo = "";
    if (userNatalChart != null) {
      final positions = userNatalChart.planetDetails?.entries
          .map((e) {
            final d = e.value as Map<String, dynamic>;
            return "${e.key}: ${d['sign']} ${d['degree']} (${d['house']}. Ev)${d['direction'] == 'Retro' ? ' [R]' : ''}";
          })
          .join('\n') ?? userNatalChart.planetPositions.entries.map((e) => "${e.key}: ${e.value}").join('\n');

      userChartInfo = """
Güneş Burcu: ${userNatalChart.sunSign}
Ay Burcu: ${userNatalChart.moonSign}
Yükselen Burç: ${userNatalChart.risingSign}
Tam Gezegen Konumları:
$positions
""";
    } else {
      userChartInfo = "Güneş Burcu: ${user.zodiacSign ?? 'Bilinmiyor'}";
    }

    // Kişi 2 natal chart bilgisi
    String partnerChartInfo = "";
    if (partnerNatalChart != null) {
      final positions = partnerNatalChart.planetDetails?.entries
          .map((e) {
            final d = e.value as Map<String, dynamic>;
            return "${e.key}: ${d['sign']} ${d['degree']} (${d['house']}. Ev)${d['direction'] == 'Retro' ? ' [R]' : ''}";
          })
          .join('\n') ?? partnerNatalChart.planetPositions.entries.map((e) => "${e.key}: ${e.value}").join('\n');

      partnerChartInfo = """
Güneş Burcu: ${partnerNatalChart.sunSign}
Ay Burcu: ${partnerNatalChart.moonSign}
Yükselen Burç: ${partnerNatalChart.risingSign}
Tam Gezegen Konumları:
$positions
""";
    } else {
      partnerChartInfo = "Güneş Burcu: $partnerZodiacSign";
    }

    // Sinastri açıları özeti
    String synastriInfo = "";
    if (synastrAspects.isNotEmpty) {
      final aspectLines = synastrAspects.take(12).map((a) {
        final hard = (a['isHard'] as bool?) == true ? '⚡ SERT' : '✨ YUMUŞAK';
        return "${a['planet1']} (K1) — ${a['planet2']} (K2): ${a['aspect']} [$hard, orb: ${(a['orb'] as double).toStringAsFixed(1)}°]";
      }).join('\n');
      synastriInfo = """
Hesaplanan Sinastri Açıları (K1: ${user.name ?? 'Kişi 1'} / K2: $partnerName):
$aspectLines
""";
    }

    // ── 4. Gemini Prompt ───────────────────────────────────────────────────
    final prompt = """
Sen dünyanın en iyi sinastri ve uyum analizi uzmanı astrologusun. 
İki kişinin doğum haritaları arasındaki gerçek sinastri açıları (interaspects) hesaplanmış ve sana verilmiştir.
Uyum Türü: ${isLove ? 'Aşk Uyumu (Romantik İlişki)' : 'Arkadaşlık Uyumu'}

══════════════════════════════════════
KİŞİ 1 (${user.name ?? 'Kullanıcı'}):
Cinsiyet: ${user.gender ?? 'Bilinmiyor'}
Doğum Tarihi: $userBirthDateStr
Doğum Saati: ${user.birthTime ?? 'Bilinmiyor'}
Doğum Yeri: ${user.birthPlace ?? 'Bilinmiyor'}
$userChartInfo
══════════════════════════════════════
KİŞİ 2 ($partnerName):
Cinsiyet: $partnerGender
Doğti: ${partnerBirthDate.day}.${partnerBirthDate.month}.${partnerBirthDate.year}
Doğum Saati: ${partnerBirthTime ?? 'Bilinmiyor'}
Doğum Yeri: ${partnerBirthPlace ?? 'Bilinmiyor'}
$partnerChartInfo
${synastriInfo.isNotEmpty ? '══════════════════════════════════════\nSİNASTRİ AÇILARI:\n$synastriInfo' : ''}
══════════════════════════════════════

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir", "kararlar senin", "hayatının kontrolü sende", "bu tavsiye niteliğindedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.
- Edebi ve Yorucu Cümlelerden Kaçınma Kuralı: Ağdalı, aşırı edebi, sanatsal veya şiirsel tasvirlerden kesinlikle kaçın. Kısa, son derece net, doğrudan ve anlaşılır cümleler kur.
- Uyum Puanlamaları: Skorlar son derece keskin ve gerçekçi olmalıdır. En kötü uyumda bile 60'ın altına inme (60-65 bandı en kötüyü temsil etsin).
- Keskin ve Net Analiz: Olumsuz/zorlu açılarda tam olarak nereden sorun yaşanacağını ("Güneş-Mars kare açınız nedeniyle öfke patlamaları kaçınılmaz", "Venüs-Satürn karesi duygusal mesafe yaratır" gibi) son derece net ve keskin cümlelerle açıkla.
- Bütünsel Element ve Harita Sentezi (Astrolojik Ağırlık): Sadece elementlerin sayısal oranlarına bakarak mekanik yorumlar yapma. Bir kişinin haritasında hava/toprak çoğunlukta olsa bile, eğer Güneş (Sun), Ay (Moon), Venüs (Venus) veya Mars gibi kişisel gezegenleri Su gruplarında (Yengeç, Akrep, Balık) ise, bu kişi duygusal açıdan soğuk veya mesafeli değildir. Aksine derin duygulara, ilgi ve şefkat ihtiyacına sahiptir (örneğin Güneş ve Mars'ı Yengeç olan bir kadın son derece duygusal, korumacı ve ilgi isteyendir). Kişisel gezegenlerin (Güneş, Ay, Venüs, Mars) konumlarını, element genel dağılımının önüne koyarak duygusal yakınlık/mesafe sentezi yap.

${isLove ? '''Aşk Sinastri Yorumu için Özel Kurallar:
- Venüs-Mars aspektleri: Fiziksel çekim ve tutku açısından yorumla. Kadın haritasındaki Mars ve erkek haritasındaki Venüs birbirini nasıl etkiliyor?
- Güneş-Ay aspektleri: Birinin ruhu diğerinin kimliğini "evde" hissettiriyor mu?
- Satürn aspektleri: Uzun vadeli bağlılık sinyalleri mi, kısıtlama mı?
''' : '''Arkadaşlık Sinastri Yorumu için Özel Kurallar:
- Merkür aspektleri ve konumları: Zihinsel uyum, sohbet kalitesi, espri anlayışı, zeka uyumu ve muhabbet sıklığını/kalitesini yorumla.
- Ay aspektleri: Duygusal konfor alanı, güvende hissetme ve sessizce yan yana durabilme bağını (duygusal yakınlık) yorumla.
- 11. Ev yerleşimleri: Sosyal çevreye bakış, ortak zevkler ve arkadaşlığı hayatına çekme şekillerini analiz et.
'''}

Görev:
1. Bu iki kişinin TAM DOĞUM HARITASI verilerine ve sinastri açılarına dayanarak derinlemesine, gerçekçi ve samimi bir uyum analizi yap.
2. Genel uyum yüzdesini (0 ile 100 arası tamsayı) belirle.
3. Şu alt skorları (0 ile 100 arası tamsayı) belirle: $scoreDesc.
4. En kritik ${synastrAspects.isNotEmpty ? 'sinastri açılarından' : 'gezegen etkileşimlerinden'} 3-5 tanesini seç ve her biri için kısa ama vurucu bir Türkçe ve İngilizce yorum yaz (synastriHighlights).
5. Hem Türkçe hem İngilizce olarak 3-4 paragraflık samimi, mistik, net ve detaylı genel analiz yorumları yaz.
6. Aşk veya Arkadaşlık fark etmeksizin Pro analiz bölümlerini şu kurallarla doldur:
   - "karmicBonds": İki kişi arasındaki ruhsal, karmik ve derin bağları inceleyen (Türkçe ve İngilizce) detaylı bir paragraf.
   - "conflictResolution": Haritalardaki zorlu açılara ve element uyumsuzluklarına göre, ilişkideki olası kavgaları/anlaşmazlıkları çözmek için çiftin uygulayabileceği son derece somut, yapıcı ve doğrudan tavsiyeler içeren (Türkçe ve İngilizce) detaylı bir paragraf.
   - "growthTimeline": Gelecek 1 yıldaki potansiyel dönüm noktalarını, gelişim aşamalarını ve kritik göksel tarih etkilerini anlatan (Türkçe ve İngilizce) detaylı bir paragraf.
7. Yanıtı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "overallScore": [Genel uyum puanı],
  "scores": {
    ${isLove ? '"loveScore": [Puan], "sexualityScore": [Puan], "communicationScore": [Puan], "longTermScore": [Puan]' : '"loyaltyScore": [Puan], "mutualInterestScore": [Puan], "funScore": [Puan], "trustScore": [Puan]'}
  },
  "synastriHighlights": [
    {
      "planet1": "[Kişi 1 gezegeni]",
      "planet2": "[Kişi 2 gezegeni]",
      "aspect": "[Açı türü]",
      "isHard": [true/false],
      "interpretationTr": "[Bu açının tek cümlelik net Türkçe yorumu]",
      "interpretationEn": "[This aspect's concise English interpretation]"
    }
  ],
  "karmicBonds": {
    "tr": "[Ruhsal ve karmik bağlar Türkçe analizi]",
    "en": "[Deep spiritual and karmic bonds English analysis]"
  },
  "conflictResolution": {
    "tr": "[Çatışma çözümü ve somut iletişim tavsiyeleri Türkçe]",
    "en": "[Conflict resolution and actionable communication advice English]"
  },
  "growthTimeline": {
    "tr": "[Gelecek 1 yıl gelişim zaman tüneli ve kritik tarihler Türkçe]",
    "en": "[Next 1 year growth timeline and critical dates English]"
  },
  "comment_tr": "[Türkçe analiz yorumu (paragrafları \\n ile ayır)]",
  "comment_en": "[İngilizce analiz yorumu (paragrafları \\n ile ayır)]"
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));

      // synastriHighlights parse et
      List<Map<String, dynamic>>? highlights;
      if (data['synastriHighlights'] != null) {
        highlights = List<Map<String, dynamic>>.from(
          (data['synastriHighlights'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }

      final karmicBonds = data['karmicBonds'] as Map<String, dynamic>?;
      final conflictResolution = data['conflictResolution'] as Map<String, dynamic>?;
      final growthTimeline = data['growthTimeline'] as Map<String, dynamic>?;

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
        synastrAspects: synastrAspects.isNotEmpty ? synastrAspects : null,
        userPlanetPositions: userNatalChart?.planetPositions.cast<String, dynamic>(),
        partnerPlanetPositions: partnerNatalChart?.planetPositions.cast<String, dynamic>(),
        synastriHighlights: highlights,
        karmicBondsTr: karmicBonds?['tr'] ?? '',
        karmicBondsEn: karmicBonds?['en'] ?? '',
        conflictResolutionTr: conflictResolution?['tr'] ?? '',
        conflictResolutionEn: conflictResolution?['en'] ?? '',
        growthTimelineTr: growthTimeline?['tr'] ?? '',
        growthTimelineEn: growthTimeline?['en'] ?? '',
      );

      await docRef.set(compatibility.toMap(), SetOptions(merge: true));
      debugPrint('✅ Yeni sinastri tabanlı uyum analizi üretildi ve kaydedildi: $docPath');
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
    bool forceRecalculate = false,
  }) async {
    final docRef = _firestore.doc('users/$userId/character_analysis/data');

    if (!forceRecalculate) {
      try {
        final docSnapshot = await docRef.safeGet();
        if (docSnapshot.exists && docSnapshot.data() != null) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          // Eski format kontrolü: personalityDimensions yoksa yeniden hesapla
          if (data.containsKey('personalityDimensions') &&
              (data['personalityDimensions'] as List?)?.isNotEmpty == true) {
            return CharacterAnalysisModel.fromMap(data);
          }
        }
      } catch (_) {}
    } else {
      // Eski dokümanı sil, taze üret
      try { await docRef.delete(); } catch (_) {}
    }

    final planetListStr = natalChart.planetPositions.entries
        .map((e) => "${e.key}: ${e.value}")
        .join('\n');

    final houseListStr = natalChart.houseDetails != null
        ? natalChart.houseDetails!.entries
            .map((e) => "${e.key}: ${e.value}")
            .join('\n')
        : '';

    final aspectsStr = natalChart.aspects != null
        ? natalChart.aspects!.entries
            .map((e) => "${e.key}: ${e.value}")
            .join('\n')
        : '';

    final prompt = """
Sen derinlikli psikolojik astroloji analizleri yapan uzman bir astrologsun.
Kullanıcı Adı: $name
Güneş Burcu: ${natalChart.sunSign}
Ay Burcu: ${natalChart.moonSign}
Yükselen Burç: ${natalChart.risingSign}

Gezegen Konumları (Burç + Ev):
$planetListStr
${houseListStr.isNotEmpty ? '\nEv Konumları:\n$houseListStr' : ''}
${aspectsStr.isNotEmpty ? '\nGezegensel Açılar (Aspektler):\n$aspectsStr' : ''}
Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- Sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun.
- Edebi ve Yorucu Cümlelerden Kaçın: Kısa, son derece net, doğrudan ve anlaşılır cümleler kur.
- secretSelf ve spiritualJourney için minimum 5 cümle yaz. Kullanıcının kendini GERÇEKTEN tanıdığını hissetmesini sağla. Somut ve kişisel ol.

Görev:
1. Bu doğum haritasına göre kullanıcının kişiliğini detaylıca analiz et.
2. Aşağıdaki alanları belirle:
   - "personalityDimensions": Tam 12 adet zıt kişilik boyutu. Her boyut için leftPercent değeri 0-100 arasında bir tamsayı olmalı. Bu değer sol kutbun ne kadar baskın olduğunu gösterir (sağ = 100 - leftPercent). Gerçekçi ve harita bazlı değerler ver. 50-50 verme, gerçek bir kutba yaklaştır.
   - "strengths" (5 adet kısa madde, TR ve EN ayrı).
   - "weaknesses" (5 adet kısa madde, TR ve EN ayrı).
   - "careers" (6 meslek adı, TR ve EN ayrı).
   - "secretSelf" (Ay burcu temelli içsel dünya analizi. Minimum 5 cümle. Net, somut, kişisel. TR ve EN ayrı).
   - "spiritualJourney" (Yükselen burç temelli yaşam dersi analizi. Minimum 5 cümle. Net, somut, rehber niteliğinde. TR ve EN ayrı).
3. Sonucu aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama yazma.

JSON formatı:
{
  "personalityDimensions": [
    {"leftLabelTr": "Sezgisel", "rightLabelTr": "Analitik", "leftLabelEn": "Intuitive", "rightLabelEn": "Analytical", "leftPercent": [0-100]},
    {"leftLabelTr": "İçe Dönük", "rightLabelTr": "Dışa Dönük", "leftLabelEn": "Introverted", "rightLabelEn": "Extroverted", "leftPercent": [0-100]},
    {"leftLabelTr": "Duygusal", "rightLabelTr": "Mantıksal", "leftLabelEn": "Emotional", "rightLabelEn": "Rational", "leftPercent": [0-100]},
    {"leftLabelTr": "Spontane", "rightLabelTr": "Planlı", "leftLabelEn": "Spontaneous", "rightLabelEn": "Structured", "leftPercent": [0-100]},
    {"leftLabelTr": "İdealist", "rightLabelTr": "Realist", "leftLabelEn": "Idealistic", "rightLabelEn": "Realistic", "leftPercent": [0-100]},
    {"leftLabelTr": "Bağımsız", "rightLabelTr": "Uyumlu", "leftLabelEn": "Independent", "rightLabelEn": "Cooperative", "leftPercent": [0-100]},
    {"leftLabelTr": "Risk Seven", "rightLabelTr": "Güvene Önem Veren", "leftLabelEn": "Risk-Taking", "rightLabelEn": "Security-Seeking", "leftPercent": [0-100]},
    {"leftLabelTr": "Sabırsız", "rightLabelTr": "Sabırlı", "leftLabelEn": "Impulsive", "rightLabelEn": "Patient", "leftPercent": [0-100]},
    {"leftLabelTr": "Yaratıcı", "rightLabelTr": "Pratik", "leftLabelEn": "Creative", "rightLabelEn": "Practical", "leftPercent": [0-100]},
    {"leftLabelTr": "Kararlı", "rightLabelTr": "Esnek", "leftLabelEn": "Decisive", "rightLabelEn": "Adaptable", "leftPercent": [0-100]},
    {"leftLabelTr": "İçgüdüsel", "rightLabelTr": "Düşünceli", "leftLabelEn": "Instinctive", "rightLabelEn": "Deliberate", "leftPercent": [0-100]},
    {"leftLabelTr": "Tutkulu", "rightLabelTr": "Sakin", "leftLabelEn": "Passionate", "rightLabelEn": "Calm", "leftPercent": [0-100]}
  ],
  "strengths_tr": ["madde 1", "madde 2", "madde 3", "madde 4", "madde 5"],
  "strengths_en": ["item 1", "item 2", "item 3", "item 4", "item 5"],
  "weaknesses_tr": ["madde 1", "madde 2", "madde 3", "madde 4", "madde 5"],
  "weaknesses_en": ["item 1", "item 2", "item 3", "item 4", "item 5"],
  "careers_tr": ["meslek 1", "meslek 2", "meslek 3", "meslek 4", "meslek 5", "meslek 6"],
  "careers_en": ["career 1", "career 2", "career 3", "career 4", "career 5", "career 6"],
  "secretSelf_tr": "[Minimum 5 cümle - Ay burcuna göre Türkçe içsel dünya analizi]",
  "secretSelf_en": "[Minimum 5 sentences - Moon sign based inner world analysis in English]",
  "spiritualJourney_tr": "[Minimum 5 cümle - Yükselen burç ve yaşam amacı Türkçe]",
  "spiritualJourney_en": "[Minimum 5 sentences - Rising sign and life purpose in English]"
}
""";


    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));

      final dims = (data['personalityDimensions'] as List? ?? []).map((d) {
        return PersonalityDimension(
          leftLabelTr: d['leftLabelTr'] ?? '',
          rightLabelTr: d['rightLabelTr'] ?? '',
          leftLabelEn: d['leftLabelEn'] ?? '',
          rightLabelEn: d['rightLabelEn'] ?? '',
          leftPercent: (d['leftPercent'] as num?)?.toInt() ?? 50,
        );
      }).toList();

      final analysis = CharacterAnalysisModel(
        personalityDimensions: dims,
        strengthsTr: List<String>.from(data['strengths_tr'] ?? []),
        strengthsEn: List<String>.from(data['strengths_en'] ?? []),
        weaknessesTr: List<String>.from(data['weaknesses_tr'] ?? []),
        weaknessesEn: List<String>.from(data['weaknesses_en'] ?? []),
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

  /// Tarot açılımı yorumu üretir ve Firestore'a kaydeder.
  Future<TarotReadingModel?> generateTarotReading({
    required String userId,
    required String category,
    required List<TarotCardDraw> draws,
    required UserModel user,
    required NatalChartModel? userNatalChart,
  }) async {
    final readingId = FirebaseFirestore.instance.collection('users/$userId/tarot_readings').doc().id;
    final docPath = 'users/$userId/tarot_readings/$readingId';
    final docRef = _firestore.doc(docPath);

    // Kategori isimlerini Türkçe ve İngilizceye çevirmek için
    final Map<String, String> categoryNameTr = {
      'love': 'Aşk ve İlişkiler',
      'career': 'Kariyer ve Finans',
      'health': 'Sağlık ve Enerji',
      'decision': 'Karar Verme / Yol Ayrımı',
      'general': 'Günlük Kozmik Tavsiye',
    };

    final Map<String, String> categoryNameEn = {
      'love': 'Love & Relationships',
      'career': 'Career & Finance',
      'health': 'Health & Energy',
      'decision': 'Decision Making',
      'general': 'Daily Cosmic Guidance',
    };

    final userBirthDateStr = user.birthDate != null
        ? "${user.birthDate!.day}.${user.birthDate!.month}.${user.birthDate!.year}"
        : "Bilinmiyor";

    String userChartInfo = "";
    if (userNatalChart != null) {
      userChartInfo = """
Güneş Burcu: ${userNatalChart.sunSign}
Ay Burcu: ${userNatalChart.moonSign}
Yükselen Burç: ${userNatalChart.risingSign}
Gezegen Konumları: ${userNatalChart.planetPositions.entries.map((e) => "${e.key}: ${e.value}").join(', ')}
""";
    }

    final String cardsDescription = draws.map((d) {
      final direction = d.isUpright ? 'DÜZ' : 'TERS';
      final positionLabel = d.position == 'past'
          ? 'Mevcut Durum / Yakın Geçmiş'
          : (d.position == 'present' ? 'Karşılaşılan Engel / Şimdi' : 'Kozmik Tavsiye / Gelecek');
      return """
Pozisyon: $positionLabel
Kart Adı: ${d.cardNameTr} (İngilizce: ${d.cardNameEn})
Simge: ${d.symbol}
Yön: $direction (Kart ${d.isUpright ? 'düz' : 'ters'} çekilmiştir)
""";
    }).join('\n---\n');

    final prompt = """
Sen dünyanın en bilge tarot ve astroloji uzmanı ve yorumcususun. 
Kullanıcı senin karşına gelip hayatının bir alanı hakkında 3 kartlık bir açılım yaptı ve senden bu kartları kendi astrolojik haritasıyla ilişkilendirerek derinlemesine yorumlamanı istiyor.

Kullanıcı Bilgileri:
Adı: ${user.name ?? 'Kullanıcı'}
Cinsiyet: ${user.gender ?? 'Bilinmiyor'}
Doğum Tarihi: $userBirthDateStr
Doğum Saati: ${user.birthTime ?? 'Bilinmiyor'}
Doğum Yeri: ${user.birthPlace ?? 'Bilinmiyor'}
$userChartInfo

Açılım Kategorisi: ${categoryNameTr[category] ?? category} (İngilizce: ${categoryNameEn[category] ?? category})

Çekilen Kartlar:
$cardsDescription

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki tarot sadece bir yol göstericidir", "kararlar senin", "hayatının kontrolü sende", "bu tavsiye niteliğindedir", "sabırlı olmalısın" gibi sorumluluk reddi (disclaimer) veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog-tarot yorumcusu gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar vermekten çekinme.
- Soyut tasvirler yerine kullanıcının hayatında uygulayabileceği somut adımlar ("actionable/concrete guidance") ver.
- Edebi ve Yorucu Cümlelerden Kaçınma Kuralı: Ağdalı, aşırı edebi, sanatsal veya şiirsel tasvirlerden kesinlikle kaçın. Uzun, karmaşık ve yorucu cümleler yerine; kısa, son derece net, doğrudan ve anlaşılır cümleler kur.
- Astro-Tarot Bağlantısı: Çekilen kartların astrolojik simgelerini ve burç/gezegen eşleşmelerini, kullanıcının doğum haritasındaki konumlarla (özellikle Güneş, Ay ve Yükselen burcuyla) ilişkilendir. Aralarındaki kozmik uyumu veya çekişmeyi mutlaka vurgula.

Görev:
1. Çekilen 3 kartı pozisyonlarına (Geçmiş/Durum, Engel/Şimdi, Gelecek/Tavsiye) ve Düz/Ters yönlerine göre seçilen kategori bağlamında analiz et.
2. Kartlar ile kullanıcının doğum haritası arasında kozmik bağlantılar kur.
3. Hem Türkçe hem İngilizce olarak 3-4 paragraflık samimi, mistik, son derece net ve detaylı bir yorum yaz.
4. Yanıtı aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

JSON formatı:
{
  "comment_tr": "[Türkçe tarot analizi yorumu (paragrafları \\n ile ayır)]",
  "comment_en": "[İngilizce tarot analizi yorumu (paragrafları \\n ile ayır)]"
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));
      final reading = TarotReadingModel(
        id: readingId,
        category: category,
        draws: draws,
        commentTr: data['comment_tr'] ?? '',
        commentEn: data['comment_en'] ?? '',
        date: DateTime.now(),
      );

      await docRef.set(reading.toMap(), SetOptions(merge: true));
      debugPrint('✅ Yeni tarot açılımı üretildi ve kaydedildi: $docPath');
      return reading;
    } catch (e) {
      debugPrint('⚠️ Tarot açılımı üretim hatası: $e');
      return null;
    }
  }

  /// Doğum Haritasına göre tüm 12 burcun uyumunu hesaplar ve Firestore'a kaydeder.
  Future<BestMatchesModel?> generateBestMatches({
    required String userId,
    required String sunSign,
    required String moonSign,
    required String risingSign,
    bool forceRecalculate = false,
  }) async {
    final docRef = _firestore.doc('users/$userId/best_matches/data');

    if (!forceRecalculate) {
      try {
        final docSnapshot = await docRef.safeGet();
        if (docSnapshot.exists && docSnapshot.data() != null) {
          final model = BestMatchesModel.fromMap(docSnapshot.data() as Map<String, dynamic>);
          // Eski 3-burçlu veri kontrolü: 10'dan az ise yeniden hesapla
          if (model.romanticMatches.length >= 10) {
            return model;
          }
        }
      } catch (_) {}
    } else {
      try { await docRef.delete(); } catch (_) {}
    }

    final prompt = """
Sen astrolojik eşleşme ve sinastri uzmanı bir astrologsun.
Kullanıcı Nitelikleri:
Güneş Burcu: $sunSign
Ay Burcu: $moonSign
Yükselen Burç: $risingSign

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- Sorumluluk reddi veya klişe yapay zeka uyarılarını asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorumlar doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun.
- Edebi ve Yorucu Cümlelerden Kaçın: Kısa, son derece net, doğrudan ve anlaşılır cümleler kur.

Görev:
1. Bu kullanıcının harita dinamiklerine (Sun/Moon/Rising uyumu) göre TÜM 12 burcun romantik (aşk) ve arkadaşlık eşleşmelerini belirle.
   - Romantik Eşleşmeleri (romanticMatches) belirlerken: Venüs-Mars (romantizm ve fiziksel kimya), Güneş-Ay (ruhsal yakınlık/evinde hissetme) uyumunu baz alarak en iyi aşk uyumundan en aza doğru sırala.
   - Arkadaşlık Eşleşmelerini (friendMatches) belirlerken: Merkür-Merkür veya Merkür-Ay (zihinsel uyum, sohbet kalitesi, zeka, espriler) ve 11. Ev (sosyal çevre/arkadaşlık) dinamiklerini baz alarak en iyi dostluk uyumundan en aza doğru sırala.
2. Her eşleşen burç için kısa, vurucu, net ve son derece samimi bir gerekçe (1-2 cümle) yaz. Bu gerekçeyi hem Türkçe hem İngilizce dillerinde ayrı ayrı ver.
3. Sonucu aşağıdaki JSON formatında ver. JSON dışında hiçbir açıklama veya markdown bloğu yazma.

Zodiac listesi: aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces. (Küçük harfle olmalı).

JSON formatı:
{
  "romanticMatches": [
    {"zodiacSign": "[burç adı]", "reasonTr": "[Türkçe gerekçe]", "reasonEn": "[İngilizce gerekçe]"},
    ... (tam 12 burç, uyum sırasına göre - en uyumludan en az uyumluya)
  ],
  "friendMatches": [
    {"zodiacSign": "[burç adı]", "reasonTr": "[Türkçe gerekçe]", "reasonEn": "[İngilizce gerekçe]"},
    ... (tam 12 burç, uyum sırasına göre - en uyumludan en az uyumluya)
  ]
}
""";

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));
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
      final docSnapshot = await docRef.safeGet();
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

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));
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
      final docSnapshot = await docRef.safeGet();
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
- Edebi ve Yorucu Cümlelerden Kaçınma Kuralı: Ağdalı, aşırı edebi, sanatsal veya şiirsel tasvirlerden kesinlikle kaçın. Uzun, karmaşık ve yorucu cümleler yerine; kısa, son derece net, doğrudan ve anlaşılır cümleler kur. Derin sanatsal betimlemeler yapmak yerine kullanıcının hızlıca okuyup somut bir sonuç çıkarabileceği doğrudan ve sade bir dil kullan.

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

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));
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
      final doc = await docRef.safeGet();
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
- Edebi ve Yorucu Cümlelerden Kaçınma Kuralı: Ağdalı, aşırı edebi, sanatsal veya şiirsel tasvirlerden kesinlikle kaçın. Uzun, karmaşık ve yorucu cümleler yerine; kısa, son derece net, doğrudan ve anlaşılır cümleler kur. Derin sanatsal betimlemeler yapmak yerine kullanıcının hızlıca okuyup somut bir sonuç çıkarabileceği doğrudan ve sade bir dil kullan.

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

      final Map<String, dynamic> data = jsonDecode(_sanitizeJson(response));
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

  /// Generate a detailed planetary interpretation on demand.
  Future<String?> generatePlanetInterpretation({
    required String planet,
    required String sign,
    required String house,
    required String languageCode,
    String? gender,
  }) async {
    final isTr = languageCode == 'tr';
    
    final String genderInfo;
    if (gender == 'male') {
      genderInfo = isTr ? 'Erkek' : 'Male';
    } else if (gender == 'female') {
      genderInfo = isTr ? 'Kadın' : 'Female';
    } else {
      genderInfo = isTr ? 'Belirtilmemiş' : 'Not specified';
    }

    final prompt = """
Sen usta bir astrologsun. Kullanıcının doğum haritasında $planet gezegeni $sign burcunda ve $house. evde bulunuyor.
Kullanıcı Cinsiyeti: $genderInfo

Karakteristik Kurallar (Çok Önemli):
- Sıradan, yapay zeka tarafından yazıldığı belli olan diplomatik ve politik dilden kesinlikle kaçın.
- "Unutma ki astroloji sadece bir yol göstericidir" gibi sorumluluk reddi (disclaimer) veya klişe uyarıları asla kullanma. Gerçek, bilge ve iddialı bir astrolog gibi konuş.
- Yorum doğrudan, samimi, insan eliyle yazılmış gibi ("humanized") ve keskin olsun. Güçlü içgörüler ve net uyarılar ver.
- Edebi ve Yorucu Cümlelerden Kaçınma Kuralı: Ağdalı, aşırı edebi, sanatsal veya şiirsel tasvirlerden kesinlikle kaçın. Uzun, karmaşık ve yorucu cümleler yerine; kısa, son derece net, doğrudan ve anlaşılır cümleler kur. Derin sanatsal betimlemeler yapmak yerine kullanıcının hızlıca okuyup somut bir sonuç çıkarabileceği doğrudan ve sade bir dil kullan.
- Cinsiyet Nüansı: Yorumu hazırlarken kullanıcının cinsiyetini ($genderInfo) göz önünde bulundur. Özellikle Mars (mücadele tarzı, dürtüler, erkek haritasında kendi eril enerjisini kullanma şekli, kadın haritasında çekim duyduğu eril arketip) ve Venüs (ilişki beklentileri, sevgi dili, kadın haritasında kendi dişil kimliği, erkek haritasında çekim duyduğu dişil arketip) yerleşimlerini yorumlarken bu cinsiyete özel nüansları yansıt. Diğer gezegenlerde de eğer cinsiyetin etkisi varsa bunu yansıt.

Görev:
1. Bu yerleşimin (gezegenin bu burçta ve bu evde olmasının) kişinin psikolojisine, yaşam hedeflerine ve günlük hayatına etkisini derinlemesine analiz et.
2. ${isTr ? 'Sadece Türkçe dilinde' : 'Sadece İngilizce dilinde'} 2 paragraf uzunluğunda (yaklaşık 100-150 kelime) çok etkileyici ve akıcı bir yorum yaz.
3. Çıktıyı düz metin olarak ver. JSON formatı KULLANMA. Sadece doğrudan yorumu yaz.
""";

    try {
      final response = await _callGemini(prompt, isJson: false);
      return response;
    } catch (e) {
      debugPrint('⚠️ Planet Interpretation Hatası: $e');
      return null;
    }
  }

  Future<String?> generateRisingSignInterpretation({
    required String risingSign,
    required String languageCode,
  }) async {
    final isTr = languageCode == 'tr';

    final prompt = isTr
        ? """
Sen usta bir astrologsun. Kullanıcının yükselen burcu (ASC) $risingSign'dır.

Kurallar:
- Sorumluluk reddi, klişe uyarılar, "astroloji sadece yol göstericidir" gibi ifadelerden kaçın.
- Kısa, net, doğrudan cümleler kur. Edebi betimlemelerden uzak dur.
- İnsan eliyle yazılmış, gerçek bir astrolog gibi yaz.

Yükselen burcun kişinin dış görünüşüne, ilk izlenimine, hayata bakış açısına ve fiziksel enerjisine nasıl yansıdığını 2 paragrafta (yaklaşık 100-150 kelime) Türkçe olarak yaz. Sadece düz metin ver, JSON kullanma.
"""
        : """
You are a skilled astrologer. The user's rising sign (ASC) is $risingSign.

Rules:
- Avoid disclaimers, clichés, or "astrology is just a guide" type phrases.
- Write short, direct, clear sentences. Avoid literary flourishes.
- Write as a real astrologer would, humanized.

Explain how this rising sign reflects in the person's outer appearance, first impression, outlook on life, and physical energy in 2 paragraphs (approx. 100-150 words) in English. Output plain text only, no JSON.
""";

    try {
      final response = await _callGemini(prompt, isJson: false);
      return response;
    } catch (e) {
      debugPrint('⚠️ Rising Sign Interpretation Hatası: $e');
      return null;
    }
  }

  Future<String?> generateHouseInterpretation({
    required String houseNumber,
    required String sign,
    required String languageCode,
  }) async {
    final isTr = languageCode == 'tr';

    final houseMeaningsTr = {
      '1': 'Kimlik, beden ve ilk izlenim',
      '2': 'Para, değerler ve sahiplik',
      '3': 'İletişim, kardeşler ve kısa yolculuklar',
      '4': 'Ev, aile ve kökenler',
      '5': 'Yaratıcılık, aşk ve eğlence',
      '6': 'Sağlık, iş düzeni ve günlük rutinler',
      '7': 'Ortaklıklar, evlilik ve ilişkiler',
      '8': 'Dönüşüm, miras ve derin bağlar',
      '9': 'Felsefe, yüksek eğitim ve uzun yolculuklar',
      '10': 'Kariyer, itibar ve hedefler',
      '11': 'Arkadaşlar, topluluk ve idealizmler',
      '12': 'Bilinçdışı, gizli düşmanlar ve spiritüellik',
    };

    final houseMeaningsEn = {
      '1': 'Identity, body and first impressions',
      '2': 'Money, values and possessions',
      '3': 'Communication, siblings and short trips',
      '4': 'Home, family and roots',
      '5': 'Creativity, romance and pleasure',
      '6': 'Health, work routine and daily habits',
      '7': 'Partnerships, marriage and relationships',
      '8': 'Transformation, inheritance and deep bonds',
      '9': 'Philosophy, higher education and long journeys',
      '10': 'Career, reputation and ambitions',
      '11': 'Friends, community and ideals',
      '12': 'Subconscious, hidden enemies and spirituality',
    };

    final meaning = isTr
        ? (houseMeaningsTr[houseNumber] ?? '$houseNumber. Ev')
        : (houseMeaningsEn[houseNumber] ?? 'House $houseNumber');

    final prompt = isTr
        ? """
Sen usta bir astrologsun. Kullanıcının $houseNumber. evinde $sign burcu bulunuyor.
Bu evin anlamı: $meaning.

Kurallar:
- Sorumluluk reddi, klişe uyarılar veya edebi betimlemelerden kaçın.
- Kısa, net, doğrudan cümleler kur.
- İnsan eliyle yazılmış, gerçek bir astrolog gibi yaz.

Bu ev-burç kombinasyonunun kişinin hayatına pratik etkisini 2 paragrafta (yaklaşık 80-120 kelime) Türkçe olarak yaz. Sadece düz metin ver, JSON kullanma.
"""
        : """
You are a skilled astrologer. The user's $houseNumber. house has $sign as its sign.
This house governs: $meaning.

Rules:
- Avoid disclaimers, clichés, or literary descriptions.
- Write short, direct, clear sentences.
- Write as a real astrologer would, humanized.

Explain the practical impact of this house-sign combination on the person's life in 2 paragraphs (approx. 80-120 words) in English. Output plain text only, no JSON.
""";

    try {
      final response = await _callGemini(prompt, isJson: false);
      return response;
    } catch (e) {
      debugPrint('⚠️ House Interpretation Hatası: $e');
      return null;
    }
  }

  /// Genel amaçlı Gemini API çağrısı
  Future<String?> callGemini(String prompt, {bool isJson = true}) => _callGemini(prompt, isJson: isJson);

  // Gemini Model API Çağrısı
  // Gemini Model API Çağrısı
  Future<String?> _callGemini(String prompt, {bool isJson = true}) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('❌ Gemini API Anahtarı bulunamadı (.env dosyası veya çevre değişkenleri eksik).');
      return null;
    }

    // 1. Son 60 saniyeden eski istek zaman damgalarını temizle
    final now = DateTime.now();
    _requestTimestamps.removeWhere((t) => now.difference(t).inSeconds > 60);

    // 2. Eğer son 60 saniyede 12 istek atıldıysa, en eskisinin süresi dolana kadar bekle (12 RPM limitini aşmamak için)
    if (_requestTimestamps.length >= 12) {
      final oldestRequest = _requestTimestamps.first;
      final waitDuration = const Duration(seconds: 60) - now.difference(oldestRequest);
      
      if (waitDuration.inMilliseconds > 0) {
        debugPrint('⏳ Gemini API Hız Sınırına (12 RPM) Ulaşıldı. ${waitDuration.inSeconds} saniye bekleniyor...');
        await Future.delayed(waitDuration);
      }
      return _callGemini(prompt, isJson: isJson);
    }

    _requestTimestamps.add(DateTime.now());

    // 6 adet model sırayla meşguliyet veya kota aşımına karşı denenecektir.
    final candidateModels = [
      'gemini-3.1-flash-lite',
      'gemini-2.5-flash-lite',
      'gemini-3-flash',
      'gemini-2.5-flash',
      'gemini-3.5-flash',
      'gemini-3.1-pro',
    ];

    for (final model in candidateModels) {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey",
      );

      final Map<String, dynamic> requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      };
      if (isJson) {
        requestBody["generationConfig"] = {
          "responseMimeType": "application/json"
        };
      }

      int retryCount = 0;
      String? successfulText;
      bool modelFailed = false;

      while (retryCount < 2) {
        try {
          debugPrint('🔮 Gemini API Çağrısı: Model: $model, Deneme: ${retryCount + 1}');
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final Map<String, dynamic> resBody = jsonDecode(response.body);
            
            final candidates = resBody['candidates'] as List?;
            if (candidates == null || candidates.isEmpty) {
              debugPrint('⚠️ Gemini API ($model): Aday listesi boş.');
              if (prompt.contains('Kozmik Kâhin') || prompt.contains('Kozmik Kahin')) {
                return '{"answer_tr": "Kozmik Kâhin bu soruyu yanıtlamaktan çekiniyor. Lütfen göksel rehberliğe uygun, yapıcı başka bir soru sorun.", "answer_en": "The Cosmic Oracle is hesitant to answer this question. Please ask another constructive question suitable for celestial guidance."}';
              }
              modelFailed = true;
              break;
            }

            final candidate = candidates[0] as Map<String, dynamic>;
            final finishReason = candidate['finishReason'];
            if (finishReason != null && finishReason != 'STOP') {
              debugPrint('⚠️ Gemini API ($model): İşlem durduruldu (Gerekçe: $finishReason).');
              if (prompt.contains('Kozmik Kâhin') || prompt.contains('Kozmik Kahin')) {
                return '{"answer_tr": "Kozmik Kâhin bu soruyu yanıtlamaktan çekiniyor. Lütfen göksel rehberliğe uygun, yapıcı başka bir soru sorun.", "answer_en": "The Cosmic Oracle is hesitant to answer this question. Please ask another constructive question suitable for celestial guidance."}';
              }
              modelFailed = true;
              break;
            }

            final content = candidate['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts == null || parts.isEmpty) {
              modelFailed = true;
              break;
            }

            final String text = parts[0]['text'] ?? '';
            successfulText = text.trim();
            break;
          } else {
            debugPrint('⚠️ Gemini API HTTP Hatası ($model, Deneme ${retryCount + 1}): ${response.statusCode} - ${response.body}');
            if (response.statusCode == 429 || response.statusCode == 403) {
              modelFailed = true;
              break;
            } else if (response.statusCode >= 500) {
              retryCount++;
              if (retryCount < 2) {
                await Future.delayed(const Duration(milliseconds: 1500));
                continue;
              }
            }
            modelFailed = true;
            break;
          }
        } catch (e) {
          if (e is TimeoutException) {
            debugPrint('⚠️ Gemini API Zaman Aşımı ($model): $e');
            modelFailed = true;
            break;
          }
          debugPrint('⚠️ Gemini Bağlantı Hatası ($model, Deneme ${retryCount + 1}): $e');
          retryCount++;
          if (retryCount < 2) {
            await Future.delayed(const Duration(milliseconds: 1500));
          } else {
            modelFailed = true;
          }
        }
      }

      if (successfulText != null) {
        return successfulText;
      }

      if (modelFailed) {
        debugPrint('⚠️ $model başarısız oldu veya meşgul. Sonraki modele geçiliyor...');
      }
    }

    return null;
  }

  // JSON Çıktısını Temizleme ve Arındırma (LLM Format Hatalarını Engellemek İçin)
  String _sanitizeJson(String rawJson) {
    var cleaned = rawJson.trim();
    
    // Markdown kod bloğu temizliği (e.g. ```json ... ```)
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith('```')) {
        lines.removeLast();
      }
      cleaned = lines.join('\n').trim();
    }
    
    // JSON başlangıç ve bitişini tespit et ({ ... })
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }
    
    return cleaned;
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
    debugPrint('🔮 Fallback Başladı - zodiac: $zodiac, gender: $gender');
    try {
      final String mappedZodiac = _mapToEnglishZodiac(zodiac);
      debugPrint('🔮 Mapped zodiac: $mappedZodiac');
      final jsonStr = await rootBundle.loadString('assets/data/demo_comments.json');
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final zodiacData = data[mappedZodiac.toLowerCase()];
      debugPrint('🔮 Zodiac data found: ${zodiacData != null}');
      if (zodiacData != null) {
        final genderData = zodiacData[gender.toLowerCase()] as List<dynamic>?;
        debugPrint('🔮 Gender data found for ${gender.toLowerCase()}: ${genderData != null}');
        if (genderData != null && genderData.isNotEmpty) {
          final day = DateTime.now().day;
          final index = day % genderData.length;
          debugPrint('🔮 Day: $day, Index: $index');
          final item = genderData[index] as Map<String, dynamic>;
          debugPrint('🔮 Loaded item: $item');
          
          final originalTr = item['comment_tr'] ?? '';
          final originalEn = item['comment_en'] ?? '';
          
          final extendedTr = _extendCommentTo10Lines(originalTr, mappedZodiac, gender, 'tr');
          final extendedEn = _extendCommentTo10Lines(originalEn, mappedZodiac, gender, 'en');

          return DailyCommentModel(
            commentTr: extendedTr,
            commentEn: extendedEn,
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
      final userDoc = await _firestore.doc('users/$userId').safeGet();
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
    try {
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
      final doc = await docRef.safeGet();
      
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
    } catch (e) {
      debugPrint('⚠️ checkCosmicOracleLimit hatası: $e');
      return {
        'allowed': true, // Ağ hatasında bloklamamak için varsayılan olarak izin ver
        'questionsAsked': 0,
        'rewardedWatched': false,
        'needAd': false,
      };
    }
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
    try {
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
      final doc = await docRef.safeGet();

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
    } catch (e) {
      debugPrint('⚠️ checkAiToolsDailyLimit hatası: $e');
      return {
        'allowed': true, // Ağ hatasında bloklamamak için varsayılan olarak izin ver
        'count': 0,
        'allowedExtra': 0,
        'needAd': false,
      };
    }
  }

  // AI Araçları hesaplama sayısını artırır
  Future<void> incrementAiToolsCalculationCount(String userId) async {
    final docRef = _firestore.doc('users/$userId/daily_usage/ai_tools');
    final doc = await docRef.safeGet();

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
    final doc = await docRef.safeGet();

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

  String _extendCommentTo10Lines(String original, String zodiac, String gender, String lang) {
    final isTr = lang == 'tr';
    final zodiacName = isTr ? _mapToTurkishZodiacName(zodiac) : zodiac;

    if (isTr) {
      return "$original\n\n"
          "Gökyüzündeki mevcut gezegen konumları ve özellikle yönetici yıldızınızın açıları, $zodiacName burcu olarak bugün içsel dengenizi kurmanız adına sizi destekliyor. "
          "Zihinsel enerjiniz oldukça yüksek görünmekle birlikte, karar alırken acele etmemeniz ve detayları gözden kaçırmamanız kritik önem taşıyor. "
          "Aşk ve ilişkiler hanenizde parlayan kozmik etkiler, sevdiklerinizle olan bağlarınızı güçlendirmek ve varsa aradaki pürüzleri gidermek için mükemmel fırsatlar sunuyor. "
          "İş ve kariyer hayatınızda ise sabırlı, planlı ve kararlı adımlar atarak uzun vadeli hedeflerinize odaklanmalısınız. "
          "Finansal konularda ise gereksiz harcamalardan uzak durarak güvenli limanlarda kalmaya özen göstermeniz yararınıza olacaktır. "
          "Unutmayın ki yıldızlar sadece yolları aydınlatır, adımı atacak olan sizsiniz. "
          "Günün kozmik mottosu: Kendine güven, akışın bilgeliğine inan ve evrenin sunduğu fırsatları sevgiyle kucakla.";
    } else {
      return "$original\n\n"
          "The current planetary positions in the sky, especially the aspects of your ruling planet, support you as a $zodiacName today to establish your inner balance. "
          "Although your mental energy seems quite high, it is critical not to rush when making decisions and not to lose sight of details. "
          "Cosmic influences shining in your love and relationship sectors offer excellent opportunities to strengthen ties and smooth over any friction. "
          "In your career and professional life, you should focus on long-term goals by taking patient, planned, and determined steps. "
          "Regarding financial matters, it will be to your benefit to avoid unnecessary expenses and stay in safe harbors. "
          "Remember that the stars only light the way; you are the one who takes the step. "
          "Today's cosmic motto: Trust yourself, believe in the wisdom of the flow, and embrace the opportunities with love.";
    }
  }

  String _mapToTurkishZodiacName(String zodiac) {
    final Map<String, String> enToTr = {
      'aries': 'Koç',
      'taurus': 'Boğa',
      'gemini': 'İkizler',
      'cancer': 'Yengeç',
      'leo': 'Aslan',
      'virgo': 'Başak',
      'libra': 'Terazi',
      'scorpio': 'Akrep',
      'sagittarius': 'Yay',
      'capricorn': 'Oğlak',
      'aquarius': 'Kova',
      'pisces': 'Balık',
    };
    return enToTr[zodiac.toLowerCase().trim()] ?? zodiac;
  }
}
