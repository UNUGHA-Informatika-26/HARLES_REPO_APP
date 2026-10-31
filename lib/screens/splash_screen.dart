import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/app_logo.dart';
import 'admin_dashboard.dart';
import 'customer_dashboard.dart';
import 'driver_dashboard.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _BannerItem {
  final String title;
  final String subtitle;
  final String tag;
  final String badge;
  final IconData icon;
  final List<Color> gradientColors;
  final bool isBrandBanner;

  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.badge,
    required this.icon,
    required this.gradientColors,
    this.isBrandBanner = false,
  });
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);

  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  final List<_BannerItem> _banners = const [
    _BannerItem(
      title: 'Harles Jujug',
      subtitle: 'Dekat, cepat, dan siap membantu segala kebutuhan harian Anda',
      tag: 'Andalan Warga',
      badge: 'OFFICIAL APP',
      icon: Icons.stars_rounded,
      gradientColors: [Color(0xFF13C5BC), Color(0xFF005F5B)],
      isBrandBanner: true,
    ),
    _BannerItem(
      title: 'Harles Ride & Ojek',
      subtitle: 'Perjalanan aman, cepat, dan nyaman bersama driver lokal terpercaya',
      tag: 'Tarif Hemat',
      badge: 'CEPAT & AMAN',
      icon: Icons.two_wheeler_rounded,
      gradientColors: [Color(0xFF0284C7), Color(0xFF0369A1)],
    ),
    _BannerItem(
      title: 'Harles Kirim Paket',
      subtitle: 'Antar barang dan dokumen kilat sampai di hari yang sama',
      tag: 'Pasti Tepat Waktu',
      badge: 'EXPRESS DELIVERY',
      icon: Icons.local_shipping_rounded,
      gradientColors: [Color(0xFFEA580C), Color(0xFFC2410C)],
    ),
    _BannerItem(
      title: 'Harles Kuliner',
      subtitle: 'Pesan makanan dan minuman favorit hangat langsung ke depan pintu',
      tag: 'Banyak Promo',
      badge: 'KULINER LOKAL',
      icon: Icons.restaurant_rounded,
      gradientColors: [Color(0xFFE11D48), Color(0xFF9F1239)],
    ),
    _BannerItem(
      title: 'Harles Mart Belanja',
      subtitle: 'Kebutuhan harian, sembako & belanjaan dapur tanpa perlu antre',
      tag: 'Praktis & Lengkap',
      badge: 'BELANJA MUDAH',
      icon: Icons.shopping_bag_rounded,
      gradientColors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final user = await AuthService().checkCurrentUserSession();
    if (!mounted || user == null) return;

    Widget targetScreen;
    switch (user.role) {
      case UserRole.admin:
        targetScreen = const AdminDashboardScreen();
        break;
      case UserRole.customer:
        targetScreen = const CustomerDashboardScreen();
        break;
      case UserRole.driver:
        targetScreen = const DriverDashboardScreen();
        break;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
      (route) => false,
    );
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _jumpToBanner(int index) {
    _autoScrollTimer?.cancel();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE6FFFA),
              Color(0xFFF0FDFA),
              Colors.white,
            ],
            stops: [0.0, 0.35, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),

                      // Top Brand Header Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AppLogo(size: 38),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primaryTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.stars_rounded, size: 14, color: _darkTeal),
                                SizedBox(width: 4),
                                Text(
                                  'v1.0 Official',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _darkTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Dynamic Banner Carousel Slider
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _banners.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return _buildBannerCard(_banners[index]);
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Animated Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_banners.length, (index) {
                          final isActive = _currentPage == index;
                          return GestureDetector(
                            onTap: () => _jumpToBanner(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: isActive ? 22 : 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? _primaryTeal
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 24),

                      // Services Quick Feature Chips Row (clickable shortcuts)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureChip(Icons.two_wheeler_rounded, 'Ojek', const Color(0xFF0284C7), 1),
                          _buildFeatureChip(Icons.local_shipping_rounded, 'Paket', const Color(0xFFEA580C), 2),
                          _buildFeatureChip(Icons.restaurant_rounded, 'Kuliner', const Color(0xFFE11D48), 3),
                          _buildFeatureChip(Icons.shopping_bag_rounded, 'Mart', const Color(0xFF7C3AED), 4),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Sub-header Category
                      const Text(
                        'SATU APLIKASI, BANYAK SOLUSI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                          color: _secondaryText,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Main Headline
                      const Text(
                        'Dekat, cepat,\nsiap membantu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          color: _darkText,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Description
                      const Text(
                        'Selamat datang di Harles Jujug. Antar-jemput, kirim paket, dan kebutuhan harian jadi lebih mudah.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: _secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Button "Masuk ke Aplikasi (Login)"
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryTeal,
                          elevation: 3,
                          shadowColor: _primaryTeal.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Masuk ke Aplikasi (Login)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Pilihan Pendaftaran: Daftar Mandiri ATAU Hubungi Admin WA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            'Daftar Mandiri',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _primaryTeal,
                            ),
                          ),
                        ),
                        const Text('  •  ', style: TextStyle(color: _secondaryText)),
                        GestureDetector(
                          onTap: () {
                            WhatsAppService.openWhatsApp(
                              phone: WhatsAppService.adminPhone,
                              message: 'Halo Admin Harles Jujug, saya ingin mendaftar akun baru...',
                            );
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Hubungi Admin WA',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _darkTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerCard(_BannerItem item) {
    if (item.isBrandBanner) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: _primaryTeal,
          boxShadow: [
            BoxShadow(
              color: _primaryTeal.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Gambar Utama: assets/images/logo.png / assets/logo.png
            Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_primaryTeal, _darkTeal]),
                  ),
                ),
              ),
            ),

            // Semi-transparent gradient overlay to ensure text contrast & readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Badge & Teks Informasi
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          item.badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _darkTeal.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 12, color: Color(0xFFFACC15)),
                            const SizedBox(width: 4),
                            Text(
                              item.tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: item.gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background subtle decorative circles
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -35,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Main Card Content
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Badge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        item.badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 12, color: Color(0xFFFACC15)),
                          const SizedBox(width: 4),
                          Text(
                            item.tag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Center / Bottom Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Icon / Logo Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: item.isBrandBanner
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                              ),
                            )
                          : Icon(
                              item.icon,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, Color color, int bannerIndex) {
    return GestureDetector(
      onTap: () => _jumpToBanner(bannerIndex),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
        ],
      ),
    );
  }
}
