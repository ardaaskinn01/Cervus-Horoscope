import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shake/shake.dart';
import 'package:go_router/go_router.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/core/services/ad_service.dart';

class CosmicOrbScreen extends ConsumerStatefulWidget {
  const CosmicOrbScreen({super.key});

  @override
  ConsumerState<CosmicOrbScreen> createState() => _CosmicOrbScreenState();
}

class _CosmicOrbScreenState extends ConsumerState<CosmicOrbScreen> {
  ShakeDetector? _shakeDetector;
  bool _isShaking = false;
  String? _answerTr;
  String? _answerEn;
  bool _showAnswer = false;
  int _orbUsageCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialize shake detector
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: () {
        _triggerShake();
      },
      shakeThresholdGravity: 2.7,
    );
  }

  @override
  void dispose() {
    _shakeDetector?.stopListening();
    super.dispose();
  }

  void _triggerShake() {
    if (_isShaking) return;
    _executeShakeLogic();
  }

  void _executeShakeLogic() {
    _orbUsageCount++;

    // Vibration feedback on shake start
    HapticFeedback.heavyImpact();

    setState(() {
      _isShaking = true;
      _showAnswer = false;
      _answerTr = null;
      _answerEn = null;
    });

    // Randomize the answer after shake animation ends (1.2 seconds delay)
    final bool isYes = Random().nextBool();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isShaking = false;
          _showAnswer = true;
          if (isYes) {
            _answerTr = "Evet, aklındaki gerçekleşecek.";
            _answerEn = "Yes, what is in your mind will happen.";
          } else {
            _answerTr = "Hayır, gerçekleşmeyecek.";
            _answerEn = "No, it will not happen.";
          }
        });
        // Success haptic feedback
        HapticFeedback.mediumImpact();
      }
    });
  }

  Widget _buildOrbContent(bool isTr) {
    if (_isShaking) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🔮',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            isTr ? 'Kozmik Enerji\nToplanıyor...' : 'Gathering\nCosmic Energy...',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white70,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.cyanAccent.withValues(alpha: 0.8), blurRadius: 10),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.4, end: 1.0, duration: 250.ms),
        ],
      );
    }

    if (_showAnswer) {
      final answer = isTr ? _answerTr : _answerEn;
      final isYes = _answerTr?.contains('Evet') ?? false;
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isYes ? '✨ EVET ✨' : '⚡ HAYIR ⚡',
              style: AppTextStyles.label.copyWith(
                color: isYes ? Colors.cyanAccent : Colors.pinkAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: isYes ? Colors.cyan : Colors.pink, blurRadius: 10),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              answer ?? '',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.4,
                shadows: [
                  Shadow(color: isYes ? Colors.cyan : Colors.pink, blurRadius: 15),
                ],
              ),
            ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '🔮',
          style: TextStyle(fontSize: 56),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds),
        const SizedBox(height: 12),
        Text(
          isTr ? 'Kozmik Küre' : 'Cosmic Orb',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.primaryGold,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: AppColors.warmAmber.withValues(alpha: 0.8), blurRadius: 15),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    Widget orbWidget = GestureDetector(
      onTap: _triggerShake,
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.purpleAccent.withValues(alpha: 0.85),
              Colors.deepPurple.withValues(alpha: 0.95),
              Colors.black87,
            ],
            center: const Alignment(-0.35, -0.35),
            radius: 0.95,
          ),
          boxShadow: [
            BoxShadow(
              color: (_showAnswer && !(_answerTr?.contains('Evet') ?? false))
                  ? Colors.pink.withValues(alpha: 0.45)
                  : (_showAnswer ? Colors.cyan.withValues(alpha: 0.45) : Colors.purpleAccent.withValues(alpha: 0.45)),
              blurRadius: 40,
              spreadRadius: 8,
            ),
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Center(
          child: _buildOrbContent(isTr),
        ),
      ),
    );

    // Apply active shake or idle floating animations
    if (_isShaking) {
      orbWidget = orbWidget
          .animate(onPlay: (controller) => controller.repeat())
          .shake(hz: 14, curve: Curves.easeInOut, duration: 200.ms)
          .custom(
            begin: 0,
            end: 1,
            duration: 200.ms,
            builder: (context, val, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.5),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: child,
              );
            },
          );
    } else {
      orbWidget = orbWidget
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .slideY(begin: 0, end: -10, duration: 2.seconds, curve: Curves.easeInOut);
    }

    return StarBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(isTr ? 'Kozmik Küre' : 'Cosmic Orb'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Glowing instructions card
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Column(
                    children: [
                      const Text(
                        '💭',
                        style: TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isTr
                            ? 'Aklından gelecekle ilgili bir soru geçir, ardından telefonu salla veya küreye dokun.'
                            : 'Think of a question about the future, then shake your phone or tap the orb.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: -0.1),
                
                const Spacer(flex: 2),
                
                // Animated Orb
                Center(
                  child: orbWidget,
                ),
                
                const Spacer(flex: 2),
                
                // Restart button
                if (_showAnswer) ...[
                  GradientButton(
                    width: 220,
                    text: isTr ? 'Yeni Soru Sor' : 'Ask Another Question',
                    onTap: () {
                      final user = ref.read(userProvider);
                      final isPremium = user?.isAnyPremium ?? false;

                      if (!isPremium && _orbUsageCount >= 2) {
                        AdService.instance.showRewardedAd(
                          placement: 'cosmic_orb_rewarded',
                          context: context,
                          isPremium: false,
                          onRewardEarned: () {
                            if (mounted) {
                              setState(() {
                                _orbUsageCount = 0; // Reklam tamamlanınca sıfırlanır
                                _showAnswer = false;
                                _answerTr = null;
                                _answerEn = null;
                              });
                              HapticFeedback.lightImpact();
                            }
                          },
                        );
                        return;
                      }

                      setState(() {
                        _showAnswer = false;
                        _answerTr = null;
                        _answerEn = null;
                      });
                      HapticFeedback.lightImpact();
                    },
                  ).animate().fade(duration: 300.ms).scale(curve: Curves.easeOutBack),
                ],
                
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
