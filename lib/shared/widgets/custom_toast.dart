import 'package:flutter/material.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';

class CustomToast {
  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String message, {bool isError = false}) {
    // Remove current toast if active
    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => ToastOverlayContent(
        message: message,
        isError: isError,
        onDismiss: () {
          // Verify that we are removing the active toast
          if (_currentEntry != null) {
            _currentEntry!.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class ToastOverlayContent extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const ToastOverlayContent({
    super.key,
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<ToastOverlayContent> createState() => _ToastOverlayContentState();
}

class _ToastOverlayContentState extends State<ToastOverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    // Auto dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: GlassCard(
                  color: widget.isError 
                      ? const Color(0xFF3D0E0E).withValues(alpha: 0.8)
                      : AppColors.cardSurface.withValues(alpha: 0.85),
                  border: Border.all(
                    color: widget.isError 
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : AppColors.primaryGold.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isError 
                            ? Icons.error_outline_rounded 
                            : Icons.auto_awesome_rounded,
                        color: widget.isError ? Colors.redAccent : AppColors.primaryGold,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
