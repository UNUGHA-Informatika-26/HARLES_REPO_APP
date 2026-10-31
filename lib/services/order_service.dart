import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class OrderService extends ChangeNotifier {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  RealtimeChannel? _realtimeChannel;
  bool _isInitialized = false;

  final List<OrderModel> _orders = [
    OrderModel(
      id: 'ORD-1001',
      serviceType: 'Harles Ride',
      customerId: 'customer-1',
      customerName: 'Budi Santoso',
      customerPhone: '6281298765432',
      pickupLocation: 'Jl. Pemuda No. 12, Pusat Kota',
      destinationLocation: 'Mall Paragon No. 45',
      price: 18000,
      notes: 'Tolong jemput di dekat pos satpam.',
      status: OrderStatus.pendingAdmin,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    OrderModel(
      id: 'ORD-1002',
      serviceType: 'Express Paket',
      customerId: 'customer-1',
      customerName: 'Budi Santoso',
      customerPhone: '6281298765432',
      pickupLocation: 'Toko Buku Sukses, Stasiun',
      destinationLocation: 'Perum Asri Blok C-10',
      price: 25000,
      notes: 'Paket isi dokumen penting.',
      assignedDriverId: 'driver-1',
      assignedDriverName: 'Ahmad Supriadi',
      assignedDriverPhone: '6281311223344',
      status: OrderStatus.driverAssigned,
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
  ];

  List<OrderModel> get orders => List.unmodifiable(_orders);

  /// Inisialisasi Realtime Subscription Supabase untuk tabel `orders`
  Future<void> initRealtimeOrders() async {
    if (!SupabaseConfig.isConfigured || _isInitialized) return;
    _isInitialized = true;

    await fetchOrdersFromSupabase();

    try {
      _realtimeChannel = SupabaseConfig.client
          .channel('public:orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              debugPrint('Realtime order change detected: ${payload.eventType}');
              fetchOrdersFromSupabase();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to orders realtime: $e');
    }
  }

  /// Ambil data orders dari Supabase
  Future<void> fetchOrdersFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;

    try {
      final List<dynamic> res = await SupabaseConfig.client
          .from('orders')
          .select('*, customer:customer_id(full_name, phone), driver:driver_id(full_name, phone)')
          .order('created_at', ascending: false);

      _orders.clear();
      for (final item in res) {
        _orders.add(OrderModel.fromMap(item as Map<String, dynamic>));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching orders from Supabase: $e');
    }
  }

  // 1. Customer: Buat Pesanan Baru
  Future<OrderModel> createOrder({
    required String serviceType,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String pickupLocation,
    required String destinationLocation,
    required double price,
    String notes = '',
  }) async {
    final orderCode =
        'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final newOrder = OrderModel(
      id: orderCode,
      serviceType: serviceType,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: pickupLocation,
      destinationLocation: destinationLocation,
      price: price,
      notes: notes,
      status: OrderStatus.pendingAdmin,
      createdAt: DateTime.now(),
    );

    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.client.from('orders').insert({
          'order_code': orderCode,
          'service_type': serviceType,
          'customer_id': customerId,
          'pickup_address': pickupLocation,
          'dropoff_address': destinationLocation,
          'total_price': price.toInt(),
          'item_notes': notes,
          'status': 'pending',
        });
      } catch (e) {
        debugPrint('Error inserting order to Supabase: $e');
      }
    }

    _orders.insert(0, newOrder);
    notifyListeners();
    return newOrder;
  }

  // 2. Admin: Menugaskan Orderan ke Driver tertentu
  Future<bool> assignDriverToOrder({
    required String orderId,
    required UserModel driver,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].assignedDriverId = driver.id;
      _orders[index].assignedDriverName = driver.fullName;
      _orders[index].assignedDriverPhone = driver.phone;
      _orders[index].status = OrderStatus.driverAssigned;

      if (SupabaseConfig.isConfigured) {
        try {
          await SupabaseConfig.client.from('orders').update({
            'driver_id': driver.id,
            'status': 'assigned',
          }).or('order_code.eq.$orderId,id.eq.$orderId');
        } catch (e) {
          debugPrint('Error assigning driver in Supabase: $e');
        }
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  // 3. Driver: Jalankan Orderan
  Future<bool> startOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].status = OrderStatus.inProgress;

      if (SupabaseConfig.isConfigured) {
        try {
          await SupabaseConfig.client
              .from('orders')
              .update({'status': 'in_progress'})
              .or('order_code.eq.$orderId,id.eq.$orderId');
        } catch (e) {
          debugPrint('Error updating order status in Supabase: $e');
        }
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  // 4. Driver: Selesaikan Orderan
  Future<bool> completeOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].status = OrderStatus.completed;

      if (SupabaseConfig.isConfigured) {
        try {
          await SupabaseConfig.client
              .from('orders')
              .update({'status': 'completed'})
              .or('order_code.eq.$orderId,id.eq.$orderId');
        } catch (e) {
          debugPrint('Error completing order in Supabase: $e');
        }
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  // 5. Admin / Customer: Batal Orderan
  Future<bool> cancelOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].status = OrderStatus.cancelled;

      if (SupabaseConfig.isConfigured) {
        try {
          await SupabaseConfig.client
              .from('orders')
              .update({'status': 'cancelled'})
              .or('order_code.eq.$orderId,id.eq.$orderId');
        } catch (e) {
          debugPrint('Error cancelling order in Supabase: $e');
        }
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  // 6. Admin / Customer: Hapus Permanen Orderan
  Future<bool> deleteOrder(String orderId) async {
    final initialLength = _orders.length;
    _orders.removeWhere((o) => o.id == orderId);
    if (_orders.length < initialLength) {
      if (SupabaseConfig.isConfigured) {
        try {
          await SupabaseConfig.client
              .from('orders')
              .delete()
              .or('order_code.eq.$orderId,id.eq.$orderId');
        } catch (e) {
          debugPrint('Error deleting order in Supabase: $e');
        }
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  // Helper Getters for Specific Roles
  List<OrderModel> getOrdersForCustomer(String customerId) {
    return _orders.where((o) => o.customerId == customerId).toList();
  }

  List<OrderModel> getOrdersForDriver(String driverId) {
    return _orders.where((o) => o.assignedDriverId == driverId).toList();
  }

  List<OrderModel> getPendingOrdersForAdmin() {
    return _orders.where((o) => o.status == OrderStatus.pendingAdmin).toList();
  }

  /// Perhitungan Tarif Dinamis Berdasarkan Jarak Penjemputan & Pengantaran
  /// - Anter Penumpang (Harles Ride / Car / Ojek): Minimal Rp 9.000 (s/d 2 km), selanjutnya Rp 3.000 / km.
  /// - Paketan & Belikan Makanan/Barang (Express, Food, Mart, Jujug): Minimal Rp 8.000 (s/d 2 km), selanjutnya Rp 2.500 / km.
  static double calculateDynamicTariff({
    required String serviceType,
    required double distanceKm,
  }) {
    final cleanService = serviceType.toLowerCase();
    final isPassengerRide = cleanService.contains('ride') ||
        cleanService.contains('car') ||
        cleanService.contains('ojek') ||
        cleanService.contains('penumpang');

    final double minPrice = isPassengerRide ? 9000.0 : 8000.0;
    final double ratePerKm = isPassengerRide ? 3000.0 : 2500.0;
    const double baseDistance = 2.0; // 2 km pertama masuk tarif minimal

    if (distanceKm <= baseDistance) {
      return minPrice;
    } else {
      final extraDistance = distanceKm - baseDistance;
      final calculatedPrice = minPrice + (extraDistance * ratePerKm);
      // Pembulatan ke kelipatan Rp 500 terdekat
      return (calculatedPrice / 500).round() * 500.0;
    }
  }

  /// Update rincian biaya pesanan & bagi hasil
  Future<OrderModel?> updateOrderFinancials({
    required String orderId,
    required double outletCost,
    required double deliveryFee,
    double parkingFee = 0,
    double adminFee = 500,
    double extraFee = 0,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final updated = _orders[index].copyWith(
        outletCost: outletCost,
        deliveryFee: deliveryFee,
        parkingFee: parkingFee,
        adminFee: adminFee,
        extraFee: extraFee,
        price: deliveryFee,
      );
      _orders[index] = updated;

      if (SupabaseConfig.isConfigured) {
        try {
          await SupabaseConfig.client.from('orders').update({
            'total_price': updated.totalCustomerBill.toInt(),
            'outlet_cost': outletCost.toInt(),
            'delivery_fee': deliveryFee.toInt(),
            'parking_fee': parkingFee.toInt(),
            'admin_fee': adminFee.toInt(),
            'extra_fee': extraFee.toInt(),
          }).or('order_code.eq.$orderId,id.eq.$orderId');
        } catch (e) {
          debugPrint('Error updating order financials in Supabase: $e');
        }
      }

      notifyListeners();
      return updated;
    }
    return null;
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
