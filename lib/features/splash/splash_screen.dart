import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _initializeApp();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Firebase oturumunu ve Dashboard verilerini yükle
    await ref.read(userProvider.notifier).initializeUser();

    // Onboarding durumunun yüklendiğinden emin ol
    await ref.read(onboardingCompleteProvider.notifier).ensureLoaded();

    // Görsel tatmin için en az 2 saniye bekle
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final user = ref.read(userProvider);
      final isComplete = ref.read(onboardingCompleteProvider);

      if (user?.uid == 'offline_anonymous') {
        final isTr = ref.read(languageProvider).languageCode == 'tr';
        CustomToast.show(
          context,
          isTr ? 'Çevrimdışı modda devam ediliyor...' : 'Continuing in offline mode...',
        );
      }

      if (isComplete) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(languageProvider).languageCode == 'tr';
    return Scaffold(
      body: StarBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dönen mistik kristal/küre logosu
              RotationTransition(
                turns: _logoController,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warmAmber.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '🔮',
                      style: TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Uygulama Başlığı
              Text(
                'Astris',
                style: AppTextStyles.h1.copyWith(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: AppColors.warmAmber.withValues(alpha: 0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isTr ? 'Doğum Haritası, Tarot ve Fazlası' : 'Birth Chart, Tarot & More',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 64),
              // Yükleniyor Göstergesi
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.primaryGold,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
