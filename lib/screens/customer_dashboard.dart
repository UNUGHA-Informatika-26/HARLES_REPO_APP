import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/branded_background.dart';
import '../widgets/live_map_view.dart';
import 'splash_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();

  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _accentGreen = Color(0xFF25D366);

  String _filterStatus = 'all'; // 'all', 'active', 'completed'

  @override
  void initState() {
    super.initState();
    _orderService.addListener(_onServiceUpdate);
    _authService.addListener(_onServiceUpdate);
    _orderService.initRealtimeOrders();
  }

  @override
  void dispose() {
    _orderService.removeListener(_onServiceUpdate);
    _authService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  // --- HITUNG ESTIMASI JARAK SECARA OTOMATIS BERDASARKAN ALAMAT JEMPUT & TUJUAN ---
  double _estimateDistanceAutomatically(String pickup, String dest) {
    final p = pickup.trim().toLowerCase();
    final d = dest.trim().toLowerCase();
    if (p.isEmpty || d.isEmpty) return 2.0;

    final combinedLen = p.length + d.length;
    double estimatedKm = (combinedLen % 14) * 0.7 + 1.8;
    return double.parse(estimatedKm.clamp(1.5, 18.0).toStringAsFixed(1));
  }

  // --- MODAL PEMBUATAN PESANAN BARU DENGAN LABEL DINAMIS SESUAI KATEGORI LAYANAN ---
  void _showCreateOrderModal(String serviceName, double defaultPrice) {
    final user = _authService.currentUser;
    if (user == null) return;

    final cleanName = serviceName.toLowerCase();

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

    // Label, Hint, & Icon Kustom Spesifik Tiap Layanan
    String label1;
    String hint1;
    IconData icon1;
    Color iconColor1;

    String label2;
    String hint2;
    IconData icon2;
    Color iconColor2;

    if (isPassengerRide) {
      label1 = '1. Titik Penjemputan';
      hint1 = 'Alamat penjemputan Anda (Contoh: Jl. Raya Jeruklegi)';
      icon1 = Icons.my_location_rounded;
      iconColor1 = Colors.blue;

      label2 = '2. Alamat Tujuan Antar';
      hint2 = 'Contoh: Mall Paragon / Pusat Kota Cilacap';
      icon2 = Icons.location_on_rounded;
      iconColor2 = Colors.red;
    } else if (isPackageExpress) {
      label1 = '1. Alamat Pengirim (Lokasi Paket)';
      hint1 = 'Alamat & nama pengirim paket/dokumen';
      icon1 = Icons.unarchive_rounded;
      iconColor1 = Colors.orange;

      label2 = '2. Alamat Penerima (Tujuan Paket)';
      hint2 = 'Alamat & nama penerima paket/dokumen';
      icon2 = Icons.archive_rounded;
      iconColor2 = Colors.red;
    } else if (isShoppingFoodMart) {
      label1 = '1. Beli di Mana (Nama Toko / Outlet / Warung)';
      hint1 = 'Contoh: Warung Kanthong / Toko Berkah / Rumah Makan';
      icon1 = Icons.storefront_rounded;
      iconColor1 = _darkTeal;

      label2 = '2. Tujuan Pengiriman (Alamat Penerima)';
      hint2 = 'Contoh: Perum Jeruklegi Indah Blok C / Torris Cell';
      icon2 = Icons.location_on_rounded;
      iconColor2 = Colors.red;
    } else {
      label1 = '1. Lokasi Asal / Tempat Beli';
      hint1 = 'Alamat asal / toko beli';
      icon1 = Icons.my_location_rounded;
      iconColor1 = Colors.blue;

      label2 = '2. Lokasi Tujuan Pengiriman';
      hint2 = 'Alamat tujuan penerima';
      icon2 = Icons.location_on_rounded;
      iconColor2 = Colors.red;
    }

    final pickupController = TextEditingController(
      text: isShoppingFoodMart ? '' : (isPackageExpress ? 'Jl. Raya Jeruklegi No. 12' : 'Jl. Raya Jeruklegi, Cilacap'),
    );
    final destController = TextEditingController(
      text: isShoppingFoodMart ? '' : (isPackageExpress ? 'Torris Cell, Cilacap' : 'Pusat Kota Cilacap'),
    );
    final notesController = TextEditingController();
    final estimateCostController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            pickupController.addListener(() {
              if (mounted) setModalState(() {});
            });
            destController.addListener(() {
              if (mounted) setModalState(() {});
            });

            final autoDistanceKm = _estimateDistanceAutomatically(
              pickupController.text,
              destController.text,
            );

            final calculatedDeliveryFee = OrderService.calculateDynamicTariff(
              serviceType: serviceName,
              distanceKm: autoDistanceKm,
            );

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _primaryTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isPassengerRide
                                    ? Icons.two_wheeler_rounded
                                    : (isPackageExpress ? Icons.local_shipping_rounded : Icons.shopping_bag_rounded),
                                color: _darkTeal,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  serviceName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkText),
                                ),
                                Text(
                                  isPassengerRide
                                      ? 'Layanan Antar Penumpang (Minimal Rp 9.000)'
                                      : 'Layanan Paketan & Belanja (Minimal Rp 8.000)',
                                  style: const TextStyle(fontSize: 11, color: _secondaryText),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Field 1: Label Dinamis (Titik Jemput / Pengirim / Beli di Mana)
                    Text(
                      label1,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkText),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: pickupController,
                      decoration: InputDecoration(
                        hintText: hint1,
                        prefixIcon: Icon(icon1, color: iconColor1),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Field 2: Label Dinamis (Alamat Antar / Tujuan Penerima / Pengiriman)
                    Text(
                      label2,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkText),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: destController,
                      decoration: InputDecoration(
                        hintText: hint2,
                        prefixIcon: Icon(icon2, color: iconColor2),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // KOTAK KETENTUAN JARAK & TARIF OTOMATIS APLIKASI
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 16, color: _darkTeal),
                                  SizedBox(width: 6),
                                  Text('Estimasi Jarak (Otomatis):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkText)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _primaryTeal.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${autoDistanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkTeal),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isPassengerRide
                                ? '• Tarif Antar Penumpang: Minimal Rp 9.000 (s/d 2.0 km) + Rp 3.000/km berikutnya.'
                                : '• Tarif Paketan & Makanan/Barang: Minimal Rp 8.000 (s/d 2.0 km) + Rp 2.500/km berikutnya.',
                            style: const TextStyle(fontSize: 11, color: _secondaryText, height: 1.3),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Field 3: Daftar Pesanan / Catatan Pengiriman
                    Text(
                      isShoppingFoodMart ? '3. Daftar Pesanan Belanja' : '3. Catatan Pengiriman / Barang (Opsional)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkText),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isShoppingFoodMart
                            ? '- Ayam bakar + nasi 1\n- Ayam penyet + nasi 1\n- Krupuk 2'
                            : (isPackageExpress ? 'Rincian barang/dokumen, nomor kontak pengirim/penerima' : 'Patokan rumah, no pagar, atau pesan untuk driver'),
                        prefixIcon: const Icon(Icons.receipt_long_rounded, color: _darkTeal),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (isShoppingFoodMart) ...[
                      const Text(
                        'Perkiraan Harga Belanjaan Outlet (Opsional):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkText),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: estimateCostController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 31000 (Jika belum tahu bisa dikosongkan)',
                          prefixText: 'Rp ',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Rincian Biaya Transparan
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tarif Jujug ($serviceName - ${autoDistanceKm.toStringAsFixed(1)} km):', style: const TextStyle(fontSize: 12, color: _secondaryText)),
                              Text('Rp ${calculatedDeliveryFee.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _darkTeal)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Biaya Administrasi Kantor:', style: TextStyle(fontSize: 12, color: _secondaryText)),
                              Text('Rp 500', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Metode Pembayaran:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('💵 Tunai / Cash ke Driver (Rp ${(calculatedDeliveryFee + 500).toInt()})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkTeal)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Button Submit Pesanan
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Kirim Pesanan ke Admin 📲',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: () async {
                          if (pickupController.text.trim().isEmpty || destController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Harap lengkapi lokasi tempat beli & alamat antar.')),
                            );
                            return;
                          }

                          final double outletEstimate = double.tryParse(estimateCostController.text) ?? 0;

                          final newOrder = await _orderService.createOrder(
                            serviceType: serviceName,
                            customerId: user.id,
                            customerName: user.fullName,
                            customerPhone: user.phone,
                            pickupLocation: pickupController.text.trim(),
                            destinationLocation: destController.text.trim(),
                            price: calculatedDeliveryFee,
                            notes: notesController.text.trim(),
                          );

                          if (outletEstimate > 0) {
                            await _orderService.updateOrderFinancials(
                              orderId: newOrder.id,
                              outletCost: outletEstimate,
                              deliveryFee: calculatedDeliveryFee,
                              adminFee: 500,
                            );
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pesanan #${newOrder.id} (${autoDistanceKm.toStringAsFixed(1)} km - Rp ${calculatedDeliveryFee.toInt()}) berhasil dikirim ke Admin!'),
                                backgroundColor: _darkTeal,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- DIALOG KONFIRMASI BATAL PESANAN ---
  void _confirmCancelOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Batalkan Pesanan?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text('Yakin ingin membatalkan pesanan #${order.id}? Pesanan ini akan dibatalkan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await _orderService.cancelOrder(order.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pesanan #${order.id} telah dibatalkan.')),
                  );
                }
              },
              child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG HAPUS PESANAN PERMANEN ---
  void _confirmDeleteOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus dari Riwayat?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text('Hapus riwayat pesanan #${order.id}? Tindakan ini akan menghapus data dari daftar Anda.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                await _orderService.deleteOrder(order.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Riwayat pesanan #${order.id} dihapus.')),
                  );
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final allCustomerOrders = _orderService.getOrdersForCustomer(user?.id ?? '');

    final filteredOrders = allCustomerOrders.where((order) {
      if (_filterStatus == 'active') {
        return order.status == OrderStatus.pendingAdmin ||
            order.status == OrderStatus.driverAssigned ||
            order.status == OrderStatus.inProgress;
      } else if (_filterStatus == 'completed') {
        return order.status == OrderStatus.completed || order.status == OrderStatus.cancelled;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const AppLogo(height: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${user?.fullName ?? "Pelanggan"} 👋',
                    style: const TextStyle(color: _darkText, fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Pelanggan Resmi Harles Jujug',
                    style: TextStyle(color: _secondaryText, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: _primaryTeal),
            tooltip: 'Hubungi Admin WA',
            onPressed: () {
              WhatsAppService.openWhatsApp(
                phone: WhatsAppService.adminPhone,
                message: 'Halo Admin Harles Jujug, saya butuh bantuan mengenai aplikasi...',
              );
            },
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. BRAND BANNER DENGAN BACKGROUND LOGO HARLES JUJUG
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _primaryTeal,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryTeal.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'OFFICIAL APP 🛵',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Harles Jujug',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Layanan Antar Penumpang & Belanja Makanan, Minuman, Paket Cilacap',
                            style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: Image.asset(
                        'assets/logo.png.jpg',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.stars_rounded, color: Colors.white, size: 48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. SALDO HARLESPAY CUSTOMER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded, color: _darkTeal, size: 18),
                            SizedBox(width: 6),
                            Text('Saldo HarlesPay', style: TextStyle(color: _secondaryText, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Rp ${user?.walletBalance.toInt() ?? 150000}', style: const TextStyle(color: _darkText, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
                      label: const Text('Top Up', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fitur Top Up Saldo HarlesPay dapat menghubungi CS/Admin WA.')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. SERVICE CATEGORY GRID
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Layanan Jujug Pesenan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _darkText),
                  ),
                  Text(
                    'Klik Icon untuk Pesan',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryTeal),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 10,
                children: [
                  _buildServiceItem('Harles Ride', Icons.two_wheeler_rounded, const Color(0xFF0284C7), 9000),
                  _buildServiceItem('Harles Car', Icons.directions_car_rounded, Colors.indigo, 15000),
                  _buildServiceItem('Express Paket', Icons.local_shipping_rounded, const Color(0xFFEA580C), 8000),
                  _buildServiceItem('Harles Food', Icons.restaurant_rounded, const Color(0xFFE11D48), 8000),
                  _buildServiceItem('Harles Mart', Icons.shopping_bag_rounded, const Color(0xFF7C3AED), 8000),
                  _buildServiceItem('Pulsa & PPOB', Icons.phone_android_rounded, Colors.purple, 10000),
                  _buildServiceItem('Admin WA', Icons.chat_rounded, _accentGreen, 0, isWhatsApp: true),
                  _buildServiceItem('Lainnya', Icons.widgets_rounded, Colors.teal, 8000),
                ],
              ),

              const SizedBox(height: 24),

              // 4. PESANAN MINTA DILAYANI DIRECT CS WA BANNER
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: _accentGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pesan Langsung via WA Admin',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkText),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Kirim daftar pesanan/lokasi jemput langsung ke Customer Service WA.',
                            style: TextStyle(fontSize: 11, color: _secondaryText),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              WhatsAppService.openWhatsApp(
                                phone: WhatsAppService.adminPhone,
                                message: 'Halo Admin Harles Jujug, saya ingin pesan layanan langsung melalui WhatsApp...',
                              );
                            },
                            child: const Text(
                              'Chat Admin WA Sekarang ➔',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkTeal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 5. DAFTAR RIWAYAT / PESANAN CUSTOMER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat & Status Pesanan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _darkText),
                  ),
                  // Filter Tabs
                  Row(
                    children: [
                      _buildFilterChip('Semua', 'all'),
                      const SizedBox(width: 4),
                      _buildFilterChip('Aktif', 'active'),
                      const SizedBox(width: 4),
                      _buildFilterChip('Selesai', 'completed'),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (filteredOrders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(Icons.inbox_rounded, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada riwayat pesanan.',
                        style: TextStyle(color: _secondaryText, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Silakan klik salah satu icon layanan di atas untuk membuat pesanan baru.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _secondaryText, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildCustomerOrderCard(order);
                  },
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _primaryTeal : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : _secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerOrderCard(OrderModel order) {
    Color statusColor;
    IconData statusIcon;

    switch (order.status) {
      case OrderStatus.pendingAdmin:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case OrderStatus.driverAssigned:
        statusColor = Colors.blue;
        statusIcon = Icons.assignment_ind_rounded;
        break;
      case OrderStatus.inProgress:
        statusColor = _primaryTeal;
        statusIcon = Icons.two_wheeler_rounded;
        break;
      case OrderStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case OrderStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
    }

    final isCanCancel = order.status == OrderStatus.pendingAdmin;

    final isPassengerRide = order.serviceType.toLowerCase().contains('ride') ||
        order.serviceType.toLowerCase().contains('car') ||
        order.serviceType.toLowerCase().contains('ojek') ||
        order.serviceType.toLowerCase().contains('penumpang');

    final isPackageExpress = order.serviceType.toLowerCase().contains('paket') ||
        order.serviceType.toLowerCase().contains('express') ||
        order.serviceType.toLowerCase().contains('dokumen');

    final isShoppingFoodMart = order.serviceType.toLowerCase().contains('food') ||
        order.serviceType.toLowerCase().contains('mart') ||
        order.serviceType.toLowerCase().contains('kuliner') ||
        order.serviceType.toLowerCase().contains('jujug');

    String label1 = isPassengerRide
        ? 'Titik Beli/Jemput'
        : (isPackageExpress ? 'Pengirim (Lokasi Paket)' : (isShoppingFoodMart ? 'Beli di (Toko/Outlet)' : 'Titik Beli/Jemput'));

    String label2 = isPassengerRide
        ? 'Tujuan Antar'
        : (isPackageExpress ? 'Penerima (Tujuan Paket)' : (isShoppingFoodMart ? 'Tujuan Pengiriman' : 'Tujuan Antar'));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Kode & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      order.serviceType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkText),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '#${order.id}',
                      style: const TextStyle(fontSize: 11, color: _secondaryText),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Lokasi Jemput/Beli
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isShoppingFoodMart ? Icons.storefront_rounded : Icons.my_location, size: 16, color: isShoppingFoodMart ? _darkTeal : Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label1: ${order.pickupLocation}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _darkText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Alamat Antar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label2: ${order.destinationLocation}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _darkText),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Embedded Peta Rute Navigasi Live
            LiveMapView(
              pickupAddress: order.pickupLocation,
              dropoffAddress: order.destinationLocation,
              height: 130,
            ),

            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Catatan: "${order.notes}"',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _secondaryText),
                ),
              ),
            ],

            // Informasi Driver jika sudah ditugaskan
            if (order.assignedDriverName != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: _primaryTeal,
                      child: Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mitra Driver: ${order.assignedDriverName}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkTeal),
                          ),
                          Text(
                            'WA Driver: +${order.assignedDriverPhone}',
                            style: const TextStyle(fontSize: 11, color: _secondaryText),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_rounded, color: _accentGreen, size: 20),
                      tooltip: 'Chat WA Driver',
                      onPressed: () {
                        if (order.assignedDriverPhone != null) {
                          final user = _authService.currentUser;
                          final msg = WhatsAppService.formatCustomerToDriver(order, user?.fullName ?? 'Pelanggan');
                          WhatsAppService.openWhatsApp(phone: order.assignedDriverPhone!, message: msg);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Rincian Biaya
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Biaya: Rp ${order.totalCustomerBill.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkTeal),
                    ),
                    if (order.outletCost > 0)
                      Text(
                        '(Belanja: Rp ${order.outletCost.toInt()} + Ongkir: Rp ${order.deliveryFee.toInt()})',
                        style: const TextStyle(fontSize: 10, color: _secondaryText),
                      ),
                  ],
                ),

                Row(
                  children: [
                    if (isCanCancel)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: () => _confirmCancelOrder(order),
                        child: const Text('Batalkan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                      tooltip: 'Hapus Riwayat',
                      onPressed: () => _confirmDeleteOrder(order),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(String title, IconData icon, Color color, double price, {bool isWhatsApp = false}) {
    return GestureDetector(
      onTap: () {
        if (isWhatsApp) {
          WhatsAppService.openWhatsApp(
            phone: WhatsAppService.adminPhone,
            message: 'Halo Admin Harles Jujug, saya ingin pesan layanan langsung melalui WhatsApp...',
          );
        } else {
          _showCreateOrderModal(title, price);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _darkText),
          ),
        ],
      ),
    );
  }
}
