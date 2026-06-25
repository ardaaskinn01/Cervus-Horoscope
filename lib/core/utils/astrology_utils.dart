class DstPeriod {
  final DateTime start;
  final DateTime end;
  final int offset;

  const DstPeriod(this.start, this.end, this.offset);
}

class AstrologyUtils {
  AstrologyUtils._();

  // Türkiye Resmi Yaz Saati / Saat Dilimi Tarihçe Veritabanı
  static final List<DstPeriod> _dstPeriods = [
    // 15.07.1962 00:00 - 30.10.1963 00:00 (+3)
    DstPeriod(DateTime(1962, 7, 15, 0, 0), DateTime(1963, 10, 30, 0, 0), 3),
    // 15.05.1964 00:00 - 01.10.1964 00:00 (+3)
    DstPeriod(DateTime(1964, 5, 15, 0, 0), DateTime(1964, 10, 1, 0, 0), 3),
    // 03.06.1973 01:00 - 04.11.1973 02:00 (+3)
    DstPeriod(DateTime(1973, 6, 3, 1, 0), DateTime(1973, 11, 4, 2, 0), 3),
    // 22.03.1974 02:00 - 03.11.1974 02:00 (+3)
    DstPeriod(DateTime(1974, 3, 22, 2, 0), DateTime(1974, 11, 3, 2, 0), 3),
    // 22.03.1975 02:00 - 02.11.1975 02:00 (+3)
    DstPeriod(DateTime(1975, 3, 22, 2, 0), DateTime(1975, 11, 2, 2, 0), 3),
    // 21.03.1976 02:00 - 31.10.1976 02:00 (+3)
    DstPeriod(DateTime(1976, 3, 21, 2, 0), DateTime(1976, 10, 31, 2, 0), 3),
    // 03.04.1977 02:00 - 16.10.1977 02:00 (+3)
    DstPeriod(DateTime(1977, 4, 3, 2, 0), DateTime(1977, 10, 16, 2, 0), 3),
    // 02.04.1978 02:00 - 31.07.1983 02:00 (Sürekli +3)
    DstPeriod(DateTime(1978, 4, 2, 2, 0), DateTime(1983, 7, 31, 2, 0), 3),
    // 31.07.1983 02:00 - 02.10.1983 02:00 (+4 Çift Yaz Saati)
    DstPeriod(DateTime(1983, 7, 31, 2, 0), DateTime(1983, 10, 2, 2, 0), 4),
    // 02.10.1983 02:00 - 01.11.1984 02:00 (Sürekli +3)
    DstPeriod(DateTime(1983, 10, 2, 2, 0), DateTime(1984, 11, 1, 2, 0), 3),
    // 1985
    DstPeriod(DateTime(1985, 4, 20, 1, 0), DateTime(1985, 9, 28, 2, 0), 3),
    // 1986
    DstPeriod(DateTime(1986, 3, 30, 1, 0), DateTime(1986, 9, 28, 2, 0), 3),
    // 1987
    DstPeriod(DateTime(1987, 3, 29, 1, 0), DateTime(1987, 9, 27, 2, 0), 3),
    // 1988
    DstPeriod(DateTime(1988, 3, 27, 1, 0), DateTime(1988, 9, 25, 2, 0), 3),
    // 1989
    DstPeriod(DateTime(1989, 3, 26, 1, 0), DateTime(1989, 9, 24, 2, 0), 3),
    // 1990
    DstPeriod(DateTime(1990, 3, 25, 1, 0), DateTime(1990, 9, 30, 2, 0), 3),
    // 1991
    DstPeriod(DateTime(1991, 3, 31, 1, 0), DateTime(1991, 9, 29, 2, 0), 3),
    // 1992
    DstPeriod(DateTime(1992, 3, 29, 1, 0), DateTime(1992, 9, 27, 2, 0), 3),
    // 1993
    DstPeriod(DateTime(1993, 3, 28, 1, 0), DateTime(1993, 9, 26, 2, 0), 3),
    // 1994
    DstPeriod(DateTime(1994, 3, 20, 1, 0), DateTime(1994, 9, 25, 2, 0), 3),
    // 1995
    DstPeriod(DateTime(1995, 3, 26, 1, 0), DateTime(1995, 9, 24, 2, 0), 3),
    // 1996
    DstPeriod(DateTime(1996, 3, 31, 1, 0), DateTime(1996, 10, 27, 2, 0), 3),
    // 1997
    DstPeriod(DateTime(1997, 3, 30, 1, 0), DateTime(1997, 10, 26, 2, 0), 3),
    // 1998
    DstPeriod(DateTime(1998, 3, 29, 1, 0), DateTime(1998, 10, 25, 2, 0), 3),
    // 1999
    DstPeriod(DateTime(1999, 3, 28, 1, 0), DateTime(1999, 10, 31, 2, 0), 3),
    // 2000
    DstPeriod(DateTime(2000, 3, 26, 1, 0), DateTime(2000, 10, 29, 2, 0), 3),
    // 2001
    DstPeriod(DateTime(2001, 3, 25, 1, 0), DateTime(2001, 10, 28, 2, 0), 3),
    // 2002
    DstPeriod(DateTime(2002, 3, 31, 1, 0), DateTime(2002, 10, 27, 2, 0), 3),
    // 2003
    DstPeriod(DateTime(2003, 3, 30, 1, 0), DateTime(2003, 10, 26, 2, 0), 3),
    // 2004
    DstPeriod(DateTime(2004, 3, 28, 1, 0), DateTime(2004, 10, 31, 2, 0), 3),
    // 2005
    DstPeriod(DateTime(2005, 3, 27, 1, 0), DateTime(2005, 10, 30, 2, 0), 3),
    // 2006
    DstPeriod(DateTime(2006, 3, 26, 1, 0), DateTime(2006, 10, 29, 2, 0), 3),
    // 2007
    DstPeriod(DateTime(2007, 3, 25, 3, 0), DateTime(2007, 10, 28, 4, 0), 3),
    // 2008
    DstPeriod(DateTime(2008, 3, 30, 3, 0), DateTime(2008, 10, 26, 4, 0), 3),
    // 2009
    DstPeriod(DateTime(2009, 3, 29, 3, 0), DateTime(2009, 10, 25, 4, 0), 3),
    // 2010
    DstPeriod(DateTime(2010, 3, 28, 3, 0), DateTime(2010, 10, 31, 4, 0), 3),
    // 2011
    DstPeriod(DateTime(2011, 3, 28, 3, 0), DateTime(2011, 10, 30, 4, 0), 3),
    // 2012
    DstPeriod(DateTime(2012, 3, 25, 3, 0), DateTime(2012, 10, 28, 4, 0), 3),
    // 2013
    DstPeriod(DateTime(2013, 3, 31, 3, 0), DateTime(2013, 10, 27, 4, 0), 3),
    // 2014
    DstPeriod(DateTime(2014, 3, 31, 3, 0), DateTime(2014, 10, 26, 4, 0), 3),
    // 2015
    DstPeriod(DateTime(2015, 3, 29, 3, 0), DateTime(2015, 11, 8, 4, 0), 3),
    // 2016-03-27'den İtibaren KALICI (+3)
    DstPeriod(DateTime(2016, 3, 27, 3, 0), DateTime(2100, 1, 1, 0, 0), 3),
  ];

  /// Belirtilen yerel doğum tarihi ve saati için Türkiye saat farkını (+2, +3 veya +4) döndürür.
  static int getTurkeyOffsetInHours(DateTime localTime) {
    for (final period in _dstPeriods) {
      if (localTime.isAfter(period.start) && localTime.isBefore(period.end)) {
        return period.offset;
      }
      // Sınırlardaki eşitlikleri de kapsayalım
      if (localTime.isAtSameMomentAs(period.start) || localTime.isAtSameMomentAs(period.end)) {
        return period.offset;
      }
    }
    // Herhangi bir yaz saati aralığına girmiyorsa default UTC+2
    return 2;
  }

  /// Yerel doğum tarihi ve saatini saat dilimi düzeltmesiyle tam UTC zamanına çevirir.
  static DateTime getUtcBirthDate(DateTime birthDate, String birthTime) {
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

    final offset = getTurkeyOffsetInHours(localDateTime);
    return localDateTime.subtract(Duration(hours: offset));
  }

  /// Gün ve ay bilgisine göre güneş burcunu döndürür.
  static String calculateZodiacSign(int day, int month) {
    switch (month) {
      case 1:
        return day >= 20 ? 'aquarius' : 'capricorn';
      case 2:
        return day >= 19 ? 'pisces' : 'aquarius';
      case 3:
        return day >= 21 ? 'aries' : 'pisces';
      case 4:
        return day >= 20 ? 'taurus' : 'aries';
      case 5:
        return day >= 21 ? 'gemini' : 'taurus';
      case 6:
        return day >= 21 ? 'cancer' : 'gemini';
      case 7:
        return day >= 23 ? 'leo' : 'cancer';
      case 8:
        return day >= 23 ? 'virgo' : 'leo';
      case 9:
        return day >= 23 ? 'libra' : 'virgo';
      case 10:
        return day >= 23 ? 'scorpio' : 'libra';
      case 11:
        return day >= 22 ? 'sagittarius' : 'scorpio';
      case 12:
        return day >= 22 ? 'capricorn' : 'sagittarius';
      default:
        return 'aries';
    }
  }

  /// UTC doğum zamanını Türkiye yerel tarih/saat dilimine dönüştürür.
  static DateTime convertUtcToTurkeyLocal(DateTime utcDateTime) {
    final localEstimated = utcDateTime.add(const Duration(hours: 3));
    final offset = getTurkeyOffsetInHours(localEstimated);
    return utcDateTime.add(Duration(hours: offset));
  }

  /// Calculate Element and Modality counts from planet signs.
  static Map<String, Map<String, int>> calculateElementsAndModalities(Map<String, dynamic> planetDetails) {
    final elements = {'Fire': 0, 'Earth': 0, 'Air': 0, 'Water': 0};
    final modalities = {'Cardinal': 0, 'Fixed': 0, 'Mutable': 0};

    for (final planetData in planetDetails.values) {
      final sign = (planetData['sign']?.toString() ?? '').toLowerCase();
      
      if (['koç', 'aries', 'aslan', 'leo', 'yay', 'sagittarius'].contains(sign)) {
        elements['Fire'] = (elements['Fire'] ?? 0) + 1;
      } else if (['boğa', 'taurus', 'başak', 'virgo', 'oğlak', 'capricorn'].contains(sign)) {
        elements['Earth'] = (elements['Earth'] ?? 0) + 1;
      } else if (['ikizler', 'gemini', 'terazi', 'libra', 'kova', 'aquarius'].contains(sign)) {
        elements['Air'] = (elements['Air'] ?? 0) + 1;
      } else if (['yengeç', 'cancer', 'akrep', 'scorpio', 'balık', 'pisces'].contains(sign)) {
        elements['Water'] = (elements['Water'] ?? 0) + 1;
      }

      if (['koç', 'aries', 'yengeç', 'cancer', 'terazi', 'libra', 'oğlak', 'capricorn'].contains(sign)) {
        modalities['Cardinal'] = (modalities['Cardinal'] ?? 0) + 1;
      } else if (['boğa', 'taurus', 'aslan', 'leo', 'akrep', 'scorpio', 'kova', 'aquarius'].contains(sign)) {
        modalities['Fixed'] = (modalities['Fixed'] ?? 0) + 1;
      } else if (['ikizler', 'gemini', 'başak', 'virgo', 'yay', 'sagittarius', 'balık', 'pisces'].contains(sign)) {
        modalities['Mutable'] = (modalities['Mutable'] ?? 0) + 1;
      }
    }

    return {
      'elements': elements,
      'modalities': modalities,
    };
  }

  /// Calculate major planetary aspects based on planet angles.
  static Map<String, dynamic> calculateAspects(Map<String, double> planetAngles) {
    final List<Map<String, dynamic>> aspectList = [];
    final List<String> planets = [
      'Güneş', 'Ay', 'Merkür', 'Venüs', 'Mars', 'Jüpiter', 'Satürn', 'Uranüs', 'Neptün', 'Plüton'
    ];

    final Map<int, String> aspectNames = {
      0: 'Kavuşum (Conjunction)',
      60: 'Sekstil (Sextile)',
      90: 'Kare (Square)',
      120: 'Üçgen (Trine)',
      180: 'Karşıt (Opposition)',
    };

    final Map<int, double> aspectOrbs = {
      0: 8.0,
      60: 4.0,
      90: 8.0,
      120: 8.0,
      180: 8.0,
    };

    final Map<int, bool> aspectHardness = {
      0: false, // Conjunction is neutral/variable but let's call it soft for drawing, or we can handle it later
      60: false,
      90: true,
      120: false,
      180: true,
    };

    for (int i = 0; i < planets.length; i++) {
      for (int j = i + 1; j < planets.length; j++) {
        final p1 = planets[i];
        final p2 = planets[j];
        final angle1 = planetAngles[p1];
        final angle2 = planetAngles[p2];

        if (angle1 == null || angle2 == null) continue;

        double diff = (angle1 - angle2).abs();
        if (diff > 180) {
          diff = 360 - diff;
        }

        for (final aspect in aspectNames.keys) {
          final target = aspect.toDouble();
          final orb = aspectOrbs[aspect]!;
          if ((diff - target).abs() <= orb) {
            aspectList.add({
              'planet1': p1,
              'planet2': p2,
              'aspect': aspectNames[aspect],
              'angle': aspect,
              'orb': (diff - target).abs(),
              'isHard': aspectHardness[aspect],
            });
            break;
          }
        }
      }
    }

    // Sort by tightest orb
    aspectList.sort((a, b) => (a['orb'] as double).compareTo(b['orb'] as double));

    return {'list': aspectList};
  }

  /// İki natal chart arasındaki sinastri (interaspect) açılarını hesaplar.
  /// [chart1Angles]: Kişi 1'in gezegen açıları (Swiss Ephemeris'ten gelen 0–360° boylam değerleri)
  /// [chart2Angles]: Kişi 2'nin gezegen açıları
  /// Sadece astrolojik olarak anlamlı gezegen çiftleri karşılaştırılır.
  static List<Map<String, dynamic>> calculateSynastriAspects(
    Map<String, double> chart1Angles,
    Map<String, double> chart2Angles,
  ) {
    final List<Map<String, dynamic>> aspectList = [];

    // Sinastride en anlamlı aspekt açıları ve tolerans (orb) değerleri
    final Map<int, String> aspectNames = {
      0: 'Kavuşum (Conjunction)',
      60: 'Sekstil (Sextile)',
      90: 'Kare (Square)',
      120: 'Üçgen (Trine)',
      180: 'Karşıt (Opposition)',
    };

    final Map<int, double> aspectOrbs = {
      0: 8.0,
      60: 4.0,
      90: 8.0,
      120: 8.0,
      180: 8.0,
    };

    final Map<int, bool> aspectHardness = {
      0: false,
      60: false,
      90: true,
      120: false,
      180: true,
    };

    // Sinastride önemli olan gezegen çiftleri (kişi1 gezegeni → kişi2 gezegeni)
    // Bu liste aşk uyumunda en kritik karşılaştırmaları kapsar.
    final List<List<String>> importantPairs = [
      ['Venüs', 'Mars'],
      ['Mars', 'Venüs'],
      ['Güneş', 'Ay'],
      ['Ay', 'Güneş'],
      ['Ay', 'Ay'],
      ['Güneş', 'Güneş'],
      ['Venüs', 'Venüs'],
      ['Mars', 'Mars'],
      ['Merkür', 'Merkür'],
      ['Güneş', 'Venüs'],
      ['Venüs', 'Güneş'],
      ['Ay', 'Venüs'],
      ['Venüs', 'Ay'],
      ['Güneş', 'Mars'],
      ['Mars', 'Güneş'],
      ['Jüpiter', 'Venüs'],
      ['Jüpiter', 'Güneş'],
      ['Satürn', 'Güneş'],
      ['Satürn', 'Ay'],
      ['Yükselen', 'Güneş'],
      ['Yükselen', 'Ay'],
      ['Yükselen', 'Venüs'],
      ['Merkür', 'Ay'],
      ['Ay', 'Merkür'],
      ['Merkür', 'Güneş'],
      ['Güneş', 'Merkür'],
      ['Merkür', 'Venüs'],
      ['Venüs', 'Merkür'],
    ];

    for (final pair in importantPairs) {
      final p1 = pair[0]; // Kişi 1'in gezegeni
      final p2 = pair[1]; // Kişi 2'nin gezegeni

      final angle1 = chart1Angles[p1];
      final angle2 = chart2Angles[p2];

      if (angle1 == null || angle2 == null) continue;

      double diff = (angle1 - angle2).abs();
      if (diff > 180) diff = 360 - diff;

      for (final aspectDeg in aspectNames.keys) {
        final orb = aspectOrbs[aspectDeg]!;
        final actualDiff = (diff - aspectDeg).abs();
        if (actualDiff <= orb) {
          aspectList.add({
            'planet1': p1,        // Kişi 1'in gezegeni
            'planet2': p2,        // Kişi 2'nin gezegeni
            'aspect': aspectNames[aspectDeg],
            'angle': aspectDeg,
            'orb': actualDiff,
            'isHard': aspectHardness[aspectDeg],
          });
          break; // Bir gezegen çifti için sadece en yakın aspekti al
        }
      }
    }

    // Orb'a göre sırala (en sıkı açı önce)
    aspectList.sort((a, b) => (a['orb'] as double).compareTo(b['orb'] as double));

    return aspectList;
  }
}
