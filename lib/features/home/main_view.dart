import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/constants/app_strings.dart';
import 'package:horoscope/core/providers/navigation_provider.dart';
import 'package:horoscope/features/home/home_screen.dart';
import 'package:horoscope/features/natal_chart/natal_chart_screen.dart';
import 'package:horoscope/features/tools/tools_screen.dart';
import 'package:horoscope/features/who_am_i/who_am_i_screen.dart';
import 'package:horoscope/features/settings/settings_screen.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/core/services/ad_service.dart';
import 'package:horoscope/core/providers/user_provider.dart';

class MainView extends ConsumerStatefulWidget {
  const MainView({super.key});

  @override
  ConsumerState<MainView> createState() => _MainViewState();
}

class _MainViewState extends ConsumerState<MainView> {
  final List<Widget> _screens = const [
    HomeScreen(),
    NatalChartScreen(),
    ToolsScreen(),
    WhoAmIScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkVersion();
      }
    });
  }

  Future<void> _checkVersion() async {
    try {
      final doc = await FirebaseFirestore.instance.doc('settings/app_config').get();
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          final info = await PackageInfo.fromPlatform();
          final currentBuild = int.tryParse(info.buildNumber) ?? 0;
          final latestBuild = int.tryParse(data['latestBuildNumber']?.toString() ?? "") ?? currentBuild;

          if (latestBuild > currentBuild) {
            final iosUrl = data['iosUrl']?.toString() ?? "";
            final androidUrl = data['androidUrl']?.toString() ?? "";
            _showUpdateDialog(iosUrl, androidUrl);
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Versiyon kontrol hatası: $e");
    }
  }

  void _showUpdateDialog(String iosUrl, String androidUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: GlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  context.translate('update_new_version_title'),
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  context.translate('update_new_version_desc'),
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    // Later Button
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppColors.borderLight),
                          ),
                        ),
                        child: Text(
                          context.translate('update_btn_later'),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Update Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final url = Platform.isIOS ? iosUrl : androidUrl;
                          if (url.isNotEmpty) {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              context.translate('update_btn_confirm'),
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getPlacementForIndex(int index) {
    switch (index) {
      case 0:
        return 'home_banner';
      case 1:
        return 'chart_banner';
      case 2:
        return 'tools_banner';
      case 3:
        return 'who_am_i_banner';
      default:
        return 'home_banner';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final user = ref.watch(userProvider);
    final isPremium = user?.isAnyPremium ?? false;

    return Scaffold(
      extendBody: true, // Alt barın arkasının görünmesi (cam efekti) için
      body: StarBackground(
        child: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdService.instance.getBannerAdWidget(
            _getPlacementForIndex(currentIndex),
            isPremium: isPremium,
          ),
          _buildFloatingBottomBar(currentIndex),
        ],
      ),
    );
  }

  // Özel yüzen cam tasarımlı Bottom Bar
  Widget _buildFloatingBottomBar(int currentIndex) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
        child: GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(currentIndex, 0, Icons.home_rounded, 'Ana Sayfa'),
              _buildNavItem(currentIndex, 1, Icons.map_rounded, 'Haritam'),
              _buildNavItem(currentIndex, 2, Icons.auto_awesome_rounded, 'Araçlar'),
              _buildNavItem(currentIndex, 3, Icons.stars_rounded, 'Karakter'),
              _buildNavItem(currentIndex, 4, Icons.settings_rounded, 'Ayarlar'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int currentIndex, int index, IconData icon, String label) {
    final bool isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        if (currentIndex != index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
          HapticFeedback.lightImpact();
        }
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İkon
            Icon(
              icon,
              color: isSelected ? AppColors.primaryGold : AppColors.textSecondary.withValues(alpha: 0.6),
              size: isSelected ? 26 : 22,
            ),
            const SizedBox(height: 4),
            // İnce Aktif Çizgisi (Indicator)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 16 : 0,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.warmAmber.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
