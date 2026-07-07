import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class _SplashScreenState extends ConsumerState<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _initializeApp();
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
              // Mistik logo görseli
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmAmber.withValues(alpha: 0.35),
                      blurRadius: 35,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/images/astris.PNG',
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(0.96, 0.96),
                end: const Offset(1.04, 1.04),
                duration: 2200.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(
                delay: 2500.ms,
                duration: 1500.ms,
                color: Colors.white24,
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
                isTr ? 'Kozmik Döngüler, Analiz ve Keşif' : 'Cosmic Cycles, Insights & Discovery',
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
