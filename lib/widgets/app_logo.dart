import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double height;
  final double size;
  final bool showFullBanner;
  final bool withText;

  const AppLogo({
    super.key,
    this.height = 38.0,
    this.size = 38.0,
    this.showFullBanner = false,
    this.withText = false,
  });

  static const Color brandTeal = Color(0xFF13C5BC);
  static const Color darkTeal = Color(0xFF005F5B);
  static const Color accentYellow = Color(0xFFFACC15);

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height != 38.0 ? height : size;

    if (showFullBanner) {
      return Container(
        width: double.infinity,
        height: 190,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: brandTeal,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: brandTeal.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackBanner(),
        ),
      );
    }

    final logoWidget = SizedBox(
      height: effectiveHeight,
      width: effectiveHeight,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackHeader(effectiveHeight),
        ),
      ),
    );

    if (withText) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          logoWidget,
          const SizedBox(width: 8),
          const Text(
            'Harles Jujug',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: darkTeal,
            ),
          ),
        ],
      );
    }

    return logoWidget;
  }

  Widget _buildFallbackHeader(double h) {
    return SizedBox(
      height: h,
      width: h,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: h,
          height: h,
          decoration: BoxDecoration(
            color: brandTeal,
            borderRadius: BorderRadius.circular(h * 0.25),
          ),
          alignment: Alignment.center,
          child: Text(
            'H',
            style: TextStyle(
              fontSize: h * 0.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 0,
          right: 0,
          height: 28,
          child: Container(color: accentYellow),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'harles',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkTeal),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Text(
                'Jujug',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: darkTeal,
                  letterSpacing: -1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
