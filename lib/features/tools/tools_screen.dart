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

    // Araçlar Listesi (Dengeli açıklamalar - Karakter boyutu 40-55 arası)
    final List<Map<String, dynamic>> tools = [
      {
        'icon': '🌙',
        'titleTr': 'Ay Fazları Takvimi',
        'titleEn': 'Moon Phases Calendar',
        'descTr': '2026 yılı dolunay, yeniay ve günlük ay fazları.',
        'descEn': '2026 full moons, new moons, and daily lunar phases.',
        'route': '/moon-phases'
      },
      {
        'icon': '📅',
        'titleTr': 'Astroloji Takvimi',
        'titleEn': 'Astro Calendar',
        'descTr': '2026 gökyüzü olayları, tutulmalar ve günlük transitler.',
        'descEn': '2026 celestial events, eclipses, and daily transits.',
        'route': '/astro-calendar'
      },
      {
        'icon': '☿',
        'titleTr': 'Geri Giden Gezegenler',
        'titleEn': 'Retrograde Periods',
        'descTr': '2026 yılı Merkür, Venüs ve Mars retro takvimi.',
        'descEn': '2026 Mercury, Venus, and Mars retro periods.',
        'route': '/retrograde'
      },
      {
        'icon': '🔢',
        'titleTr': 'Kişisel Numeroloji',
        'titleEn': 'Personal Numerology',
        'descTr': 'Kişisel doğum tarihiniz ve isminize göre numeroloji.',
        'descEn': 'Personal numerology based on birth date and name.',
        'route': '/numerology'
      },
      {
        'icon': '🔮',
        'titleTr': 'Doğum Tarihi Numerolojisi',
        'titleEn': 'Birth Date Numerology',
        'descTr': 'Başkasının doğum tarihine göre numeroloji analizi.',
        'descEn': 'Analyze life path and personal years for someone else.',
        'route': '/partner-numerology'
      },
      {
        'icon': '💑',
        'titleTr': 'Aşk Uyumu',
        'titleEn': 'Love Compatibility',
        'descTr': 'İki kişinin doğum haritalarına göre aşk ve sinastri.',
        'descEn': 'Love and synastry match based on birth details.',
        'route': '/love-compatibility'
      },
      {
        'icon': '🤝',
        'titleTr': 'Arkadaşlık Uyumu',
        'titleEn': 'Friendship Match',
        'descTr': 'Harita rezonansına göre sosyal arkadaşlık uyumu.',
        'descEn': 'Social compatibility based on chart resonance.',
        'route': '/friend-compatibility'
      },
      {
        'icon': '🗺️',
        'titleTr': 'Astro Portre',
        'titleEn': 'Astro Portrait',
        'descTr': 'Güneş, Ay, Yükselen ve detaylı gezegen konumları.',
        'descEn': 'Sun, Moon, Rising, and planet distributions.',
        'route': 1 // Tab değiştir
      },
      {
        'icon': '🌌',
        'titleTr': 'Başkasının Astro Portresi',
        'titleEn': 'Partner\'s Astro Portrait',
        'descTr': 'Başka birinin doğum tarihine göre astro portresi.',
        'descEn': 'Astro portrait of a friend or partner based on birth.',
        'route': '/partner-natal-chart'
      },
      {
        'icon': '👁️',
        'titleTr': 'Kozmik Kâhin',
        'titleEn': 'Cosmic Oracle',
        'descTr': 'Yapay zeka kâhinine astroloji hakkında soru sorun.',
        'descEn': 'Ask the AI-powered astrology oracle your questions.',
        'route': '/cosmic-oracle'
      },
      {
        'icon': '🃏',
        'titleTr': 'Kozmik Tarot',
        'titleEn': 'Cosmic Tarot',
        'descTr': 'Doğum haritası entegreli 3 kartlık tarot açılımı.',
        'descEn': '3-card tarot spread integrated with your natal chart.',
        'route': '/tarot'
      }
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 3 : 2;
    final double childAspectRatio = screenWidth > 600 ? 1.25 : 1.05;

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
                        const SizedBox(height: 12),
                        // Başlık
                        Text(
                          title,
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Açıklama
                        Text(
                          desc,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10.0,
                            height: 1.35,
                          ),
                          maxLines: 3,
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
