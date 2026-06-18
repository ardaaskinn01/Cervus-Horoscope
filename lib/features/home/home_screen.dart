import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/constants/app_strings.dart';
import 'package:horoscope/core/models/daily_comment_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/navigation_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/score_bar.dart';
import 'package:horoscope/shared/widgets/zodiac_icon.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isCommentExpanded = false;
  
  // AI Yükleme Durumları
  bool _isLoadingDaily = true;
  DailyCommentModel? _dailyComment;

  bool _isLoadingMonthly = true;
  Map<String, dynamic>? _monthlyComment;

  // Hızlı Erişim Butonları Eşleştirmesi (Yalnızca Hesaplama Araçları)
  final List<Map<String, dynamic>> _quickActions = [
    {'icon': Icons.map_rounded, 'title': 'Astro Portre', 'titleEn': 'Astro Portrait', 'route': 1},
    {'icon': Icons.favorite_rounded, 'title': 'Aşk Uyumu', 'titleEn': 'Love Compatibility', 'route': 'love'},
    {'icon': Icons.people_rounded, 'title': 'Arkadaşlık Uyumu', 'titleEn': 'Friend Compatibility', 'route': 'friend'},
    {'icon': Icons.pin_rounded, 'title': 'Numeroloji', 'titleEn': 'Numerology', 'route': 'numerology'},
    {'icon': Icons.auto_awesome_rounded, 'title': 'Kozmik Kâhin', 'titleEn': 'Cosmic Oracle', 'route': 'cosmic_oracle'},
    {'icon': Icons.stars_rounded, 'title': 'Başkasının Portresi', 'titleEn': 'Partner\'s Portrait', 'route': 'partner_chart'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final user = ref.read(userProvider);
    if (user == null) {
      setState(() {
        _isLoadingDaily = false;
        _isLoadingMonthly = false;
      });
      return;
    }

    final now = DateTime.now();
    final adjustedDate = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    final todayStr = DateFormat('yyyy-MM-dd').format(adjustedDate);
    final currentMonthStr = DateFormat('yyyy-MM').format(adjustedDate);
    final zodiac = user.zodiacSign ?? 'aries';
    final gender = user.gender ?? 'female';

    // 1. Günlük Yorum Yükleme
    try {
      final comment = await AiService().generateAndSaveDailyComment(
        date: todayStr,
        zodiac: zodiac,
        gender: gender,
      );
      if (mounted) {
        setState(() {
          _dailyComment = comment;
          _isLoadingDaily = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isLoadingDaily = false; });
      }
    }

    // 2. Aylık Yorum Yükleme (Sadece ayın 1'i ise yükle)
    if (DateTime.now().day == 1) {
      try {
        final monthly = await AiService().generateAndSaveMonthlyComment(
          month: currentMonthStr,
          zodiac: zodiac,
          gender: gender,
        );
        if (mounted) {
          setState(() {
            _monthlyComment = monthly;
            _isLoadingMonthly = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() { _isLoadingMonthly = false; });
        }
      }
    } else {
      if (mounted) {
        setState(() { _isLoadingMonthly = false; });
      }
    }
  }

  // Zaman dilimine göre selamlama
  String _getGreeting(String locale) {
    final hour = DateTime.now().hour;
    final isTr = locale == 'tr';

    if (hour >= 5 && hour < 12) {
      return isTr ? 'Günaydın' : 'Good Morning';
    } else if (hour >= 12 && hour < 18) {
      return isTr ? 'Tünaydın' : 'Good Afternoon';
    } else if (hour >= 18 && hour < 22) {
      return isTr ? 'İyi Akşamlar' : 'Good Evening';
    } else {
      return isTr ? 'İyi Geceler' : 'Good Night';
    }
  }

  // Burç Adı Çevirisi
  String _getZodiacName(String? key, bool isTr) {
    if (key == null) return '';
    if (!isTr) return key[0].toUpperCase() + key.substring(1);
    switch (key.toLowerCase()) {
      case 'aries': return 'Koç';
      case 'taurus': return 'Boğa';
      case 'gemini': return 'İkizler';
      case 'cancer': return 'Yengeç';
      case 'leo': return 'Aslan';
      case 'virgo': return 'Başak';
      case 'libra': return 'Terazi';
      case 'scorpio': return 'Akrep';
      case 'sagittarius': return 'Yay';
      case 'capricorn': return 'Oğlak';
      case 'aquarius': return 'Kova';
      case 'pisces': return 'Balık';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';
    
    final now = DateTime.now();
    final adjustedDate = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    final formattedDate = DateFormat('d MMMM yyyy', locale.languageCode).format(adjustedDate);
    final greeting = _getGreeting(locale.languageCode);
    final userName = user?.name ?? (isTr ? 'Gezgin' : 'Traveler');
    final userSign = user?.zodiacSign ?? 'aries';

    // Bugün ayın 1'i mi? (Aylık yorum kontrolü)
    final bool isFirstDayOfMonth = DateTime.now().day == 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          formattedDate,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Profil burç simgesi
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ZodiacIcon(
              sign: userSign,
              size: 38,
              showGlow: false,
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryGold,
        backgroundColor: AppColors.cardSurface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 160.0), // bottom nav boşluğu
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Giriş Selamlaması
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $userName 🔮',
                    style: AppTextStyles.h1.copyWith(
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: AppColors.warmAmber.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isTr 
                        ? 'Gezegenlerin bugünkü hizalanması seni nasıl etkiliyor?'
                        : 'How are today\'s planetary alignments affecting you?',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ).animate().fade(duration: 400.ms).slideY(begin: 0.05, duration: 400.ms),
              const SizedBox(height: 24),

              // CONDITIONAL: Aylık Yorum Kartı (Sadece ayın 1'inde gösterilir)
              if (isFirstDayOfMonth) ...[
                _buildMonthlyCommentCard(isTr)
                    .animate()
                    .fade(delay: 100.ms, duration: 400.ms)
                    .slideY(begin: 0.05, duration: 400.ms),
                const SizedBox(height: 24),
              ],

              // 1. Bugünkü Enerji Puanları
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('daily_scores'),
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 12),
                  _buildScoresSection(),
                ],
              ).animate().fade(delay: 150.ms, duration: 400.ms).slideY(begin: 0.05, duration: 400.ms),
              const SizedBox(height: 24),

              // 2. Günlük Yorum Kartı
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('daily_comment_title'),
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 12),
                  _buildCommentSection(isTr, userSign),
                ],
              ).animate().fade(delay: 250.ms, duration: 400.ms).slideY(begin: 0.05, duration: 400.ms),
              const SizedBox(height: 24),

              // 3. Hızlı Erişim Grid (2x3)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTr ? 'Kozmik Araçlar' : 'Cosmic Tools',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _quickActions.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    itemBuilder: (context, index) {
                      final action = _quickActions[index];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final route = action['route'];
                          if (route is int) {
                            ref.read(bottomNavIndexProvider.notifier).state = route;
                          } else if (route == 'love') {
                            context.push('/love-compatibility');
                          } else if (route == 'friend') {
                            context.push('/friend-compatibility');
                          } else if (route == 'numerology') {
                            context.push('/numerology');
                          } else if (route == 'cosmic_oracle') {
                            context.push('/cosmic-oracle');
                          } else if (route == 'partner_chart') {
                            context.push('/partner-natal-chart');
                          }
                        },
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                action['icon'],
                                color: AppColors.primaryGold,
                                size: 24,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isTr ? action['title'] : action['titleEn'],
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ).animate().fade(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  // Puanlar Kartını Yükleme Durumuna Göre Oluşturur
  Widget _buildScoresSection() {
    if (_isLoadingDaily) {
      return GlassCard(
        child: Column(
          children: List.generate(4, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 1200.ms, color: Colors.white24),
            );
          }),
        ),
      );
    }

    // AI'dan gelen verileri bağlayalım, yoksa fallback puanlar
    final love = _dailyComment?.love ?? 81;
    final money = _dailyComment?.money ?? 67;
    final career = _dailyComment?.career ?? 74;
    final energy = _dailyComment?.energy ?? 90;

    return GlassCard(
      child: Column(
        children: [
          ScoreBar(
            label: context.translate('love'),
            value: love,
            icon: Icons.favorite_rounded,
          ),
          ScoreBar(
            label: context.translate('money'),
            value: money,
            icon: Icons.monetization_on_rounded,
          ),
          ScoreBar(
            label: context.translate('career'),
            value: career,
            icon: Icons.work_rounded,
          ),
          ScoreBar(
            label: context.translate('energy'),
            value: energy,
            icon: Icons.bolt_rounded,
          ),
        ],
      ),
    );
  }

  // Yorum Kartını Yükleme Durumuna Göre Oluşturur
  Widget _buildCommentSection(bool isTr, String userSign) {
    if (_isLoadingDaily) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 20,
              width: 120,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
            ),
          ],
        )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white24),
      );
    }

    final commentText = _dailyComment != null
        ? (isTr ? _dailyComment!.commentTr : _dailyComment!.commentEn)
        : context.translate('sample_comment');

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ZodiacIcon(sign: userSign, size: 30, showGlow: false),
                  const SizedBox(width: 8),
                  Text(
                    _getZodiacName(userSign, isTr),
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryGold,
                size: 20,
              ),
            ],
          ),
          const Divider(),
          // Genişleyen Yorum Gövdesi
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _isCommentExpanded ? double.infinity : 90.0,
              ),
              child: Text(
                commentText,
                style: AppTextStyles.bodyMedium,
                overflow: _isCommentExpanded ? null : TextOverflow.fade,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Genişletme/Küçültme Butonu
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isCommentExpanded = !_isCommentExpanded;
                });
                HapticFeedback.lightImpact();
              },
              child: Text(
                _isCommentExpanded
                    ? (isTr ? 'Daha Az Göster ▲' : 'Read Less ▲')
                    : (isTr ? 'Daha Fazla Oku ▼' : 'Read More ▼'),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primaryGold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Aylık Yorum Kartı Widget'ı
  Widget _buildMonthlyCommentCard(bool isTr) {
    if (_isLoadingMonthly) {
      return GlassCard(
        child: Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white24),
      );
    }

    final commentText = _monthlyComment != null
        ? (isTr ? _monthlyComment!['comment_tr'] : _monthlyComment!['comment_en'])
        : (isTr
            ? 'Yeni bir ay başladı! Gökyüzünün bu ay size getirdiği şansları ve uyarıları kaçırmayın.'
            : 'A new month has begun! Don\'t miss the luck and warnings the sky brings you.');

    final luckyDays = _monthlyComment != null
        ? List<int>.from(_monthlyComment!['luckyDays']).join(', ')
        : '3, 7, 15, 22';

    final unluckyDays = _monthlyComment != null
        ? List<int>.from(_monthlyComment!['unluckyDays']).join(', ')
        : '9, 18';

    return GlassCard(
      color: AppColors.warmAmber.withValues(alpha: 0.15),
      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.primaryGold),
              const SizedBox(width: 8),
              Text(
                isTr ? 'Aylık Kozmik Yorum Raporu' : 'Monthly Cosmic Report',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.primaryGold),
          Text(
            commentText,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Şanslı Günler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? '🍀 Şanslı Günler' : '🍀 Lucky Days',
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.greenAccent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      luckyDays,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              // Şanssız Günler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? '⚠️ Dikkatli Günler' : '⚠️ Warning Days',
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unluckyDays,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
