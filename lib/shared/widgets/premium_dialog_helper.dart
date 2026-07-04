import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/services/revenuecat_service.dart';

class PremiumDialogHelper {
  static void show(BuildContext context, WidgetRef ref) {
    final language = ref.read(languageProvider);
    final isTr = language.languageCode == 'tr';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.3), width: 1.5),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star/Crown Header
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                      ),
                    ),
                    const Icon(
                      Icons.stars_rounded,
                      size: 60,
                      color: AppColors.primaryGold,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  isTr ? "Astris Pro Üyelik" : "Astris Pro Membership",
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  isTr 
                      ? "Yıldızların rehberliğinde sınırsız mistik keşfe çıkın"
                      : "Embark on an unlimited mystical discovery guided by the stars",
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Features
                _buildFeatureRow(
                  Icons.block,
                  isTr ? "Reklamsız Deneyim" : "Ad-Free Experience",
                  isTr ? "Mistik yolculuğunuzda kesintisiz, reklamsız deneyim." : "Seamless, ad-free experience on your journey.",
                ),
                _buildFeatureRow(
                  Icons.auto_awesome,
                  isTr ? "Sınırsız Günlük Analiz" : "Unlimited Daily Insights",
                  isTr ? "Yapay zeka destekli kozmik yorumlara sınırsız erişim." : "Unlimited access to AI cosmic insights.",
                ),
                _buildFeatureRow(
                  Icons.favorite,
                  isTr ? "Detaylı Aşk & Sinastri" : "Detailed Love & Synastry",
                  isTr ? "Aşk uyumu ve sinastri analizlerinde tam detaylar." : "Full details in love compatibility and synastry analysis.",
                ),
                _buildFeatureRow(
                  Icons.person_search_rounded,
                  isTr ? "Detaylı Karakter Analizi" : "Detailed Character Analysis",
                  isTr ? "Karakter analizindeki tüm kilitli bölümler ve burç eşleşmeleri açılır." : "Unlock All locked sections and zodiac sign matches are unlocked.",
                ),
                const SizedBox(height: 24),
                
                // RevenueCat Options Loader
                FutureBuilder<Offerings?>(
                  future: RevenueCatService.getOfferings(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primaryGold),
                        ),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return _buildErrorState(isTr);
                    }

                    final offerings = snapshot.data!;
                    final availablePackages = offerings.current?.availablePackages ?? [];

                    if (availablePackages.isEmpty) {
                      return _buildErrorState(isTr);
                    }

                    final proPlusPackages = availablePackages.where(
                      (pkg) => pkg.storeProduct.identifier.toLowerCase().contains('plus') || pkg.storeProduct.identifier.toLowerCase().contains('proplus')
                    ).toList();
                    final proPackages = availablePackages.where(
                      (pkg) => !pkg.storeProduct.identifier.toLowerCase().contains('plus') && !pkg.storeProduct.identifier.toLowerCase().contains('proplus')
                    ).toList();

                    // Fiyata göre küçükten büyüğe sıralama yapıyoruz
                    proPlusPackages.sort((a, b) => a.storeProduct.price.compareTo(b.storeProduct.price));
                    proPackages.sort((a, b) => a.storeProduct.price.compareTo(b.storeProduct.price));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (proPackages.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Text(
                              isTr ? "ASTRIS PRO" : "ASTRIS PRO",
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primaryGold,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            isTr 
                                ? "• Günlük 10 yapay zeka hakkı\n• Reklam yok\n• Tüm kilitli bölümler açık"
                                : "• Daily 10 AI limit\n• No ads\n• All details unlocked",
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...proPackages.map((pkg) => _buildPackageCard(
                            context: context,
                            ref: ref,
                            dialogContext: ctx,
                            package: pkg,
                            isTr: isTr,
                            isProPlus: false,
                          )),
                          const SizedBox(height: 16),
                        ],
                        if (proPlusPackages.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  isTr ? "ASTRIS PRO+" : "ASTRIS PRO+",
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.primaryGold,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.goldGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isTr ? "ÖNERİLEN" : "RECOMMENDED",
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isTr 
                                ? "• Sınırsız yapay zeka hakkı\n• Reklam yok\n• Tüm kilitli bölümler açık"
                                : "• Truly unlimited AI calculations\n• No ads\n• All details unlocked",
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...proPlusPackages.map((pkg) => _buildPackageCard(
                            context: context,
                            ref: ref,
                            dialogContext: ctx,
                            package: pkg,
                            isTr: isTr,
                            isProPlus: true,
                          )),
                        ],
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Legal Links and Restore
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () async {
                        try {
                          final restoreSuccess = await RevenueCatService.restorePurchases();
                          if (restoreSuccess) {
                            await ref.read(userProvider.notifier).syncPremiumStatus();
                          }
                          final user = ref.read(userProvider);
                          final bool hasAny = user?.isAnyPremium == true;
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  hasAny
                                      ? (isTr ? "Aboneliğiniz başarıyla geri yüklendi! ✨" : "Subscription restored successfully! ✨")
                                      : (isTr ? "Geri yüklenecek aktif abonelik bulunamadı." : "No active subscription found to restore."),
                                ),
                                backgroundColor: hasAny ? Colors.green : Colors.orange,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isTr ? "Geri yükleme başarısız oldu." : "Restore failed."),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        isTr ? "Geri Yükle" : "Restore",
                        style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      "•",
                      style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                    ),
                    TextButton(
                      onPressed: () => _openLegalUrl("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        isTr ? "Kullanım Koşulları (EULA)" : "Terms of Use (EULA)",
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ),
                    Text(
                      "•",
                      style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                    ),
                    TextButton(
                      onPressed: () => _openLegalUrl("https://cervusdigital.com/astris/privacy-policy/"),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        isTr ? "Gizlilik Sözleşmesi" : "Privacy Policy",
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isTr ? "Kapat" : "Close",
                    style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGold, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildErrorState(bool isTr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 32),
          const SizedBox(height: 8),
          Text(
            isTr ? "Abonelik paketleri alınamadı." : "Subscription packages could not be retrieved.",
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isTr 
                ? "Lütfen internet bağlantınızı kontrol edin veya daha sonra tekrar deneyin."
                : "Please check your internet connection or try again later.",
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Widget _buildPackageCard({
    required BuildContext context,
    required WidgetRef ref,
    required BuildContext dialogContext,
    required Package package,
    required bool isTr,
    required bool isProPlus,
  }) {
    String name = "";
    final id = package.identifier.toLowerCase();
    
    final bool isMonthly = package.packageType == PackageType.monthly || id.contains('monthly');
    final bool isAnnual = package.packageType == PackageType.annual || id.contains('annual') || id.contains('yearly');
    final bool isLifetime = package.packageType == PackageType.lifetime || id.contains('lifetime');
    
    bool isPopular = isAnnual;

    if (isMonthly) {
      name = isTr ? "Aylık Paket" : "Monthly Package";
    } else if (isAnnual) {
      name = isTr ? "Yıllık Paket" : "Annual Package";
    } else if (isLifetime) {
      name = isTr ? "Ömür Boyu" : "Lifetime Access";
    } else {
      String rawTitle = package.storeProduct.title;
      if (rawTitle.contains('(')) {
        name = rawTitle.split('(').first.trim();
      } else {
        name = rawTitle;
      }
    }

    final price = package.storeProduct.priceString;

    return GestureDetector(
      onTap: () async {
        showDialog(
          context: dialogContext,
          barrierDismissible: false,
          builder: (loadingCtx) => PopScope(
            canPop: false,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            ),
          ),
        );

        try {
          final purchaseSuccess = await RevenueCatService.purchasePackage(package);
          if (purchaseSuccess) {
            await ref.read(userProvider.notifier).syncPremiumStatus();
          }

          if (dialogContext.mounted) {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }

          if (purchaseSuccess) {
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
            }
            if (context.mounted) {
              final user = ref.read(userProvider);
              final bool isPlus = user?.isPremium == true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isPlus
                        ? (isTr 
                            ? "Astris Pro+ üyeliğiniz aktif edildi! 🌟" 
                            : "Your Astris Pro+ membership has been activated! 🌟")
                        : (isTr 
                            ? "Astris Pro üyeliğiniz aktif edildi! 🌟" 
                            : "Your Astris Pro membership has been activated! 🌟"),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (e) {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }

          bool isCancelled = false;
          if (e is PlatformException) {
            final errorCode = PurchasesErrorHelper.getErrorCode(e);
            if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
              isCancelled = true;
            }
          }

          if (!isCancelled && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isTr ? "Satın alma işlemi başarısız oldu." : "Purchase process failed."),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isPopular ? AppColors.primaryGold.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? AppColors.primaryGold : AppColors.borderLight,
            width: isPopular ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isTr ? "EN POPÜLER" : "POPULAR",
                            style: AppTextStyles.caption.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.storeProduct.description.isNotEmpty
                        ? package.storeProduct.description
                        : (isMonthly
                            ? (isTr ? "Aylık yenilenen abonelik" : "Monthly auto-renewing subscription")
                            : (isAnnual
                                ? (isTr ? "Yıllık yenilenen abonelik" : "Yearly auto-renewing subscription")
                                : (isTr ? "Tek seferlik ödeme" : "One-time payment"))),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isAnnual) ...[
                  Text(
                    isProPlus
                        ? (isTr ? "₺2.999,99" : "\$299.99")
                        : (isTr ? "₺599,99" : "\$599.99"),
                    style: TextStyle(
                      color: Colors.redAccent.shade200,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.redAccent.shade200,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  price,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openLegalUrl(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
