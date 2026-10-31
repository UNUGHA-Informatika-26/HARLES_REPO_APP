import 'package:flutter/material.dart';

class BrandedBackground extends StatelessWidget {
  final Widget child;
  final double imageOpacity;

  const BrandedBackground({
    super.key,
    required this.child,
    this.imageOpacity = 0.08,
  });

  static const Color _primaryTeal = Color(0xFF13C5BC);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: Stack(
        children: [
          // 1. Soft Gradient Top Ambient Tint
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFCCFBF1),
                    Color(0xFFE6FFFA),
                    Color(0xFFF8FAFC),
                  ],
                ),
              ),
            ),
          ),

          // 2. Branded Watermark Background Image (assets/logo.png.jpg)
          Positioned.fill(
            child: Opacity(
              opacity: imageOpacity,
              child: Image.asset(
                'assets/logo.png.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primaryTeal.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Child Screen Content
          Positioned.fill(
            child: child,
          ),
        ],
      ),
    );
  }
}
