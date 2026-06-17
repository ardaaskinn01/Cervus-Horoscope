import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/providers/navigation_provider.dart';
import 'package:horoscope/features/home/home_screen.dart';
import 'package:horoscope/features/natal_chart/natal_chart_screen.dart';
import 'package:horoscope/features/tools/tools_screen.dart';
import 'package:horoscope/features/who_am_i/who_am_i_screen.dart';
import 'package:horoscope/features/settings/settings_screen.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/star_background.dart';

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
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      extendBody: true, // Alt barın arkasının görünmesi (cam efekti) için
      body: StarBackground(
        child: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _buildFloatingBottomBar(currentIndex),
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
