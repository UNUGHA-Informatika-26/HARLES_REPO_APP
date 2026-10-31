import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import 'customer_dashboard.dart';
import 'driver_dashboard.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  UserRole _selectedRole = UserRole.customer;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _vehiclePlateController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _isLoading = false;

  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _inputBorder = Color(0xFFE2E8F0);
  static const Color _tabBg = Color(0xFFF1F5F9);

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return;

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final vehicleType = _vehicleTypeController.text.trim();
    final vehiclePlate = _vehiclePlateController.text.trim();

    if (fullName.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data pendaftaran.')),
      );
      return;
    }

    if (fullName.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama lengkap minimal 3 karakter.')),
      );
      return;
    }

    if (!AuthService.isValidPhoneNumber(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp tidak valid (harus 9-15 digit angka).')),
      );
      return;
    }

    if (!AuthService.isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format email tidak valid (contoh: nama@domain.com).')),
      );
      return;
    }

    final passwordError = AuthService.validatePassword(password);
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(passwordError)),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password dan Konfirmasi Password tidak cocok.')),
      );
      return;
    }

    if (_selectedRole == UserRole.driver && (vehiclePlate.isEmpty || vehicleType.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi plat nomor dan jenis kendaraan driver.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Cek apakah Email sudah terdaftar
      final isEmailTaken = await AuthService().isEmailRegistered(email);
      if (!mounted) return;
      if (isEmailTaken) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Email ini sudah terdaftar. Silakan gunakan email lain atau langsung Login.'),
          ),
        );
        return;
      }

      // 2. Cek apakah Nomor WhatsApp sudah terdaftar
      final isPhoneTaken = await AuthService().isPhoneRegistered(phone);
      if (!mounted) return;
      if (isPhoneTaken) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Nomor WhatsApp ini sudah terdaftar. Silakan gunakan nomor lain atau langsung Login.'),
          ),
        );
        return;
      }

      final success = await AuthService().register(
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
        role: _selectedRole,
        vehicleType: _selectedRole == UserRole.driver ? vehicleType : null,
        vehiclePlate: _selectedRole == UserRole.driver ? vehiclePlate : null,
      );

      if (!mounted) return;

      if (success) {
        if (AuthService().requiresEmailVerification) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: _primaryTeal,
              content: Text('Kode OTP verifikasi telah dikirimkan ke email Anda.'),
            ),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyEmailScreen(
                email: email,
                role: _selectedRole,
              ),
            ),
          );
          return;
        }

        final roleLabel = _selectedRole == UserRole.driver ? 'Mitra Driver' : 'Pelanggan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pendaftaran $roleLabel berhasil!')),
        );

        Widget targetDashboard = _selectedRole == UserRole.driver
            ? const DriverDashboardScreen()
            : const CustomerDashboardScreen();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => targetDashboard),
          (route) => false,
        );
      } else {
        final errorMsg = AuthService().errorMessage ?? 'Email sudah terdaftar. Silakan gunakan email lain.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
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
              // 1. Top Header Bar with New Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.maybePop(context);
                    },
                    icon: const Icon(Icons.arrow_back, color: _darkText),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                  // Brand Logo Header
                  const AppLogo(size: 34),

                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: _secondaryText,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. Title & Subtitle
              Text(
                _selectedRole == UserRole.driver
                    ? 'Daftar Mitra Driver'
                    : 'Daftar Akun Pelanggan',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedRole == UserRole.driver
                    ? 'Bergabung menjadi mitra driver Harles Jujug.'
                    : 'Semua kebutuhan harian, dalam satu aplikasi.',
                style: const TextStyle(
                  fontSize: 14,
                  color: _secondaryText,
                ),
              ),

              const SizedBox(height: 24),

              // 3. Tab Selector Role (Customer / Mitra Driver)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _tabBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [UserRole.customer, UserRole.driver].map((role) {
                    final bool isSelected = _selectedRole == role;
                    final String displayLabel =
                        role == UserRole.customer ? '👤 Pelanggan' : '🛵 Mitra Driver';
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRole = role;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSelected ? _primaryTeal : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            displayLabel,
                            style: TextStyle(
                              color: isSelected ? Colors.white : _secondaryText,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // 4. Input Fields
              _buildInputLabel('Full Name'),
              const SizedBox(height: 6),
              TextField(
                controller: _fullNameController,
                decoration: _buildInputDecoration(
                  hintText: 'Nama lengkap Anda',
                ),
              ),

              const SizedBox(height: 16),

              _buildInputLabel('WhatsApp Number'),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _buildInputDecoration(
                  hintText: '812 3456 7890',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '+62',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 1,
                          height: 20,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _buildInputLabel('Email'),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(
                  hintText: 'nama@email.com',
                ),
              ),

              if (_selectedRole == UserRole.driver) ...[
                const SizedBox(height: 16),
                _buildInputLabel('Merk & Model Kendaraan'),
                const SizedBox(height: 6),
                TextField(
                  controller: _vehicleTypeController,
                  decoration: _buildInputDecoration(
                    hintText: 'Contoh: Honda Vario 160 / Daihatsu Sigra',
                    prefixIcon: const Icon(Icons.two_wheeler_rounded, color: _secondaryText, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInputLabel('Nomor Plat Kendaraan'),
                const SizedBox(height: 6),
                TextField(
                  controller: _vehiclePlateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _buildInputDecoration(
                    hintText: 'Contoh: B 1234 XYZ',
                    prefixIcon: const Icon(Icons.badge_rounded, color: _secondaryText, size: 20),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              _buildInputLabel('Password'),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _isPasswordObscured,
                decoration: _buildInputDecoration(
                  hintText: 'Minimal 8 karakter',
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
                ),
              ),

              const SizedBox(height: 16),

              _buildInputLabel('Konfirmasi Password'),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _isConfirmPasswordObscured,
                decoration: _buildInputDecoration(
                  hintText: 'Ulangi password Anda',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _secondaryText,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 5. Terms & Privacy Notice
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(
                      Icons.shield_outlined,
                      color: _primaryTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: _secondaryText,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(text: 'Dengan mendaftar, Anda menyetujui '),
                          TextSpan(
                            text: 'Syarat & Ketentuan',
                            style: const TextStyle(
                              color: _darkTeal,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () {},
                          ),
                          const TextSpan(text: ' dan '),
                          TextSpan(
                            text: 'Kebijakan Privasi',
                            style: const TextStyle(
                              color: _darkTeal,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () {},
                          ),
                          const TextSpan(text: ' kami.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 6. Submit Button ("Daftar Sekarang")
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                              'Daftar Sekarang',
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

              // 7. Footer Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sudah punya akun? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: _secondaryText,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Masuk (Login)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _darkTeal,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: _darkText,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
      ),
      filled: true,
      fillColor: _lightBg,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _inputBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryTeal, width: 1.5),
      ),
    );
  }
}
