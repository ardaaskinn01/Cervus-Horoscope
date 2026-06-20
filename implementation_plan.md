# Gelişmiş Aşk Uyumu (Horoscope Pro) ve Yapay Zeka Yorum İyileştirmesi

Bu plan; aşk uyumu analizinin yapay zeka tarafından (Gemini) yorumlanma mantığındaki astrolojik hataları gidermeyi ve **Horoscope Pro** üyeleri (ve yerel test sürecinde geliştiriciler) için aşk uyumu ekranına yepyeni, çok detaylı premium analiz bölümleri kazandırmayı hedefler.

## User Review Required

> [!IMPORTANT]
> **Yapay Zeka Mantık Düzeltmesi (Astrolojik Ağırlık):**
> Kullanıcıdan alınan geri bildirime göre, element tabanlı genel sayım (örn. hava/toprak çoğunluğu), su grubundaki (özellikle Yengeç, Akrep, Balık) **Güneş, Ay, Venüs ve Mars** gibi kişisel gezegenlerin baskın duygusal doğasını gölgelemekteydi.
> Gemini promptuna eklenecek yeni kurallar ile **kişisel gezegenlerin (Güneş, Ay, Venüs, Mars) burçlarının, elementlerin genel sayısal oranlarından daha yüksek ağırlığa sahip olduğu** açıkça belirtilecektir. Böylece Güneş ve Mars'ı Yengeç olan bir partner "duygusal olarak mesafeli" olarak nitelendirilmeyecektir.

> [!NOTE]
> **Test Süreci (Debug Mode):**
> Gelişmiş Horoscope Pro analizlerini market sürümüne kadar test edebilmeniz için, premium kartlar **`isPremium || kDebugMode`** durumunda tamamen açık olacaktır. Böylece yerel test cihazlarında premium satın alım yapmadan da yeni bölümleri test edebileceksiniz.

---

## Proposed Changes

### 1. Model Katmanı

#### [MODIFY] [compatibility_model.dart](file:///c:/Users/ardaa/StudioProjects/horoscope/lib/core/models/compatibility_model.dart)
Gelişmiş premium analizleri saklamak için model sınıfına yeni alanlar eklenir:
- `karmicBondsTr` / `karmicBondsEn` (Ruhsal ve Karmik Bağlar)
- `conflictResolutionTr` / `conflictResolutionEn` (Çatışma Çözüm Rehberi ve İletişim Tavsiyeleri)
- `growthTimelineTr` / `growthTimelineEn` (Kozmik Zaman Tüneli ve Gelişim Aşamaları)

---

### 2. Servis Katmanı (Gemini & Yapay Zeka)

#### [MODIFY] [ai_service.dart](file:///c:/Users/ardaa/StudioProjects/horoscope/lib/core/services/ai_service.dart)
- Gemini promptuna **Bütünsel Element ve Harita Sentezi** kuralı eklenir:
  - *"Sadece elementlerin sayısal oranlarına bakarak mekanik yorumlar yapma. Bir kişinin haritasında hava/toprak çoğunlukta olsa bile, eğer Güneş, Ay, Venüs veya Mars gibi kişisel gezegenleri Su gruplarında (Yengeç, Akrep, Balık) ise, bu kişi duygusal açıdan soğuk veya mesafeli değildir. Kişisel gezegenlerin (Güneş, Ay, Venüs, Mars) konumlarını, element genel dağılımının önüne koyarak duygusal yakınlık/mesafe sentezi yap."*
- Projeye Horoscope Pro için 3 yeni JSON alanı eklenir:
  - `karmicBonds`: `{ "tr": "...", "en": "..." }`
  - `conflictResolution`: `{ "tr": "...", "en": "..." }`
  - `growthTimeline`: `{ "tr": "...", "en": "..." }`

---

### 3. Arayüz Katmanı (UI)

#### [MODIFY] [love_compatibility_screen.dart](file:///c:/Users/ardaa/StudioProjects/horoscope/lib/features/love_compatibility/love_compatibility_screen.dart)
Aşk uyumu sonuç görünümü Horoscope Pro ve ücretsiz kullanıcılar için ayrıştırılır:
- **Ücretsiz Kullanıcı:** Mevcut skorlar ve analiz gösterilir. Analiz kartının hemen altında mistik, animasyonlu, yarı kilitli bir **"Horoscope Pro ile Derin Sinastri Analizini Keşfet"** kartı gösterilir. Bu karta tıklandığında Horoscope Pro satın alım popup'ı açılır.
- **Horoscope Pro Üyesi / Debug Modu:** Bu bölümler tamamen açılarak aşağıdaki 3 şık, altın işlemeli kozmik kart render edilir:
  1. **🔮 Ruh Eşi & Karmik Bağlar:** İki ruhun kozmik çekimi ve geçmiş yaşam kodları.
  2. **🛡️ İletişim & Çatışma Çözümü:** Sert açılara (kare/karşıt) karşı yapay zekanın sunduğu somut, doğrudan ilişki tavsiyeleri.
  3. **⏳ Gelecek Kozmik Zaman Tüneli:** Gelecek 1 yıldaki ilişki dönüm noktaları ve gelişim aşamaları.

---

## Verification Plan

### Automated Tests
- `flutter analyze` — Projede hiçbir lint veya derleme hatası olmamalıdır.

### Manual Verification
1. **Prompt Testi:** Kullanıcının belirttiği harita kombinasyonu (Yay Güneş, Balık Yükselen, Akrep Venüs, İkizler Ay, Kova Mars vs. Yengeç Güneş ve Yengeç Mars) girilerek analiz tetiklenir. Çıkan metinde Yengeç partnerin duygusal mesafeli olarak yorumlanmadığı, aksine derin duygusallığı ve ilgi arayışının doğru analiz edildiği doğrulanır.
2. **Debug Testi:** Yerel test ortamında premium satın alım yapılmamış olsa bile `kDebugMode` sayesinde Horoscope Pro kartlarının açıldığı ve başarıyla render edildiği gözlemlenir.
3. **Kilit Testi:** `kDebugMode` geçici olarak kapatıldığında ücretsiz kullanıcılara kilitli kartın gösterildiği ve tıklandığında satın alma popup'ının açıldığı doğrulanır.
