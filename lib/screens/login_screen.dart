import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/app_logo.dart';
import 'admin_dashboard.dart';
import 'customer_dashboard.dart';
import 'driver_dashboard.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordObscured = true;
  bool _isLoading = false;

  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _inputBorder = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final input = _inputController.text.trim();
    final password = _passwordController.text;

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap isi email/nomor WA dan password.')),
      );
      return;
    }

    if (input.contains('@') && !AuthService.isValidEmail(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format email tidak valid (contoh: nama@domain.com).')),
      );
      return;
    }

    if (!input.contains('@') && !AuthService.isValidPhoneNumber(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format nomor WhatsApp tidak valid (minimal 9 digit).')),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 8 karakter.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await AuthService().login(input, password);

      if (!mounted) return;

      if (success) {
        final user = AuthService().currentUser!;
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
      } else {
        final errorMsg = AuthService().errorMessage ?? 'Email/No. HP atau Password salah.';
        final isEmailNotConfirmed = errorMsg.toLowerCase().contains('email belum dikonfirmasi') ||
            errorMsg.toLowerCase().contains('email not confirmed');

        if (isEmailNotConfirmed) {
          _showVerifyEmailDialog(input);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVerifyEmailDialog(String emailInput) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_rounded, color: _primaryTeal),
            SizedBox(width: 8),
            Text('Verifikasi Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Akun Anda ($emailInput) belum diverifikasi. Masukkan 6 digit kode OTP yang dikirimkan ke email Anda untuk mengaktifkan akun.',
          style: const TextStyle(fontSize: 14, color: _darkText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryTeal),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerifyEmailScreen(email: emailInput),
                ),
              );
            },
            child: const Text(
              'Masukkan Kode OTP',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Top Bar with AppLogo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: _darkText),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const AppLogo(size: 34),
                  const SizedBox(width: 40),
                ],
              ),

              const SizedBox(height: 28),

              // Title & Subtitle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryTeal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.waving_hand_rounded, color: _darkTeal, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Selamat Datang Kembali',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Masuk ke akun Anda untuk melacak pesanan & transaksi.',
                style: TextStyle(
                  fontSize: 14,
                  color: _secondaryText,
                ),
              ),

              const SizedBox(height: 28),

              // Input Email / No HP
              const Text(
                'Email atau Nomor WhatsApp',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: 'nama@email.com atau 81234567890',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  filled: true,
                  fillColor: _lightBg,
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: _secondaryText, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _primaryTeal, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Input Password
              const Text(
                'Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _isPasswordObscured,
                decoration: InputDecoration(
                  hintText: 'Masukkan password Anda',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  filled: true,
                  fillColor: _lightBg,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: _secondaryText, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _secondaryText,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      });
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _primaryTeal, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    elevation: 2,
                    shadowColor: _primaryTeal.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Masuk Sekarang',
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

              const SizedBox(height: 20),

              // Hubungi Admin untuk Pendaftaran Akun
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Belum punya akun? ',
                    style: TextStyle(fontSize: 13, color: _secondaryText),
                  ),
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
                          'Hubungi Admin untuk Daftar',
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
      ),
    );
  }
}
