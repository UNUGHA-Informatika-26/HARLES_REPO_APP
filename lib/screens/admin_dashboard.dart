import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/branded_background.dart';
import '../widgets/driver_fleet_radar_map.dart';
import 'splash_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();

  late TabController _tabController;
  String _searchQueryCustomer = '';
  String _searchQueryDriver = '';

  static const Color _primaryTeal = Color(0xFF13C5BC);
  static const Color _darkTeal = Color(0xFF005F5B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _authService.addListener(_onServiceUpdate);
    _orderService.addListener(_onServiceUpdate);
    _orderService.initRealtimeOrders();
    _authService.fetchUsersFromSupabase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authService.removeListener(_onServiceUpdate);
    _orderService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  // --- DISPATCH: ADMIN TUGASKAN DRIVER KE ORDERAN ---
  void _showAssignDriverDialog(OrderModel order) {
    final availableDrivers = _authService.users.where((u) => u.role == UserRole.driver).toList()
      ..sort((a, b) {
        if (a.isOnbid && !b.isOnbid) return -1;
        if (!a.isOnbid && b.isOnbid) return 1;
        return a.fullName.compareTo(b.fullName);
      });

    if (availableDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada Driver terdaftar di sistem. Harap buat akun Driver terlebih dahulu.')),
      );
      return;
    }

    UserModel selectedDriver = availableDrivers.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.two_wheeler_rounded, color: _primaryTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tugaskan Driver (${order.id})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Layanan: ${order.serviceType}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Customer: ${order.customerName} (+${order.customerPhone})', style: const TextStyle(fontSize: 12, color: _secondaryText)),
                    const SizedBox(height: 6),
                    Text('📍 Titik Jemput: ${order.pickupLocation}', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    // Embedded Radar Map
                    DriverFleetRadarMap(
                      drivers: availableDrivers,
                      selectedPickupLocation: order.pickupLocation,
                      height: 130,
                    ),

                    const SizedBox(height: 12),
                    const Text('Pilih Driver (Prioritas Driver ONBID Terdekat):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<UserModel>(
                      initialValue: selectedDriver,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: availableDrivers.map((d) {
                        final onbidTag = d.isOnbid ? '⚡ 🟢 ONBID (Terdekat)' : '⚪ OFFBID';
                        final overTag = d.isExceeded18Hours ? ' [⚠️ >18 Jam]' : '';
                        return DropdownMenuItem(
                          value: d,
                          child: Text(
                            '${d.fullName} ($onbidTag)$overTag - 📍 ${d.currentLocation}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: d.isOnbid ? FontWeight.bold : FontWeight.normal,
                              color: d.isExceeded18Hours ? Colors.red : (d.isOnbid ? _darkTeal : _secondaryText),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDriver = val);
                      },
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
                  onPressed: () async {
                    await _orderService.assignDriverToOrder(
                      orderId: order.id,
                      driver: selectedDriver,
                    );

                    final dispatchText = WhatsAppService.formatDispatchToDriver(order);
                    await WhatsAppService.openWhatsApp(
                      phone: selectedDriver.phone,
                      message: dispatchText,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Format JUJUG PESENAN dikirim ke WhatsApp ${selectedDriver.fullName}!')),
                      );
                    }
                  },
                  child: const Text('Tugaskan & Kirim WA Driver 📲', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- RINCIAN BIAYA & BAGI HASIL ORDERAN ---
  void _showOrderFinancialDialog(OrderModel order) {
    final outletController = TextEditingController(text: order.outletCost > 0 ? order.outletCost.toInt().toString() : '');
    final deliveryController = TextEditingController(text: order.deliveryFee > 0 ? order.deliveryFee.toInt().toString() : order.price.toInt().toString());
    final parkingController = TextEditingController(text: order.parkingFee > 0 ? order.parkingFee.toInt().toString() : '');
    final admController = TextEditingController(text: order.adminFee.toInt().toString());
    final extraController = TextEditingController(text: order.extraFee > 0 ? order.extraFee.toInt().toString() : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double outlet = double.tryParse(outletController.text) ?? 0;
            final double delivery = double.tryParse(deliveryController.text) ?? order.price;
            final double parking = double.tryParse(parkingController.text) ?? 0;
            final double adm = double.tryParse(admController.text) ?? 500;
            final double extra = double.tryParse(extraController.text) ?? 0;

            final totalCustomer = outlet + delivery + parking + adm + extra;
            final commissionDeduction = (delivery * 0.20) + adm;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: _primaryTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Kelola Rincian #${order.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Layanan: ${order.serviceType}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Customer: ${order.customerName}', style: const TextStyle(fontSize: 12, color: _secondaryText)),
                    const SizedBox(height: 12),

                    TextField(
                      controller: outletController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Biaya Belanja Outlet (Rp)',
                        hintText: 'Contoh: 31000',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: deliveryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tarif Ongkir Jujug Pesenan (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: parkingController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Biaya Parkir (Rp opsional)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: admController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Adm Kantor (Rp)',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: extraController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Biaya Tambahan (Rp)',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Tagihan Customer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Rp ${totalCustomer.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkTeal)),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bagi Hasil 20% + Adm:', style: TextStyle(fontSize: 12, color: Colors.red)),
                              Text('Rp ${commissionDeduction.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryTeal),
                  onPressed: () async {
                    final updatedOrder = await _orderService.updateOrderFinancials(
                      orderId: order.id,
                      outletCost: outlet,
                      deliveryFee: delivery,
                      parkingFee: parking,
                      adminFee: adm,
                      extraFee: extra,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      final driver = _authService.users.firstWhere(
                        (u) => u.id == order.assignedDriverId,
                        orElse: () => UserModel(id: '', fullName: '', phone: '', email: '', password: '', role: UserRole.driver),
                      );

                      if (updatedOrder != null && driver.phone.isNotEmpty) {
                        final rincianText = WhatsAppService.formatRincianOrderToDriver(
                          updatedOrder,
                          currentDepositBalance: driver.walletBalance,
                        );
                        await WhatsAppService.openWhatsApp(phone: driver.phone, message: rincianText);
                      }
                    }
                  },
                  child: const Text('Simpan & Kirim Rincian WA Driver 📲', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- CRUD: CREATE USER DIALOG (WITH DEFAULT ROLE) ---
  void _showAddUserDialog({required UserRole defaultRole}) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final vehiclePlateController = TextEditingController();
    final vehicleTypeController = TextEditingController(text: 'Honda Vario 125');
    final depositController = TextEditingController(text: '150000');
    UserRole selectedRole = defaultRole;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDriver = selectedRole == UserRole.driver;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(isDriver ? Icons.two_wheeler_rounded : Icons.person_add_rounded, color: isDriver ? Colors.orange : _primaryTeal),
                  const SizedBox(width: 8),
                  Text(
                    isDriver ? 'Tambah Mitra Driver' : 'Tambah Customer Baru',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor WhatsApp',
                        hintText: '088227810296',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Akun',
                        hintText: 'nama@harlesjujug.com',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password Akun',
                        hintText: 'harles123',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isDriver) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: vehiclePlateController,
                              decoration: const InputDecoration(labelText: 'Plat Nomor', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: vehicleTypeController,
                              decoration: const InputDecoration(labelText: 'Tipe Motor', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: depositController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Saldo Deposit Awal (Rp)', border: OutlineInputBorder()),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isDriver ? Colors.orange : _primaryTeal),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty) return;

                    final newUser = UserModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      fullName: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      email: emailController.text.trim(),
                      password: passwordController.text.trim().isEmpty ? 'harles123' : passwordController.text.trim(),
                      role: selectedRole,
                      vehiclePlate: vehiclePlateController.text.trim(),
                      vehicleType: vehicleTypeController.text.trim(),
                      walletBalance: double.tryParse(depositController.text) ?? 150000.0,
                    );

                    await _authService.addUser(newUser);

                    if (context.mounted) {
                      Navigator.pop(context);

                      if (newUser.phone.isNotEmpty) {
                        final waText = WhatsAppService.formatNewAccountToUser(
                          name: newUser.fullName,
                          role: newUser.role.label,
                          email: newUser.email,
                          phone: newUser.phone,
                          password: newUser.password,
                        );
                        await WhatsAppService.openWhatsApp(phone: newUser.phone, message: waText);
                      }
                    }
                  },
                  child: const Text('Simpan & Kirim WA User 📲', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- CRUD: EDIT USER DIALOG ---
  void _showEditUserDialog(UserModel user) {
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone);
    final emailController = TextEditingController(text: user.email);
    UserRole selectedRole = user.role;
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit Data Pengguna', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Nomor WhatsApp', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                      items: UserRole.values.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r.label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Status Akun Aktif', style: TextStyle(fontSize: 14)),
                      value: isActive,
                      activeThumbColor: _primaryTeal,
                      onChanged: (val) => setDialogState(() => isActive = val),
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
                    _authService.updateUser(
                      user.id,
                      fullName: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      email: emailController.text.trim(),
                      role: selectedRole,
                      isActive: isActive,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data pengguna berhasil diperbarui!')),
                    );
                  },
                  child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- CRUD: DELETE USER PERMANENTLY ---
  void _confirmDeleteUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Pengguna Permanen?'),
          content: Text('Apakah Anda yakin ingin menghapus data ${user.fullName}? Tindakan ini tidak dapat dibatalkan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _authService.deleteUser(user.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pengguna ${user.fullName} berhasil dihapus permanen.')),
                );
              },
              child: const Text('Hapus Permanen', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allUsers = _authService.users;
    final allOrders = _orderService.orders;

    final customers = allUsers.where((u) => u.role == UserRole.customer).toList();
    final drivers = allUsers.where((u) => u.role == UserRole.driver).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            AppLogo(height: 30),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Panel Admin', style: TextStyle(color: _darkText, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Dispatch & Kelola Data Terpisah', style: TextStyle(color: _secondaryText, fontSize: 10)),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _darkTeal,
          unselectedLabelColor: _secondaryText,
          indicatorColor: _primaryTeal,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.radar_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Dispatch (${allOrders.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Customer (${customers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.two_wheeler_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Driver (${drivers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: DISPATCH ORDERAN & PETA RADAR FLEET DRIVER
            _buildOrdersDispatchTab(allOrders),

            // TAB 2: DATA CUSTOMER TERPISAH
            _buildCustomerTab(customers),

            // TAB 3: DATA MITRA DRIVER TERPISAH
            _buildDriverTab(drivers),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: ORDER DISPATCH TAB WITH RADAR MAP ---
  Widget _buildOrdersDispatchTab(List<OrderModel> allOrders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Status Orderan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primaryTeal, _darkTeal]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pusat Radar Dispatch Orderan',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${allOrders.where((o) => o.status == OrderStatus.pendingAdmin).length} Orderan Baru Menunggu Penugasan Driver Terdekat',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Live Fleet Radar Map Posisi Seluruh Driver
          DriverFleetRadarMap(
            drivers: _authService.users,
            height: 190,
          ),

          const SizedBox(height: 20),

          const Text(
            'Daftar Masuk Orderan Customer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkText),
          ),

          const SizedBox(height: 12),

          if (allOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('Belum ada orderan masuk dari Customer.', style: TextStyle(color: _secondaryText)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allOrders.length,
              itemBuilder: (context, index) {
                final order = allOrders[index];
                return _buildAdminOrderCard(order);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAdminOrderCard(OrderModel order) {
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
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    const SizedBox(width: 8),
                    Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _secondaryText)),
                  ],
                ),
                Text(
                  order.status.label,
                  style: TextStyle(
                    color: order.status == OrderStatus.pendingAdmin ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text('Customer: ${order.customerName} (+${order.customerPhone})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('$label1: ${order.pickupLocation}', style: const TextStyle(fontSize: 12, color: _secondaryText, fontWeight: FontWeight.w600)),
            Text('$label2: ${order.destinationLocation}', style: const TextStyle(fontSize: 12, color: _secondaryText, fontWeight: FontWeight.w600)),
            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Catatan: "${order.notes}"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Biaya: Rp ${order.totalCustomerBill.toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkTeal),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                      tooltip: 'Atur Rincian Biaya/Nota',
                      onPressed: () => _showOrderFinancialDialog(order),
                    ),
                    if (order.status == OrderStatus.pendingAdmin)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: _primaryTeal),
                        onPressed: () => _showAssignDriverDialog(order),
                        icon: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 16),
                        label: const Text('Tugaskan Driver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    else
                      Text(
                        'Driver: ${order.assignedDriverName ?? "-"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkTeal),
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

  // --- TAB 2: DATA CUSTOMER TERPISAH ---
  Widget _buildCustomerTab(List<UserModel> customers) {
    final filteredCustomers = customers.where((c) {
      final q = _searchQueryCustomer.toLowerCase();
      return c.fullName.toLowerCase().contains(q) || c.email.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Customer Card
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
                    const Text('Total Pelanggan Terdaftar', style: TextStyle(fontSize: 12, color: _secondaryText)),
                    const SizedBox(height: 4),
                    Text('${customers.length} Customer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _darkTeal)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(defaultRole: UserRole.customer),
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                  label: const Text('Tambah Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Field Customer
          TextField(
            onChanged: (val) => setState(() => _searchQueryCustomer = val),
            decoration: InputDecoration(
              hintText: 'Cari nama, email, atau WA Customer...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _secondaryText),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),

          const SizedBox(height: 16),

          // List Cards Customer
          if (filteredCustomers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('Tidak ada data Customer yang ditemukan.', style: TextStyle(color: _secondaryText)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = filteredCustomers[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: _primaryTeal.withValues(alpha: 0.15),
                      child: const Icon(Icons.person_rounded, color: _darkTeal),
                    ),
                    title: Row(
                      children: [
                        Text(customer.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Customer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _darkTeal)),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('${customer.email} • +${customer.phone}', style: const TextStyle(fontSize: 12, color: _secondaryText)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                          onPressed: () => _showEditUserDialog(customer),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDeleteUser(customer),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- TAB 3: DATA MITRA DRIVER TERPISAH ---
  Widget _buildDriverTab(List<UserModel> drivers) {
    final filteredDrivers = drivers.where((d) {
      final q = _searchQueryDriver.toLowerCase();
      return d.fullName.toLowerCase().contains(q) || d.email.toLowerCase().contains(q) || d.phone.contains(q) || d.vehiclePlate.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Driver Card
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
                    const Text('Total Mitra Driver Terdaftar', style: TextStyle(fontSize: 12, color: _secondaryText)),
                    const SizedBox(height: 4),
                    Text('${drivers.length} Driver (${drivers.where((d) => d.isOnbid).length} Online)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(defaultRole: UserRole.driver),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 16),
                  label: const Text('Tambah Driver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Field Driver
          TextField(
            onChanged: (val) => setState(() => _searchQueryDriver = val),
            decoration: InputDecoration(
              hintText: 'Cari nama, plat nomor, atau WA Driver...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _secondaryText),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),

          const SizedBox(height: 16),

          // List Cards Driver
          if (filteredDrivers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('Tidak ada data Driver yang ditemukan.', style: TextStyle(color: _secondaryText)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredDrivers.length,
              itemBuilder: (context, index) {
                final driver = filteredDrivers[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.15),
                      child: const Icon(Icons.two_wheeler_rounded, color: Colors.orange),
                    ),
                    title: Row(
                      children: [
                        Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: driver.isOnbid ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            driver.isOnbid ? '🟢 ONBID' : '⚪ OFFBID',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: driver.isOnbid ? Colors.green : _secondaryText),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Plat: ${driver.vehiclePlate.isNotEmpty ? driver.vehiclePlate : "-"} • ${driver.vehicleType}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkText)),
                          Text('WA: +${driver.phone} • Deposit: Rp ${driver.walletBalance.toInt()}', style: const TextStyle(fontSize: 11, color: _secondaryText)),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                          onPressed: () => _showEditUserDialog(driver),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDeleteUser(driver),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
