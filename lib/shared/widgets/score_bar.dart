import 'package:flutter/material.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';

class ScoreBar extends StatelessWidget {
  final String label;
  final int value; // 0 - 100 arası
  final IconData? icon;
  final Duration duration;

  const ScoreBar({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = (value.clamp(0, 100)) / 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: percentage),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, val, _) {
          final int currentValue = (val * 100).round();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 16,
                          color: AppColors.primaryGold,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currentValue.toString(),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Animasyonlu İlerleme Çubuğu (Progress Bar)
              Stack(
                children: [
                  // Arka Plan Çubuğu
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 0.5,
                      ),
                    ),
                  ),
                  // Dolgulu Alan (Gradiyent)
                  FractionallySizedBox(
                    widthFactor: val,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warmAmber.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
