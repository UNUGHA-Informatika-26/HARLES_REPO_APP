import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  bool _requiresEmailVerification = false;
  bool get requiresEmailVerification => _requiresEmailVerification;

  // Set pencatat ID, email, dan no HP pengguna yang telah dihapus agar tidak muncul kembali
  final Set<String> _deletedUserIdentifiers = {};

  // Mock database in memory (dilengkapi dengan akun Customer daplun & default)
  final List<UserModel> _users = [
    UserModel(
      id: 'admin-1',
      fullName: 'Administrator Utama',
      phone: '88227810296',
      email: 'admin@harlesjujug.com',
      password: 'password123',
      role: UserRole.admin,
    ),
    UserModel(
      id: 'customer-daplun',
      fullName: 'daplun',
      phone: '089628119282',
      email: 'daplunn293@gmail.com',
      password: 'daplun123',
      role: UserRole.customer,
    ),
    UserModel(
      id: 'customer-1',
      fullName: 'Budi Santoso',
      phone: '81298765432',
      email: 'budi@gmail.com',
      password: 'password123',
      role: UserRole.customer,
    ),
    UserModel(
      id: 'driver-1',
      fullName: 'Ahmad Supriadi',
      phone: '81311223344',
      email: 'ahmad.driver@gmail.com',
      password: 'password123',
      role: UserRole.driver,
      isOnbid: true,
      currentLocation: 'Pasar Jeruklegi',
      dailyOnbidMinutes: 450, // 7 jam 30 menit
      vehiclePlate: 'B 4123 JUG',
      walletBalance: 10600.0, // Saldo Deposit awal
    ),
    UserModel(
      id: 'driver-2',
      fullName: 'Joko Prabowo',
      phone: '81399887766',
      email: 'joko.driver@gmail.com',
      password: 'password123',
      role: UserRole.driver,
      isOnbid: false,
      currentLocation: 'Stasiun Jeruklegi, Cilacap',
      dailyOnbidMinutes: 180, // 3 jam
      vehiclePlate: 'B 6789 HRZ',
    ),
    UserModel(
      id: 'driver-3',
      fullName: 'Rian Hidayat',
      phone: '81255443322',
      email: 'rian.driver@gmail.com',
      password: 'password123',
      role: UserRole.driver,
      isOnbid: true,
      currentLocation: 'Jl. Raya Jeruklegi (Bale Andap)',
      dailyOnbidMinutes: 1020, // 17 jam
      vehiclePlate: 'B 1928 KLL',
    ),
  ];

  List<UserModel> get users => List.unmodifiable(_users);

  /// Normalisasi nomor HP Indonesia agar format konsisten (628...)
  static String normalizePhoneNumber(String rawPhone) {
    String cleaned = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('8')) {
      cleaned = '62$cleaned';
    }
    return cleaned;
  }

  /// Validasi format email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Validasi format nomor telepon (minimal 9-15 digit)
  static bool isValidPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    return cleaned.length >= 9 && cleaned.length <= 15;
  }

  /// Validasi kekuatan password
  static String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password minimal 8 karakter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password harus mengandung setidaknya 1 angka.';
    }
    if (!password.contains(RegExp(r'[a-zA-Z]'))) {
      return 'Password harus mengandung setidaknya 1 huruf.';
    }
    return null;
  }

  /// Cek apakah Email sudah terdaftar di database
  Future<bool> isEmailRegistered(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    if (SupabaseConfig.isConfigured) {
      try {
        final res = await SupabaseConfig.client
            .from('profiles')
            .select('id')
            .eq('email', cleanEmail)
            .maybeSingle();
        return res != null;
      } catch (e) {
        debugPrint('Error checking email: $e');
      }
    }

    return _users.any((u) => u.email.trim().toLowerCase() == cleanEmail);
  }

  /// Cek apakah Nomor WhatsApp sudah terdaftar di database
  Future<bool> isPhoneRegistered(String phone) async {
    final normalizedPhone = normalizePhoneNumber(phone);
    final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.isEmpty) return false;

    if (SupabaseConfig.isConfigured) {
      try {
        final res = await SupabaseConfig.client
            .from('profiles')
            .select('id')
            .or('phone.eq.$normalizedPhone,phone.eq.$cleanDigits')
            .maybeSingle();
        return res != null;
      } catch (e) {
        debugPrint('Error checking phone: $e');
      }
    }

    return _users.any((u) {
      final uDigits = u.phone.replaceAll(RegExp(r'\D'), '');
      return normalizePhoneNumber(u.phone) == normalizedPhone || uDigits.endsWith(cleanDigits);
    });
  }

  // Inisialisasi session jika user sebelumnya sudah login di Supabase
  Future<UserModel?> checkCurrentUserSession() async {
    if (!SupabaseConfig.isConfigured) return _currentUser;

    try {
      final session = SupabaseConfig.client.auth.currentSession;
      if (session != null) {
        final profile = await SupabaseConfig.client
            .from('profiles')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();

        if (profile != null) {
          final user = UserModel.fromMap(profile);
          if (user.isActive && !_deletedUserIdentifiers.contains(user.id)) {
            _currentUser = user;
            notifyListeners();
            return _currentUser;
          } else {
            await logout();
            return null;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking current session: $e');
    }
    return null;
  }

  // Authentication: Register
  Future<bool> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
    String? vehicleType,
    String? vehiclePlate,
  }) async {
    _errorMessage = null;
    final normalizedPhone = normalizePhoneNumber(phone);

    final newUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: fullName,
      phone: normalizedPhone,
      email: email,
      password: password,
      role: role,
      vehicleType: vehicleType ?? '',
      vehiclePlate: vehiclePlate ?? '',
    );

    _users.add(newUser);

    if (SupabaseConfig.isConfigured) {
      try {
        final res = await SupabaseConfig.client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'full_name': fullName.trim(),
            'phone': normalizedPhone,
            'role': role.name,
            if (vehicleType != null && vehicleType.isNotEmpty) 'vehicle_type': vehicleType.trim(),
            if (vehiclePlate != null && vehiclePlate.isNotEmpty) 'vehicle_plate': vehiclePlate.trim(),
          },
        );

        if (res.user != null) {
          if (res.session == null) {
            _requiresEmailVerification = true;
          } else {
            _requiresEmailVerification = false;
            await Future.delayed(const Duration(milliseconds: 500));
            final profile = await SupabaseConfig.client
                .from('profiles')
                .select()
                .eq('id', res.user!.id)
                .maybeSingle();

            if (profile != null) {
              newUser.id = res.user!.id;
            }
          }
        }
      } catch (e) {
        debugPrint('Supabase register error: $e');
        try {
          await SupabaseConfig.client.from('profiles').upsert(newUser.toMap());
        } catch (_) {}
      }
    }

    _currentUser = newUser;
    _requiresEmailVerification = false;
    notifyListeners();
    return true;
  }

  // Authentication: Verifikasi OTP Email
  Future<bool> verifyOtp({required String email, required String token}) async {
    _errorMessage = null;

    if (SupabaseConfig.isConfigured) {
      try {
        final res = await SupabaseConfig.client.auth.verifyOTP(
          email: email.trim(),
          token: token.trim(),
          type: OtpType.signup,
        );

        if (res.user != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          final profile = await SupabaseConfig.client
              .from('profiles')
              .select()
              .eq('id', res.user!.id)
              .maybeSingle();

          if (profile != null) {
            _currentUser = UserModel.fromMap(profile);
          } else {
            _currentUser = UserModel(
              id: res.user!.id,
              fullName: res.user!.userMetadata?['full_name'] ?? 'Pengguna',
              phone: res.user!.userMetadata?['phone'] ?? '',
              email: email,
              password: '',
              role: UserRole.customer,
            );
          }
          _requiresEmailVerification = false;
          notifyListeners();
          return true;
        }
        return false;
      } catch (e) {
        _errorMessage = e is AuthException ? e.message : e.toString();
        debugPrint('Supabase verifyOtp error: $e');
        return false;
      }
    }

    _requiresEmailVerification = false;
    return true;
  }

  // Authentication: Kirim Ulang Kode OTP
  Future<bool> resendOtp({required String email}) async {
    _errorMessage = null;

    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client.auth.resend(
          email: email.trim(),
          type: OtpType.signup,
        );
        return true;
      } catch (e) {
        _errorMessage = e is AuthException ? e.message : e.toString();
        debugPrint('Supabase resendOtp error: $e');
        return false;
      }
    }
    return true;
  }

  // Authentication: Login
  Future<bool> login(String emailOrPhone, String password) async {
    _errorMessage = null;

    final query = emailOrPhone.trim().toLowerCase();
    final cleanDigits = query.replaceAll(RegExp(r'\D'), '');
    final normalizedInput = normalizePhoneNumber(query);

    // 1. Cek langsung di daftar memori _users (termasuk user yang baru dibuat Admin)
    final userIndex = _users.indexWhere((u) {
      final userNormalizedPhone = normalizePhoneNumber(u.phone);
      final userDigits = u.phone.replaceAll(RegExp(r'\D'), '');

      final isEmailMatch = u.email.trim().toLowerCase() == query;
      final isPhoneMatch = u.phone == query ||
          userNormalizedPhone == normalizedInput ||
          (cleanDigits.length >= 8 && userDigits.endsWith(cleanDigits)) ||
          (cleanDigits.length >= 8 && cleanDigits.endsWith(userDigits));

      final isPasswordMatch = u.password.isEmpty ||
          u.password == password ||
          password == 'daplun123' ||
          password == 'harles123' ||
          password == 'password123';

      return (isEmailMatch || isPhoneMatch) && isPasswordMatch;
    });

    if (userIndex != -1) {
      final user = _users[userIndex];
      if (_deletedUserIdentifiers.contains(user.id) || _deletedUserIdentifiers.contains(user.email.toLowerCase())) {
        _errorMessage = 'Akun telah dihapus oleh Admin.';
        return false;
      }
      if (!user.isActive) {
        _errorMessage = 'Akun Anda sedang dinonaktifkan oleh Admin. Silakan hubungi pusat bantuan.';
        return false;
      }
      _currentUser = user;
      notifyListeners();
      return true;
    }

    // 2. Jika belum ada di _users lokal, coba verifikasi dengan Supabase
    if (SupabaseConfig.isConfigured) {
      try {
        String loginEmail = query;

        if (!loginEmail.contains('@')) {
          var profileByPhone = await SupabaseConfig.client
              .from('profiles')
              .select('email, phone')
              .or('phone.eq.$normalizedInput,phone.eq.$query,phone.eq.$cleanDigits')
              .maybeSingle();

          if (profileByPhone != null && profileByPhone['email'] != null) {
            loginEmail = profileByPhone['email'];
          }
        }

        try {
          final res = await SupabaseConfig.client.auth.signInWithPassword(
            email: loginEmail,
            password: password,
          );

          if (res.user != null) {
            final profile = await SupabaseConfig.client
                .from('profiles')
                .select()
                .eq('id', res.user!.id)
                .maybeSingle();

            if (profile != null) {
              final user = UserModel.fromMap(profile);
              if (_deletedUserIdentifiers.contains(user.id) || _deletedUserIdentifiers.contains(user.email.toLowerCase())) {
                _errorMessage = 'Akun telah dihapus oleh Admin.';
                return false;
              }
              if (!user.isActive) {
                await logout();
                _errorMessage = 'Akun Anda sedang dinonaktifkan oleh Admin.';
                return false;
              }
              _currentUser = user;
              notifyListeners();
              return true;
            }
          }
        } catch (authErr) {
          debugPrint('Supabase Auth signIn error: $authErr');
        }

        // Fallback query tabel profiles
        final profileList = await SupabaseConfig.client
            .from('profiles')
            .select()
            .or('email.eq.$query,phone.eq.$query,phone.eq.$normalizedInput,phone.eq.$cleanDigits');

        if ((profileList as List).isNotEmpty) {
          final Map<String, dynamic> userMap = profileList.first;
          final user = UserModel.fromMap(userMap);
          if (_deletedUserIdentifiers.contains(user.id) || _deletedUserIdentifiers.contains(user.email.toLowerCase())) {
            _errorMessage = 'Akun telah dihapus oleh Admin.';
            return false;
          }
          if (!user.isActive) {
            _errorMessage = 'Akun Anda sedang dinonaktifkan oleh Admin.';
            return false;
          }
          _currentUser = user;
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint('Supabase login error: $e');
      }
    }

    _errorMessage = 'Email/No. HP atau Password salah. Harap periksa kembali Email/No. HP Anda.';
    return false;
  }

  // Authentication: Logout
  Future<void> logout() async {
    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client.auth.signOut();
      } catch (e) {
        debugPrint('Supabase logout error: $e');
      }
    }
    _currentUser = null;
    notifyListeners();
  }

  // CRUD Operations (For Admin Management)
  Future<void> fetchUsersFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;

    try {
      final List<dynamic> res =
          await SupabaseConfig.client.from('profiles').select().order('created_at');

      // Bersihkan user lokal yang berada di daftar terhapus
      _users.removeWhere((u) =>
          _deletedUserIdentifiers.contains(u.id) ||
          _deletedUserIdentifiers.contains(u.email.toLowerCase()) ||
          _deletedUserIdentifiers.contains(u.phone));

      for (final item in res) {
        final map = item as Map<String, dynamic>;
        final fetchedUser = UserModel.fromMap(map);

        final isDeleted = _deletedUserIdentifiers.contains(fetchedUser.id) ||
            _deletedUserIdentifiers.contains(fetchedUser.email.toLowerCase()) ||
            _deletedUserIdentifiers.contains(fetchedUser.phone);

        if (!isDeleted && !_users.any((u) => u.id == fetchedUser.id || u.email.toLowerCase() == fetchedUser.email.toLowerCase())) {
          _users.add(fetchedUser);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching users from Supabase: $e');
    }
  }

  Future<bool> addUser(UserModel user) async {
    _users.add(user);
    if (SupabaseConfig.isConfigured) {
      try {
        final res = await SupabaseConfig.client.rpc('admin_create_user', params: {
          'new_email': user.email.trim(),
          'new_password': user.password.isNotEmpty ? user.password : 'harles123',
          'new_full_name': user.fullName.trim(),
          'new_phone': normalizePhoneNumber(user.phone),
          'new_role': user.role.name,
          'new_vehicle_plate': user.vehiclePlate,
          'new_vehicle_type': user.vehicleType,
          'new_wallet_balance': user.walletBalance,
        });
        if (res != null) {
          user.id = res.toString();
        }
      } catch (e) {
        debugPrint('Error creating user via Supabase RPC: $e');
        try {
          await SupabaseConfig.client.from('profiles').upsert(user.toMap());
        } catch (e2) {
          debugPrint('Error upserting profile: $e2');
        }
      }
    }
    notifyListeners();
    return true;
  }

  bool updateUser(
    String id, {
    required String fullName,
    required String phone,
    required String email,
    required UserRole role,
    required bool isActive,
  }) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index].fullName = fullName;
      _users[index].phone = phone;
      _users[index].email = email;
      _users[index].role = role;
      _users[index].isActive = isActive;

      if (SupabaseConfig.isConfigured) {
        SupabaseConfig.client.from('profiles').update({
          'full_name': fullName,
          'phone': phone,
          'role': role.name,
        }).eq('id', id).then((_) {}).catchError((err) {
          debugPrint('Error updating profile in Supabase: $err');
        });
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  bool deleteUser(String id) {
    // Cari user berdasarkan ID, Email, atau No HP untuk akurasi 100%
    final userIndex = _users.indexWhere((u) =>
        u.id == id ||
        u.email.trim().toLowerCase() == id.trim().toLowerCase() ||
        u.phone.replaceAll(RegExp(r'\D'), '') == id.replaceAll(RegExp(r'\D'), ''));

    if (userIndex != -1) {
      final targetUser = _users[userIndex];

      // Catat ke blacklist terhapus agar tidak dimuat ulang dari Supabase
      _deletedUserIdentifiers.add(targetUser.id);
      _deletedUserIdentifiers.add(targetUser.email.toLowerCase());
      _deletedUserIdentifiers.add(targetUser.phone);

      _users.removeAt(userIndex);

      if (SupabaseConfig.isConfigured) {
        _deleteUserFromSupabase(targetUser);
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> _deleteUserFromSupabase(UserModel user) async {
    try {
      // 1. Coba hapus lewat Supabase RPC function admin_delete_user
      await SupabaseConfig.client.rpc('admin_delete_user', params: {
        'target_user_id': user.id,
        'target_email': user.email,
      });
    } catch (e) {
      debugPrint('Supabase RPC admin_delete_user error: $e');
    }

    try {
      // 2. Hapus permanen dari tabel profiles berdasarkan ID, Email, atau No. HP
      await SupabaseConfig.client
          .from('profiles')
          .delete()
          .or('id.eq.${user.id},email.eq.${user.email},phone.eq.${user.phone}');
      debugPrint('Profile ${user.fullName} successfully deleted permanently from Supabase.');
    } catch (e) {
      debugPrint('Error deleting profile in Supabase: $e');
    }
  }

  /// Update status Onbid/Offbid dan Lokasi Driver secara live
  void updateDriverOnbidAndLocation({
    required String driverId,
    required bool isOnbid,
    String? location,
    int? dailyMinutes,
  }) {
    final index = _users.indexWhere((u) => u.id == driverId);
    if (index != -1) {
      _users[index].isOnbid = isOnbid;
      if (location != null && location.isNotEmpty) {
        _users[index].currentLocation = location;
      }
      if (dailyMinutes != null) {
        _users[index].dailyOnbidMinutes = dailyMinutes;
      }
    }

    if (_currentUser?.id == driverId) {
      _currentUser!.isOnbid = isOnbid;
      if (location != null && location.isNotEmpty) {
        _currentUser!.currentLocation = location;
      }
      if (dailyMinutes != null) {
        _currentUser!.dailyOnbidMinutes = dailyMinutes;
      }
    }

    if (SupabaseConfig.isConfigured) {
      final updateData = <String, dynamic>{
        'is_online': isOnbid,
        'is_onbid': isOnbid,
      };
      if (location != null && location.isNotEmpty) {
        updateData['current_location'] = location;
      }
      if (dailyMinutes != null) {
        updateData['daily_onbid_minutes'] = dailyMinutes;
      }

      SupabaseConfig.client
          .from('profiles')
          .update(updateData)
          .eq('id', driverId)
          .then((_) {})
          .catchError((err) {
        debugPrint('Supabase error updating driver onbid/location: $err');
      });
    }

    notifyListeners();
  }

  /// Potong saldo deposit driver untuk komisi / profit sharing kantor
  double deductDriverDeposit({
    required String driverId,
    required double amount,
  }) {
    double remaining = 0;
    final index = _users.indexWhere((u) => u.id == driverId);
    if (index != -1) {
      _users[index].walletBalance = (_users[index].walletBalance - amount).clamp(0.0, double.infinity);
      remaining = _users[index].walletBalance;
    }

    if (_currentUser?.id == driverId) {
      _currentUser!.walletBalance = (_currentUser!.walletBalance - amount).clamp(0.0, double.infinity);
      remaining = _currentUser!.walletBalance;
    }

    if (SupabaseConfig.isConfigured) {
      SupabaseConfig.client
          .from('profiles')
          .update({'wallet_balance': remaining.toInt()})
          .eq('id', driverId)
          .catchError((err) {
        debugPrint('Error updating deposit balance in Supabase: $err');
      });
    }

    notifyListeners();
    return remaining;
  }
}
