import 'dart:math';
import 'package:flutter/material.dart';

class StarBackground extends StatefulWidget {
  final Widget? child;
  final int starCount;

  const StarBackground({
    super.key,
    this.child,
    this.starCount = 70,
  });

  @override
  State<StarBackground> createState() => _StarBackgroundState();
}

class _StarBackgroundState extends State<StarBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Star> _stars = [];
  final Random _random = Random();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Yıldızları oluştur
    for (int i = 0; i < widget.starCount; i++) {
      _stars.add(
        Star(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: _random.nextDouble() * 2.2 + 0.6,
          maxOpacity: _random.nextDouble() * 0.6 + 0.4,
          speed: _random.nextDouble() * 1.5 + 0.5,
          phase: _random.nextDouble() * pi * 2,
        ),
      );
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final starColor = isDark ? Colors.white : const Color(0xFFC17B2A); // Açık temada altın/kehribar rengi yıldızlar

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollUpdateNotification) {
          if (mounted) {
            setState(() {
              _scrollOffset = notification.metrics.pixels;
            });
          }
        }
        return false; // Let notification bubble up to other listeners
      },
      child: Stack(
        children: [
          // Yıldız Çizimleri
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: StarPainter(
                    stars: _stars,
                    animationValue: _controller.value,
                    scrollOffset: _scrollOffset,
                    starColor: starColor,
                  ),
                );
              },
            ),
          ),
          // İçerik
          if (widget.child != null) Positioned.fill(child: widget.child!),
        ],
      ),
    );
  }
}

class Star {
  final double x; // 0.0 - 1.0 arası x konumu
  final double y; // 0.0 - 1.0 arası y konumu
  final double size; // yıldız boyutu
  final double maxOpacity; // maksimum opaklık seviyesi
  final double speed; // parıldama hızı çarpanı
  final double phase; // başlangıç fazı (hepsi aynı anda parıldamasın)

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.maxOpacity,
    required this.speed,
    required this.phase,
  });
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;
  final double scrollOffset;
  final Color starColor;

  StarPainter({
    required this.stars,
    required this.animationValue,
    required this.scrollOffset,
    required this.starColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = starColor;

    for (final star in stars) {
      // Sinüs dalgası kullanarak yumuşak parıldama efekti elde edelim
      final double angle = (animationValue * pi * 2 * star.speed) + star.phase;
      final double pulse = (sin(angle) + 1.0) / 2.0; // 0.0 - 1.0 arasına normalize et
      final double opacity = pulse * star.maxOpacity * (starColor == Colors.white ? 1.0 : 0.6); // Açık temada yıldızları daha naif/yumuşak yapmak için hafifçe kısalım

      paint.color = starColor.withValues(alpha: opacity);

      final double px = star.x * size.width;
      
      // Parallax speed based on star size to create depth (larger = faster, closer)
      final double parallaxFactor = star.size * 0.15;
      final double rawY = (star.y * size.height) - (scrollOffset * parallaxFactor);
      
      // Dynamic wrap-around using modulo
      final double py = (rawY % size.height + size.height) % size.height;

      // Yıldızı çiz
      canvas.drawCircle(Offset(px, py), star.size, paint);
      
      // Daha parlak yıldızlar için hafif bir hale (glow) efekti ekleyelim
      if (star.size > 2.0 && opacity > 0.6) {
        final Paint glowPaint = Paint()
          ..color = starColor.withValues(alpha: opacity * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(px, py), star.size * 2.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.starColor != starColor;
  }
}
