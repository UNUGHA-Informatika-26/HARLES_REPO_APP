import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import 'admin_dashboard.dart';
import 'customer_dashboard.dart';
import 'driver_dashboard.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final UserRole? role;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.role,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _inputBorder = Color(0xFFCBD5E1);

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() {
      _resendCooldown = 60;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode =>
      _otpControllers.map((controller) => controller.text).join();

  Future<void> _handleVerify() async {
    final code = _otpCode;
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap masukkan 6 digit kode OTP verifikasi.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await AuthService().verifyOtp(
        email: widget.email,
        token: code,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Email berhasil diverifikasi! Selamat datang di Harles Jujug.'),
          ),
        );

        final user = AuthService().currentUser;
        final targetRole = user?.role ?? widget.role ?? UserRole.customer;

        Widget targetScreen;
        switch (targetRole) {
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
        final errorMsg = AuthService().errorMessage ?? 'Kode OTP salah atau telah kadaluarsa.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(errorMsg),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final success = await AuthService().resendOtp(email: widget.email);

      if (!mounted) return;

      if (success) {
        _startCooldownTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: _primaryTeal,
            content: Text('Kode OTP baru telah dikirimkan ke email Anda.'),
          ),
        );
      } else {
        final errorMsg = AuthService().errorMessage ?? 'Gagal mengirim ulang kode OTP.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Row
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

              const SizedBox(height: 36),

              // Animated/Highlighted Icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: _primaryTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    color: _darkTeal,
                    size: 46,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              const Text(
                'Verifikasi Email Anda',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'Masukkan 6 digit kode OTP yang kami kirimkan ke email:',
                style: TextStyle(
                  fontSize: 14,
                  color: _secondaryText,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Email Badge Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _darkTeal,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 6-Digit OTP Input Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verifikasi & Lanjut Masuk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend Code Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Belum menerima kode? ',
                    style: TextStyle(fontSize: 13, color: _secondaryText),
                  ),
                  if (_resendCooldown > 0)
                    Text(
                      'Tunggu $_resendCooldown s',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _darkTeal,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _isResending ? null : _handleResend,
                      child: Text(
                        _isResending ? 'Mengirim...' : 'Kirim Ulang Kode',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _primaryTeal,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text(
                  'Ganti Email atau Kembali',
                  style: TextStyle(color: _secondaryText, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 46,
      height: 54,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _darkText,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _lightBg,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryTeal, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_otpCode.length == 6) {
            _handleVerify();
          }
        },
      ),
    );
  }
}
