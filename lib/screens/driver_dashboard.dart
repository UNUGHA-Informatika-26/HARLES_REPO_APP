import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/branded_background.dart';
import '../widgets/live_map_view.dart';
import 'splash_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();

  late bool _isOnbid;
  late String _currentLocation;
  late int _dailyOnbidMinutes; // Total menit onbid hari ini (Maksimal 18 jam = 1080 menit)
  static const int _maxDailyMinutes = 18 * 60; // 1080 menit

  Timer? _onbidTimer;

  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    final driver = _authService.currentUser;
    _isOnbid = driver?.isOnbid ?? true;
    _currentLocation = driver?.currentLocation ?? 'Pusat Kota Harles';
    _dailyOnbidMinutes = driver?.dailyOnbidMinutes ?? 450; // Default simulasi: 7.5 jam

    _orderService.addListener(_onServiceUpdate);
    _authService.addListener(_onServiceUpdate);
    _orderService.initRealtimeOrders();

    // Timer internal untuk melacak durasi Onbid secara live
    _startOnbidTracking();
  }

  @override
  void dispose() {
    _onbidTimer?.cancel();
    _orderService.removeListener(_onServiceUpdate);
    _authService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _startOnbidTracking() {
    _onbidTimer?.cancel();
    // Melacak durasi Onbid secara kontinu tanpa batasan 8 jam WA
    _onbidTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) return;
      if (_isOnbid) {
        setState(() {
          _dailyOnbidMinutes += 1;
        });

        // Sinkronisasi berkala lokasi & status ke database
        _syncDriverStatus();
      }
    });
  }

  void _syncDriverStatus() {
    final driver = _authService.currentUser;
    if (driver != null) {
      _authService.updateDriverOnbidAndLocation(
        driverId: driver.id,
        isOnbid: _isOnbid,
        location: _currentLocation,
        dailyMinutes: _dailyOnbidMinutes,
      );
    }
  }

  /// Tindakan otomatis saat melebihi batas Onbid 18 jam
  void _enforceRestLimit() {
    if (!_isOnbid) return;

    setState(() {
      _isOnbid = false;
    });

    _syncDriverStatus();

    // Tampilkan Peringatan Wajib Istirahat
    _showRestExceededDialog();
  }

  void _showRestExceededDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Jaga Kesehatan & Keselamatan Driver di Jalan!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bedtime_rounded, color: Colors.red, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Waktu Onbid Anda telah mencapai 18 Jam (Batas Maksimal Harian).',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Demi menjaga kesehatan tubuh dan keselamatan Anda selama berkendara di jalan raya, sistem telah menonaktifkan status Onbid secara otomatis.\n\nSilakan istirahat yang cukup untuk memulihkan stamina. Ingat, ada keluarga tercinta yang menanti Anda di rumah dengan selamat! ❤️🛵',
                style: TextStyle(fontSize: 13, height: 1.45, color: _darkText),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Saya Mengerti & Siap Beristirahat',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleOnbid(bool val) {
    if (val) {
      // Jika mencoba Onbid padahal sudah >= 18 jam
      if (_dailyOnbidMinutes >= _maxDailyMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              '⚠️ Tidak dapat Onbid! Anda telah mencapai batas maksimal 18 jam kerja hari ini. Mohon beristirahat.',
            ),
          ),
        );
        _showRestExceededDialog();
        return;
      }
    }

    setState(() {
      _isOnbid = val;
    });

    _syncDriverStatus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isOnbid ? _primaryTeal : Colors.grey.shade700,
        content: Row(
          children: [
            Icon(_isOnbid ? Icons.check_circle_outline : Icons.pause_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              _isOnbid
                  ? 'Status ONBID aktif. Anda siap menerima order dari Admin!'
                  : 'Status OFFBID. Anda sedang beristirahat & tidak menerima order.',
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeLocationDialog() {
    final popularLocations = [
      'Jl. Raya Jeruklegi (Pusat)',
      'Pasar Jeruklegi',
      'Stasiun Jeruklegi',
      'SPBU Jeruklegi',
      'Jl. Raya Kawunganten',
      'Pos Pantau Jujug Jeruklegi',
      'Alun-alun Cilacap',
      'Terminal Bus Cilacap',
      'RSUD Cilacap',
      'Simpang Lima Cilacap',
    ];

    final customController = TextEditingController(text: _currentLocation);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.location_on, color: _primaryTeal),
                  SizedBox(width: 8),
                  Text('Update Lokasi Driver', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lokasi Anda akan terhubung langsung ke Admin untuk penugasan order:',
                      style: TextStyle(fontSize: 12, color: _secondaryText),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customController,
                      decoration: InputDecoration(
                        labelText: 'Nama Lokasi Terkini',
                        hintText: 'Contoh: Jl. Diponegoro No. 8',
                        prefixIcon: const Icon(Icons.my_location, color: _primaryTeal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Pilihan Lokasi Cepat:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: popularLocations.map((loc) {
                        final isSelected = customController.text == loc;
                        return ChoiceChip(
                          label: Text(loc, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : _darkText)),
                          selected: isSelected,
                          selectedColor: _primaryTeal,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                customController.text = loc;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryTeal),
                  onPressed: () {
                    final newLoc = customController.text.trim();
                    if (newLoc.isNotEmpty) {
                      setState(() {
                        _currentLocation = newLoc;
                      });
                      _syncDriverStatus();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lokasi driver diperbarui ke: $newLoc (Tersambung ke Admin)')),
                      );
                    }
                  },
                  child: const Text('Simpan Lokasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- HELPER TESTING: Tambah 1 jam / Tes 18 Jam / Reset ---
  void _simulateAddHour() {
    setState(() {
      _dailyOnbidMinutes += 60;
    });
    _syncDriverStatus();
    if (_dailyOnbidMinutes >= _maxDailyMinutes) {
      _enforceRestLimit();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Simulasi: Ditambah 1 jam Onbid (Total: ${_dailyOnbidMinutes ~/ 60} jam ${_dailyOnbidMinutes % 60} menit)')),
      );
    }
  }

  void _simulateMaxLimit() {
    setState(() {
      _dailyOnbidMinutes = _maxDailyMinutes;
    });
    _syncDriverStatus();
    _enforceRestLimit();
  }

  void _resetDailyHours() {
    setState(() {
      _dailyOnbidMinutes = 0;
      _isOnbid = true;
    });
    _syncDriverStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Jam kerja harian di-reset ke 0 jam. Anda dapat Onbid kembali!')),
    );
  }

  // --- DIALOG PENGISIAN SALDO DEPOSIT VIA DANA HARLES JUJUG ---
  void _showDanaTopUpDialog(UserModel? driver) {
    final nominalController = TextEditingController(text: '50000');
    final quickNominals = [20000, 50000, 100000, 200000];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF118EEA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF118EEA), size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Top Up DANA Harles Jujug', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Isi Saldo Deposit Driver', style: TextStyle(fontSize: 11, color: _secondaryText)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kartu Rekening Akun DANA Harles Jujug
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF118EEA), Color(0xFF0C69B0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF118EEA).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'DANA HARLES JUJUG',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Akun Resmi', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Nomor Akun DANA Harles Jujug:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '0812-3456-7890',
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                                tooltip: 'Salin Nomor DANA',
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: '088227810296'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Nomor DANA 088227810296 berhasil disalin!')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'a.n. Harles Jujug Official',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text('Pilih Nominal Top Up:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkText)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickNominals.map((nom) {
                        final isSelected = nominalController.text == nom.toString();
                        return ChoiceChip(
                          label: Text(
                            'Rp ${nom ~/ 1000}rb',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF118EEA),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF118EEA),
                          backgroundColor: const Color(0xFF118EEA).withValues(alpha: 0.1),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                nominalController.text = nom.toString();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: nominalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nominal Transfer (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Petunjuk Top Up:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkText)),
                          SizedBox(height: 4),
                          Text('1. Buka aplikasi DANA Anda & transfer ke nomor di atas.', style: TextStyle(fontSize: 11, color: _secondaryText)),
                          Text('2. Screenshot bukti transfer berhasil.', style: TextStyle(fontSize: 11, color: _secondaryText)),
                          Text('3. Klik tombol hijau di bawah untuk konfirmasi ke Admin WA.', style: TextStyle(fontSize: 11, color: _secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                  label: const Text(
                    'Kirim Bukti ke Admin WA 📲',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () {
                    final nominal = nominalController.text.trim();
                    Navigator.pop(context);
                    final msg = 'Halo Admin Harles Jujug, saya Driver ${driver?.fullName ?? "Driver"} (${driver?.phone ?? ""}) telah mentransfer pengisian saldo deposit driver via DANA Harles Jujug (0882-2781-0296) sebesar Rp $nominal.\n\nBerikut bukti transfernya, mohon segera ditambahkan ke saldo akun saya. Terima kasih! 🙏🛵';
                    WhatsAppService.openWhatsApp(phone: WhatsAppService.adminPhone, message: msg);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIALOG PENJELASAN SKEMA PROFIT SHARING 20% ---
  void _showProfitSharingInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: _primaryTeal, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Skema Profit Sharing 20%',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sistem Bagi Hasil Resmi Harles Jujug:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _darkText),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• Pendapatan Bersih Driver:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('80% Ongkir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• Komisi Instansi Jujug:', style: TextStyle(fontSize: 12, color: Colors.red)),
                        Text('20% Ongkir', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• Biaya Administrasi:', style: TextStyle(fontSize: 12, color: Colors.red)),
                        Text('Rp 500,-', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 Catatan Penting:\n'
                '1. Customer membayar 100% tunai/cash langsung kepada Anda (Driver).\n'
                '2. Anda memegang seluruh uang tunai dari customer.\n'
                '3. Begitu orderan Anda tandai selesai di aplikasi, sistem otomatis memotong 20% + Adm Rp 500 dari Saldo Deposit Driver Anda.\n'
                '4. Pastikan saldo deposit Anda selalu mencukupi (minimal Rp 2.100).',
                style: TextStyle(fontSize: 11, color: _secondaryText, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG KONFIRMASI PENYELESAIAN ORDER & PEMOTONGAN PROFIT SHARING 20% OTOMATIS ---
  void _showCompleteOrderConfirmation(OrderModel order) {
    final driver = _authService.currentUser;
    if (driver == null) return;

    final double ongkir = order.deliveryFee;
    final double profitSharing = order.profitSharingAmount; // 20%
    final double totalPotongan = order.totalCommissionDeduction; // 20% + Adm
    final double saldoSebelum = driver.walletBalance;
    final double saldoSesudah = (saldoSebelum - totalPotongan).clamp(0.0, double.infinity);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Selesaikan Orderan & Bagi Hasil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.id} (${order.serviceType})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkTeal),
                ),
                Text(
                  'Customer: ${order.customerName}',
                  style: const TextStyle(fontSize: 12, color: _secondaryText),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Tagih Tunai (Cash):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('Rp ${order.totalCustomerBill.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _darkTeal)),
                        ],
                      ),
                      if (order.outletCost > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('• Belanja Outlet (Talangan):', style: TextStyle(fontSize: 11, color: _secondaryText)),
                            Text('Rp ${order.outletCost.toInt()}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('• Tarif Jujug (Ongkir):', style: TextStyle(fontSize: 11, color: _secondaryText)),
                          Text('Rp ${ongkir.toInt()}', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('• Ongkir Bersih Driver (80%):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                          Text('Rp ${order.driverNetEarnings.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Potongan Profit Sharing (20%):', style: TextStyle(fontSize: 11, color: Colors.red)),
                          Text('-Rp ${profitSharing.toInt()}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Biaya Adm Kantor:', style: TextStyle(fontSize: 11, color: Colors.red)),
                          Text('-Rp ${order.adminFee.toInt()}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Potong Saldo Deposit:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                          Text('-Rp ${totalPotongan.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saldo Deposit Saat Ini:', style: TextStyle(fontSize: 11, color: _secondaryText)),
                          Text('Sisa Saldo Setelah Dipotong:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkTeal)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Rp ${saldoSebelum.toInt()}', style: const TextStyle(fontSize: 11, color: _secondaryText)),
                          Text('Rp ${saldoSesudah.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _darkTeal)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(context);

                // 1. Selesaikan orderan
                await _orderService.completeOrder(order.id);

                // 2. Otomatis potong saldo deposit driver untuk komisi instansi Jujug 20% + Adm
                final remaining = _authService.deductDriverDeposit(
                  driverId: driver.id,
                  amount: totalPotongan,
                );

                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Orderan #${order.id} selesai! Saldo deposit otomatis terpotong Rp ${totalPotongan.toInt()}. Sisa saldo: Rp ${remaining.toInt()}'),
                      backgroundColor: _darkTeal,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              child: const Text(
                'Selesaikan & Potong Deposit',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = _authService.currentUser;
    final driverOrders = _orderService.getOrdersForDriver(driver?.id ?? '');

    final onbidHours = _dailyOnbidMinutes ~/ 60;
    final onbidMinutes = _dailyOnbidMinutes % 60;
    final progress = (_dailyOnbidMinutes / _maxDailyMinutes).clamp(0.0, 1.0);
    final isExceeded = _dailyOnbidMinutes >= _maxDailyMinutes;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const AppLogo(height: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driver: ${driver?.fullName ?? "Ahmad"} 🛵',
                    style: const TextStyle(color: _darkText, fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnbid ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isOnbid ? 'ONBID (Online Siap Narik)' : 'OFFBID (Istirahat)',
                        style: TextStyle(
                          color: _isOnbid ? _darkTeal : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              _authService.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SplashScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: BrandedBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 1. STATUS CARD UTAMA (ONBID / OFFBID TOGGLE)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: _isOnbid
                    ? const LinearGradient(
                        colors: [Color(0xFFE6FFFA), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFF1F5F9), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOnbid ? _primaryTeal.withValues(alpha: 0.5) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isOnbid ? _primaryTeal.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _isOnbid ? _primaryTeal : Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isOnbid ? Icons.two_wheeler_rounded : Icons.power_settings_new_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isOnbid ? 'STATUS: ONBID' : 'STATUS: OFFBID',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: _isOnbid ? _darkTeal : _secondaryText,
                                ),
                              ),
                              Text(
                                _isOnbid ? 'Siap terima orderan dari Admin' : 'Sedang istirahat (Off order)',
                                style: const TextStyle(fontSize: 12, color: _secondaryText),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Transform.scale(
                        scale: 1.1,
                        child: Switch(
                          value: _isOnbid,
                          activeThumbColor: _primaryTeal,
                          activeTrackColor: _primaryTeal.withValues(alpha: 0.3),
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.shade200,
                          onChanged: _toggleOnbid,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Keterangan koneksi ke Admin
                  Row(
                    children: [
                      Icon(
                        _isOnbid ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                        color: _isOnbid ? _primaryTeal : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isOnbid
                              ? 'Radar GPS Aktif: Terhubung live ke Dispatcher Admin Harles Jujug'
                              : 'Radar GPS Nonaktif: Titik Anda tidak dimunculkan di peta Admin (Offbid)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isOnbid ? _darkTeal : _secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // TAMPILAN PETA RADAR AREA ONBID / OFFBID DRIVER
                  _DriverRadarMapWidget(
                    isOnbid: _isOnbid,
                    currentLocation: _currentLocation,
                    driverName: driver?.fullName ?? 'Driver Harles',
                    onChangeLocation: _showChangeLocationDialog,
                  ),
                  const SizedBox(height: 10),
                  // TOMBOL BAGIKAN LOKASI MAPS & WAKTU ONBID KE ADMIN VIA WHATSAPP
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _darkTeal,
                        side: const BorderSide(color: _primaryTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      icon: const Icon(Icons.share_location_rounded, size: 16, color: _darkTeal),
                      label: Text(
                        _isOnbid ? 'Bagikan Maps Onbid & Waktu ke WA Admin' : 'Kirim Update Posisi ke WA Admin',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      onPressed: () {
                        final now = TimeOfDay.now();
                        final hourStr = now.hour.toString().padLeft(2, '0');
                        final minStr = now.minute.toString().padLeft(2, '0');
                        final statusStr = _isOnbid ? 'ONBID (SIAP TERIMA ORDER)' : 'OFFBID (SEDANG ISTIRAHAT)';
                        final mapsUrl = 'https://maps.google.com/?q=${Uri.encodeComponent("$_currentLocation, Jeruklegi, Cilacap")}';
                        
                        final msg = 'Halo Admin Dispatcher Harles Jujug,\n\n'
                            'Saya Driver *${driver?.fullName ?? "Driver Harles"}* (${driver?.phone ?? ""})\n'
                            '🛵 *Status:* $statusStr\n'
                            '📍 *Lokasi Terkini:* $_currentLocation\n'
                            '🗺️ *Link Google Maps:* $mapsUrl\n'
                            '⏱️ *Durasi Onbid Hari Ini:* $onbidHours Jam $onbidMinutes Menit (Maks 18 Jam)\n'
                            '🕒 *Waktu Sinkron:* $hourStr:$minStr WIB\n\n'
                            'Titik radar GPS saya aktif dan siap menerima penugasan orderan. Terima kasih!';

                        WhatsAppService.openWhatsApp(
                          phone: WhatsAppService.adminPhone,
                          message: msg,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. KARTU BATAS JAM KERJA (MAKS 18 JAM SEHARI)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isExceeded ? Colors.red.shade300 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isExceeded ? Colors.red.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isExceeded ? Icons.warning_rounded : Icons.timer_outlined,
                            color: isExceeded ? Colors.red : (progress > 0.85 ? Colors.orange : _primaryTeal),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Jam Kerja Onbid Hari Ini',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkText),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isExceeded
                              ? Colors.red.shade100
                              : (progress > 0.85 ? Colors.orange.shade100 : _primaryTeal.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isExceeded ? 'HABIS / OVER' : 'Maks 18 Jam / Hari',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isExceeded ? Colors.red.shade800 : _darkTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$onbidHours Jam $onbidMinutes Menit',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isExceeded ? Colors.red : (progress > 0.85 ? Colors.orange.shade800 : _darkTeal),
                        ),
                      ),
                      Text(
                        'dari 18 Jam (1080 mnt)',
                        style: const TextStyle(fontSize: 12, color: _secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isExceeded ? Colors.red : (progress > 0.85 ? Colors.orange : _primaryTeal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isExceeded)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Batas 18 jam telah terlampaui. Mohon beristirahat demi keselamatan Anda!',
                              style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Sisa waktu narik: ${(18 - onbidHours).clamp(0, 18)} jam ${(60 - onbidMinutes) % 60} menit lagi sebelum wajib istirahat.',
                      style: const TextStyle(fontSize: 11, color: _secondaryText),
                    ),

                  const SizedBox(height: 10),

                  // Testing Controls Toolbar (Sangat membantu pengujian)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Alat Uji Cepat:', style: TextStyle(fontSize: 10, color: _secondaryText, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            InkWell(
                              onTap: _simulateAddHour,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text('+1 Jam', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const Text('•', style: TextStyle(color: Colors.grey)),
                            InkWell(
                              onTap: _simulateMaxLimit,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text('Tes 18 Jam', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const Text('•', style: TextStyle(color: Colors.grey)),
                            InkWell(
                              onTap: _resetDailyHours,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text('Reset', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
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

            const SizedBox(height: 14),

            // KARTU SALDO DEPOSIT DRIVER (POTONGAN PROFIT SHARING 20% INSTANSI JUJUG)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_darkTeal, _primaryTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _primaryTeal.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Logo Watermark Background
                  Positioned(
                    right: -25,
                    bottom: -25,
                    child: Opacity(
                      opacity: 0.16,
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler_rounded, size: 80, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Konten Deposit Driver
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Saldo Deposit Driver',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (driver?.walletBalance ?? 0) >= 2100 ? Colors.white24 : Colors.red.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    (driver?.walletBalance ?? 0) >= 2100 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (driver?.walletBalance ?? 0) >= 2100 ? 'Siap Narik' : 'Perlu Top Up',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Rp ${(driver?.walletBalance ?? 8500).toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Otomatis terpotong komisi 20% + Adm Rp 500 untuk instansi Jujug setiap order selesai.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF118EEA),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF118EEA)),
                              label: const Text('Top Up via DANA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              onPressed: () => _showDanaTopUpDialog(driver),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: const Icon(Icons.info_outline_rounded, size: 15, color: Colors.white),
                              label: const Text('Info Bagi Hasil 20%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              onPressed: _showProfitSharingInfoDialog,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. DAFTAR PESANAN DITUGASKAN ADMIN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Orderan Ditugaskan Admin',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _darkText),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${driverOrders.length} Order Aktif',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _darkTeal),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (!_isOnbid)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.bedtime_outlined, size: 44, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'Status Anda Sedang OFFBID',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _darkText),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Aktifkan status ONBID di bagian atas jika Anda ingin menerima dan menjalankan pesanan dari Admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              )
            else if (driverOrders.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.moped_rounded, size: 44, color: _primaryTeal),
                    SizedBox(height: 10),
                    Text(
                      'Belum Ada Orderan Baru',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkText),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Status ONBID Anda aktif dan terhubung ke Admin. Tunggu pesanan ditugaskan ke Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: driverOrders.length,
                itemBuilder: (context, index) {
                  final order = driverOrders[index];
                  return _buildDriverOrderCard(order);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDriverOrderCard(OrderModel order) {
    final cleanName = order.serviceType.toLowerCase();

    final isPassengerRide = cleanName.contains('ride') ||
        cleanName.contains('car') ||
        cleanName.contains('ojek') ||
        cleanName.contains('penumpang');

    final isPackageExpress = cleanName.contains('paket') ||
        cleanName.contains('express') ||
        cleanName.contains('dokumen');

    final isShoppingFoodMart = cleanName.contains('food') ||
        cleanName.contains('mart') ||
        cleanName.contains('kuliner') ||
        cleanName.contains('jujug');

    String label1 = isPassengerRide
        ? 'Titik Jemput'
        : (isPackageExpress ? 'Pengirim (Lokasi Paket)' : (isShoppingFoodMart ? 'Beli di (Toko/Outlet)' : 'Titik Jemput'));

    String label2 = isPassengerRide
        ? 'Tujuan Antar'
        : (isPackageExpress ? 'Penerima (Tujuan Paket)' : (isShoppingFoodMart ? 'Tujuan Pengiriman' : 'Tujuan Antar'));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.serviceType,
                    style: const TextStyle(color: _darkTeal, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Text(
                  'Rp ${order.price.toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _darkTeal),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'Customer: ${order.customerName} (+${order.customerPhone})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(isShoppingFoodMart ? Icons.storefront_rounded : Icons.my_location, color: isShoppingFoodMart ? _darkTeal : Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label1: ${order.pickupLocation}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label2: ${order.destinationLocation}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Catatan: "${order.notes}"',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey),
              ),
            ],
            const SizedBox(height: 10),

            // Live Peta Lokasi Rute Navigasi Driver (Embedded Map)
            LiveMapView(
              pickupAddress: order.pickupLocation,
              dropoffAddress: order.destinationLocation,
              isDriverView: true,
              height: 140,
            ),

            const SizedBox(height: 10),
            // RINCIAN TAGIHAN & BAGI HASIL ORDER
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Tagih ke Customer (Cash):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Rp ${order.totalCustomerBill.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkTeal)),
                    ],
                  ),
                  if (order.outletCost > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('• Belanja Outlet (Talangan):', style: TextStyle(fontSize: 11, color: _secondaryText)),
                        Text('Rp ${order.outletCost.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('• Ongkir Bersih Driver (80%):', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                      Text('Rp ${order.driverNetEarnings.toInt()}', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('• Potongan Deposit Kantor (20% + Adm):', style: TextStyle(fontSize: 11, color: Colors.red)),
                      Text('-Rp ${order.totalCommissionDeduction.toInt()}', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tombol Komunikasi WhatsApp dengan Customer & Maps
            if (order.status == OrderStatus.driverAssigned || order.status == OrderStatus.inProgress) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        final currentDriver = _authService.currentUser;
                        final driverName = currentDriver?.fullName ?? 'Driver Harles';
                        final msg = WhatsAppService.formatDriverToCustomer(order, driverName);
                        WhatsAppService.openWhatsApp(phone: order.customerPhone, message: msg);
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                      label: const Text(
                        'Konfirmasi ke WA Customer',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            if (order.status == OrderStatus.driverAssigned)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    _orderService.startOrder(order.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Orderan ${order.id} dalam perjalanan! Selamat bertugas.')),
                    );
                  },
                  icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                  label: const Text('Jalankan Orderan Ini', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            else if (order.status == OrderStatus.inProgress)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showCompleteOrderConfirmation(order),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'Selesaikan & Potong Bagi Hasil 20% (-Rp ${order.totalCommissionDeduction.toInt()})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              )
            else if (order.status == OrderStatus.completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text('Orderan Selesai Diantar', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    Text(
                      'Bagi Hasil: -Rp ${order.totalCommissionDeduction.toInt()}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// WIDGET PETA & RADAR ONBID/OFFBID DRIVER
// ==========================================
class _DriverRadarMapWidget extends StatefulWidget {
  final bool isOnbid;
  final String currentLocation;
  final String driverName;
  final VoidCallback onChangeLocation;

  const _DriverRadarMapWidget({
    required this.isOnbid,
    required this.currentLocation,
    required this.driverName,
    required this.onChangeLocation,
  });

  @override
  State<_DriverRadarMapWidget> createState() => _DriverRadarMapWidgetState();
}

class _DriverRadarMapWidgetState extends State<_DriverRadarMapWidget> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const activeTeal = Color(0xFF13C5BC);

    return Container(
      height: 225,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isOnbid ? activeTeal.withValues(alpha: 0.6) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Gambar Peta & Radar Gelombang Menggunakan CustomPainter
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(double.infinity, 225),
                painter: _MapCanvasPainter(
                  isOnbid: widget.isOnbid,
                  pulseValue: _radarController.value,
                ),
              );
            },
          ),

          // 2. POI / Landmark Lokasi di Jeruklegi & Cilacap
          Positioned(
            left: 14,
            top: 40,
            child: _buildPoiBadge(Icons.storefront_rounded, 'Pasar Jeruklegi', Colors.orange),
          ),
          Positioned(
            right: 14,
            top: 42,
            child: _buildPoiBadge(Icons.local_gas_station_rounded, 'SPBU Jeruklegi', Colors.red),
          ),
          Positioned(
            left: 20,
            bottom: 46,
            child: _buildPoiBadge(Icons.train_rounded, 'Stasiun Jeruklegi', Colors.indigo),
          ),
          Positioned(
            right: 18,
            bottom: 44,
            child: _buildPoiBadge(Icons.security_rounded, 'Pos Dispatcher Jujug', const Color(0xFF005F5B)),
          ),

          // 3. Driver Pin Marker & Callout Tooltip di Titik Tengah
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Callout Tag Driver
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.isOnbid ? const Color(0xFF0F172A) : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isOnbid ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                        color: widget.isOnbid ? const Color(0xFF13C5BC) : Colors.white60,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isOnbid ? '${widget.driverName} (LIVE)' : 'OFFBID',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Icon Pin Motor
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: widget.isOnbid ? const Color(0xFF13C5BC) : Colors.grey.shade500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isOnbid ? const Color(0xFF13C5BC) : Colors.black).withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.two_wheeler_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),

          // 4. Header Overlay: Status Radar Pill & Tombol Ubah Lokasi
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (widget.isOnbid ? const Color(0xFF005F5B) : Colors.grey.shade900).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isOnbid ? const Color(0xFF13C5BC) : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.isOnbid ? 'PETA RADAR ONBID' : 'PETA RADAR OFFBID',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: widget.onChangeLocation,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_location_alt_rounded, size: 13, color: Color(0xFF005F5B)),
                        SizedBox(width: 3),
                        Text(
                          'Ubah Lokasi',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF005F5B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Overlay: Alamat Terkini Driver
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF13C5BC)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Posisi: ${widget.currentLocation}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    widget.isOnbid ? 'Live Dispatcher Jujug' : 'Radar Offbid',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.isOnbid ? const Color(0xFF005F5B) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiBadge(IconData icon, String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            name,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CANVAS CUSTOM PAINTER UNTUK PETA & RADAR
// ==========================================
class _MapCanvasPainter extends CustomPainter {
  final bool isOnbid;
  final double pulseValue;

  _MapCanvasPainter({required this.isOnbid, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background Dasar Peta
    final bgPaint = Paint()..color = isOnbid ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Jalur Sungai Serayu / Donan (Cilacap)
    final waterPaint = Paint()
      ..color = isOnbid ? const Color(0xFFBAE6FD) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final waterPath = Path();
    waterPath.moveTo(-10, size.height * 0.78);
    waterPath.quadraticBezierTo(size.width * 0.35, size.height * 0.88, size.width * 0.68, size.height * 0.62);
    waterPath.quadraticBezierTo(size.width * 0.9, size.height * 0.42, size.width + 10, size.height * 0.36);
    canvas.drawPath(waterPath, waterPaint);

    // 3. Jaringan Jalan Raya (Jl. Raya Jeruklegi, Jl. Kawunganten, dll)
    final roadBorderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    final roadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    // Jalan Utama Horizontal
    final mainRoad = Path();
    mainRoad.moveTo(-10, size.height * 0.48);
    mainRoad.cubicTo(size.width * 0.3, size.height * 0.44, size.width * 0.7, size.height * 0.53, size.width + 10, size.height * 0.50);
    canvas.drawPath(mainRoad, roadBorderPaint);
    canvas.drawPath(mainRoad, roadPaint);

    // Jalan Persimpangan Vertikal
    final crossRoad = Path();
    crossRoad.moveTo(size.width * 0.5, -10);
    crossRoad.cubicTo(size.width * 0.48, size.height * 0.3, size.width * 0.52, size.height * 0.7, size.width * 0.49, size.height + 10);
    canvas.drawPath(crossRoad, roadBorderPaint);
    canvas.drawPath(crossRoad, roadPaint);

    // Jalan Penghubung Diagonal
    final diagRoad = Path();
    diagRoad.moveTo(-10, size.height * 0.2);
    diagRoad.lineTo(size.width * 0.62, size.height + 10);
    canvas.drawPath(diagRoad, roadBorderPaint..strokeWidth = 6);
    canvas.drawPath(diagRoad, roadPaint..strokeWidth = 4.5);

    // 4. Blok Kawasan & Kompleks Bangunan
    final blockPaint = Paint()
      ..color = isOnbid ? const Color(0xFFE2E8F0).withValues(alpha: 0.6) : const Color(0xFFCBD5E1).withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.1, size.height * 0.16, size.width * 0.25, size.height * 0.2), const Radius.circular(6)),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.66, size.height * 0.16, size.width * 0.25, size.height * 0.25), const Radius.circular(6)),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.14, size.height * 0.62, size.width * 0.26, size.height * 0.2), const Radius.circular(6)),
      blockPaint,
    );

    // 5. Efek Gelombang Radar Live (Hanya Aktif saat ONBID)
    final center = Offset(size.width * 0.5, size.height * 0.49);

    if (isOnbid) {
      // Lingkaran Radar Luar Mengembang
      final rippleRadius1 = 18.0 + (pulseValue * 58.0);
      final rippleOpacity1 = (1.0 - pulseValue).clamp(0.0, 0.45);
      final ripplePaint1 = Paint()
        ..color = const Color(0xFF13C5BC).withValues(alpha: rippleOpacity1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, rippleRadius1, ripplePaint1);

      // Garis Lingkaran Radar Kedua
      final pulse2 = (pulseValue + 0.5) % 1.0;
      final rippleRadius2 = 14.0 + (pulse2 * 45.0);
      final rippleOpacity2 = ((1.0 - pulse2) * 0.6).clamp(0.0, 0.6);
      final ripplePaint2 = Paint()
        ..color = const Color(0xFF13C5BC).withValues(alpha: rippleOpacity2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, rippleRadius2, ripplePaint2);
    }
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.isOnbid != isOnbid || oldDelegate.pulseValue != pulseValue;
  }
}

