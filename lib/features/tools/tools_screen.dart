import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/navigation_provider.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    // Araçlar Listesi
    final List<Map<String, dynamic>> tools = [
      {
        'icon': '🌙',
        'titleTr': 'Ay Fazları Takvimi',
        'titleEn': 'Moon Phases Calendar',
        'descTr': '2026 yılı dolunay, yeniay ve günlük ay fazı değişimleri.',
        'descEn': '2026 full moons, new moons, and daily lunar phase shifts.',
        'route': '/moon-phases'
      },
      {
        'icon': '📅',
        'titleTr': 'Astroloji Takvimi',
        'titleEn': 'Astro Calendar',
        'descTr': '2026 gökyüzü olayları, tutulmalar ve günlük olumlu/dikkatli transitle.',
        'descEn': '2026 celestial events, eclipses, and daily cosmic transits.',
        'route': '/astro-calendar'
      },
      {
        'icon': '☿',
        'titleTr': 'Geri Giden Gezegenler',
        'titleEn': 'Retrograde Periods',
        'descTr': '2026 yılı Merkür, Venüs ve Mars retro tarihleri ve etkileri.',
        'descEn': '2026 Mercury, Venus, and Mars retro dates and areas of impact.',
        'route': '/retrograde'
      },
      {
        'icon': '🔢',
        'titleTr': 'Kişisel Numeroloji',
        'titleEn': 'Personal Numerology',
        'descTr': 'Kendi doğum tarihi ve isminize göre kozmik numeroloji analiziniz.',
        'descEn': 'Your cosmic numerology analysis based on your birth date and name.',
        'route': '/numerology'
      },
      {
        'icon': '🔮',
        'titleTr': 'Doğum Tarihi Numerolojisi',
        'titleEn': 'Birth Date Numerology',
        'descTr': 'Başka birinin doğum tarihine göre yaşam yolu ve kişisel yıl analizini yapın.',
        'descEn': 'Analyze life path and personal year numbers for someone else.',
        'route': '/partner-numerology'
      },
      {
        'icon': '💑',
        'titleTr': 'Aşk Uyumu',
        'titleEn': 'Love Compatibility',
        'descTr': 'İki kişinin doğum bilgilerine göre aşk ve sinastri uyumu.',
        'descEn': 'Love and synastry match analysis based on birth details.',
        'route': '/love-compatibility'
      },
      {
        'icon': '🤝',
        'titleTr': 'Arkadaşlık Uyumu',
        'titleEn': 'Friendship Match',
        'descTr': 'Burç haritası rezonansına göre arkadaşlık uyumu.',
        'descEn': 'Social compatibility based on zodiac chart resonance.',
        'route': '/friend-compatibility'
      },
      {
        'icon': '🗺️',
        'titleTr': 'Astro Portre',
        'titleEn': 'Astro Portrait',
        'descTr': 'Güneş, Ay, Yükselen konumları ve detaylı gezegen ev dağılımları.',
        'descEn': 'Sun, Moon, Rising positions, and planet house distributions.',
        'route': 1 // Tab değiştir
      },
      {
        'icon': '🌌',
        'titleTr': 'Başkasının Astro Portresi',
        'titleEn': 'Partner\'s Astro Portrait',
        'descTr': 'Arkadaşınızın veya partnerinizin doğum bilgilerine göre astro portresini çıkartın.',
        'descEn': 'Generate and view the astronomical astro portrait for a friend or partner.',
        'route': '/partner-natal-chart'
      },
      {
        'icon': '👁️',
        'titleTr': 'Kozmik Kâhin',
        'titleEn': 'Cosmic Oracle',
        'descTr': 'Yapay zeka tabanlı astroloji kâhinine günde 1 soru sorun.',
        'descEn': 'Ask the AI-powered astrology oracle 1 question per day.',
        'route': '/cosmic-oracle'
      }
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 3 : 2;
    final double childAspectRatio = screenWidth > 600 ? 0.95 : 0.82;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isTr ? 'Astroloji Araçları' : 'Astrology Tools'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 16.0),
              itemCount: tools.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final tool = tools[index];
                final String title = isTr ? tool['titleTr'] : tool['titleEn'];
                final String desc = isTr ? tool['descTr'] : tool['descEn'];

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final route = tool['route'];
                    if (route is int) {
                      ref.read(bottomNavIndexProvider.notifier).state = route;
                    } else if (route is String) {
                      context.push(route);
                    }
                  },
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // İkon rozeti
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            tool['icon'],
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const Spacer(),
                        // Başlık
                        Text(
                          title,
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Açıklama
                        Text(
                          desc,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                            height: 1.4,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fade(delay: (index * 80).ms, duration: 350.ms)
                    .slideY(begin: 0.1, delay: (index * 80).ms, duration: 350.ms);
              },
            ),
          ),
          const SizedBox(height: 160),
        ],
      ),
    );
  }
}
