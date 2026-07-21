import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/services/limit_service.dart';
import 'package:horoscope/core/services/ad_service.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/premium_dialog_helper.dart';

class LimitDialogHelper {
  static Future<dynamic> showAdRequiredDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String featureKey,
    required VoidCallback onAdCompleted,
  }) {
    final isTr = ref.read(languageProvider).languageCode == 'tr';

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📊', style: TextStyle(fontSize: 48))
                    .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 16),
                Text(
                  isTr ? 'Yapay Zeka Analiz Limiti' : 'AI Calculation Limit',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isTr
                      ? 'İlk ücretsiz kullanım hakkınız tamamlanmıştır. Ödüllü bir reklam izleyerek hemen +1 günlük analiz hakkı kazanabilir veya Premium\'a geçerek sınırsız analiz yapabilirsiniz.'
                      : 'Your first free calculation has been consumed. Watch a rewarded ad to earn 1 daily calculation, or upgrade to Premium for unlimited access.',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: isTr ? 'Reklam İzle 📺' : 'Watch Ad 📺',
                  onTap: () {
                    Navigator.pop(dialogCtx);
                    AdService.instance.showRewardedAd(
                      placement: 'ai_tools_rewarded',
                      context: context,
                      isPremium: false,
                      onRewardEarned: () async {
                        await LimitService.instance.registerAdWatch(featureKey);
                        onAdCompleted();
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    PremiumDialogHelper.show(context, ref);
                  },
                  child: Text(
                    isTr ? '7 Gün Ücretsiz Deneyin 🎁' : 'Try 7 Days Free 🎁',
                    style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    isTr ? 'Kapat' : 'Close',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showDailyLimitReachedDialog({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final isTr = ref.read(languageProvider).languageCode == 'tr';
    final user = ref.read(userProvider);
    final bool isPro = user?.isPro == true;
    final isGlobal = await LimitService.instance.isGlobalLimitReached();

    if (!context.mounted) return;

    String limitMessage = "";
    if (isPro) {
      limitMessage = isTr
          ? 'Günlük Pro üyelik yapay zeka limitinize (10/10) ulaştınız. Gece 04:00\'den sonra tekrar deneyebilir veya şimdi Pro+ (Pro Plus) üyeliğine geçerek tamamen sınırsız analiz yapabilirsiniz.'
          : 'You have reached your daily Pro limit of 10 calculations. Try again after 04:00 AM, or upgrade to Pro+ right now for truly unlimited access.';
    } else {
      limitMessage = isGlobal
          ? (isTr
              ? 'Günlük toplam yapay zeka limitinize (3/3) ulaştınız. Gece 04:00\'den sonra tekrar deneyebilir veya şimdi Premium\'a geçerek beklemeden sınırsız erişim sağlayabilirsiniz.'
              : 'You have reached your daily limit for AI calculations. Try again after 04:00 AM, or upgrade to Premium right now for unlimited, instant access.')
          : (isTr
              ? 'Bu özellik için bugünkü günlük hakkınız dolmuştur. Gece 04:00\'den sonra tekrar deneyebilir veya şimdi Premium\'a geçerek beklemeden sınırsız erişim sağlayabilirsiniz.'
              : 'You have reached your daily limit for this feature. Try again after 04:00 AM, or upgrade to Premium right now for unlimited, instant access.');
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 48))
                    .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 16),
                Text(
                  isTr ? 'Günlük Limit Aşıldı' : 'Daily Limit Reached',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  limitMessage,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: isPro
                      ? (isTr ? 'Pro+\'a Yükselt ✨' : 'Upgrade to Pro+ ✨')
                      : (isTr ? '7 Gün Ücretsiz Deneyin 🎁' : 'Try 7 Days Free 🎁'),
                  onTap: () {
                    Navigator.pop(dialogCtx);
                    PremiumDialogHelper.show(context, ref);
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    isTr ? 'Kapat' : 'Close',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
