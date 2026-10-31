enum OrderStatus {
  pendingAdmin,   // Customer baru membuat pesanan, menunggu diproses Admin
  driverAssigned, // Admin telah menunjuk/menugaskan Driver
  inProgress,     // Driver sedang menuju lokasi / mengantar
  completed,      // Pesanan selesai
  cancelled,      // Pesanan dibatalkan
}

extension OrderStatusExtension on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pendingAdmin:
        return 'Menunggu Admin';
      case OrderStatus.driverAssigned:
        return 'Driver Ditugaskan';
      case OrderStatus.inProgress:
        return 'Dalam Perjalanan';
      case OrderStatus.completed:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
    }
  }
}

class OrderModel {
  final String id;
  final String serviceType; // e.g. "Jujug Pesenan", "Harles Ride", "Express Paket"
  final String serviceCode; // e.g. "JPS MTR", "RIDE", "EXPRESS"
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String pickupLocation;
  final String destinationLocation;
  final double price; // default ongkir dasar
  final String notes;

  // Rincian Biaya Transaksi & Bagi Hasil
  final double outletCost;   // Belanja di Warung/Outlet (ditalangi driver)
  final double parkingFee;   // Biaya Parkir
  final double deliveryFee;  // Tarif Ongkir Jujug Pesenan
  final double adminFee;     // Biaya Administrasi Kantor/Aplikasi
  final double extraFee;     // Biaya Tambahan Driver (Tips / Area Jauh)
  final double profitSharingPercentage; // Default 20% (0.20)

  String? assignedDriverId;
  String? assignedDriverName;
  String? assignedDriverPhone;

  OrderStatus status;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.serviceType,
    String? serviceCode,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.price,
    this.notes = '',
    double? outletCost,
    double? parkingFee,
    double? deliveryFee,
    double? adminFee,
    double? extraFee,
    double? profitSharingPercentage,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedDriverPhone,
    this.status = OrderStatus.pendingAdmin,
    required this.createdAt,
  })  : serviceCode = serviceCode ?? _deriveServiceCode(serviceType),
        outletCost = outletCost ?? 0.0,
        parkingFee = parkingFee ?? 0.0,
        deliveryFee = deliveryFee ?? (price > 0 ? price : 8000.0),
        adminFee = adminFee ?? 500.0,
        extraFee = extraFee ?? 0.0,
        profitSharingPercentage = profitSharingPercentage ?? 20.0;

  static String _deriveServiceCode(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('pesen') || lower.contains('jps')) return 'JPS MTR';
    if (lower.contains('car') || lower.contains('mobil')) return 'CAR';
    if (lower.contains('paket') || lower.contains('express')) return 'EXPRESS';
    if (lower.contains('food') || lower.contains('kuliner')) return 'FOOD';
    if (lower.contains('mart') || lower.contains('belanja')) return 'MART';
    return 'JPS MTR';
  }

  /// Total yang wajib dibayar oleh Customer (Belanja + Parkir + Ongkir + Adm + Tambahan)
  double get totalCustomerBill =>
      outletCost + parkingFee + deliveryFee + adminFee + extraFee;

  /// Nominal Potongan Bagi Hasil Kantor dari Ongkir (misal: 20% x Rp 8.000 = Rp 1.600)
  double get profitSharingAmount =>
      deliveryFee * (profitSharingPercentage / 100.0);

  /// Total Potongan ke Saldo Deposit Driver (Profit Sharing 20% + Adm Rp 500 = Rp 2.100)
  double get totalCommissionDeduction => profitSharingAmount + adminFee;

  /// Penghasilan Bersih Driver dari Ongkir (Ongkir 80% + Biaya Tambahan Driver)
  double get driverNetEarnings =>
      (deliveryFee - profitSharingAmount) + extraFee;

  OrderModel copyWith({
    String? id,
    String? serviceType,
    String? serviceCode,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? pickupLocation,
    String? destinationLocation,
    double? price,
    String? notes,
    double? outletCost,
    double? parkingFee,
    double? deliveryFee,
    double? adminFee,
    double? extraFee,
    double? profitSharingPercentage,
    String? assignedDriverId,
    String? assignedDriverName,
    String? assignedDriverPhone,
    OrderStatus? status,
    DateTime? createdAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      serviceType: serviceType ?? this.serviceType,
      serviceCode: serviceCode ?? this.serviceCode,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      outletCost: outletCost ?? this.outletCost,
      parkingFee: parkingFee ?? this.parkingFee,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      adminFee: adminFee ?? this.adminFee,
      extraFee: extraFee ?? this.extraFee,
      profitSharingPercentage: profitSharingPercentage ?? this.profitSharingPercentage,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      assignedDriverPhone: assignedDriverPhone ?? this.assignedDriverPhone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    OrderStatus parsedStatus = OrderStatus.pendingAdmin;
    final statusStr = map['status']?.toString();
    switch (statusStr) {
      case 'assigned':
      case 'driverAssigned':
        parsedStatus = OrderStatus.driverAssigned;
        break;
      case 'in_progress':
      case 'inProgress':
        parsedStatus = OrderStatus.inProgress;
        break;
      case 'completed':
        parsedStatus = OrderStatus.completed;
        break;
      case 'cancelled':
        parsedStatus = OrderStatus.cancelled;
        break;
      default:
        parsedStatus = OrderStatus.pendingAdmin;
    }

    final customerData = map['customer'] as Map<String, dynamic>?;
    final driverData = map['driver'] as Map<String, dynamic>?;

    return OrderModel(
      id: map['order_code']?.toString() ?? map['id']?.toString() ?? '',
      serviceType: map['service_type']?.toString() ?? map['serviceType']?.toString() ?? 'Jujug Pesenan',
      serviceCode: map['service_code']?.toString() ?? map['serviceCode']?.toString(),
      customerId: map['customer_id']?.toString() ?? map['customerId']?.toString() ?? '',
      customerName: customerData?['full_name']?.toString() ??
          map['customer_name']?.toString() ??
          map['customerName']?.toString() ??
          'Pelanggan',
      customerPhone: customerData?['phone']?.toString() ??
          map['customer_phone']?.toString() ??
          map['customerPhone']?.toString() ??
          '',
      pickupLocation: map['pickup_address']?.toString() ??
          map['pickupLocation']?.toString() ??
          '',
      destinationLocation: map['dropoff_address']?.toString() ??
          map['destinationLocation']?.toString() ??
          '',
      price: (map['total_price'] ?? map['price'] ?? 8000).toDouble(),
      notes: map['item_notes']?.toString() ?? map['notes']?.toString() ?? '',
      outletCost: (map['outlet_cost'] ?? map['outletCost'] ?? 0).toDouble(),
      parkingFee: (map['parking_fee'] ?? map['parkingFee'] ?? 0).toDouble(),
      deliveryFee: (map['delivery_fee'] ?? map['deliveryFee'] ?? map['total_price'] ?? 8000).toDouble(),
      adminFee: (map['admin_fee'] ?? map['adminFee'] ?? 500).toDouble(),
      extraFee: (map['extra_fee'] ?? map['extraFee'] ?? 0).toDouble(),
      assignedDriverId: map['driver_id']?.toString() ?? map['assignedDriverId']?.toString(),
      assignedDriverName: driverData?['full_name']?.toString() ?? map['assignedDriverName']?.toString(),
      assignedDriverPhone: driverData?['phone']?.toString() ?? map['assignedDriverPhone']?.toString(),
      status: parsedStatus,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['createdAt'] is DateTime ? map['createdAt'] : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    String statusString = 'pending';
    switch (status) {
      case OrderStatus.pendingAdmin:
        statusString = 'pending';
        break;
      case OrderStatus.driverAssigned:
        statusString = 'assigned';
        break;
      case OrderStatus.inProgress:
        statusString = 'in_progress';
        break;
      case OrderStatus.completed:
        statusString = 'completed';
        break;
      case OrderStatus.cancelled:
        statusString = 'cancelled';
        break;
    }

    return {
      'order_code': id,
      'service_type': serviceType,
      'service_code': serviceCode,
      'customer_id': customerId,
      'driver_id': assignedDriverId,
      'status': statusString,
      'pickup_address': pickupLocation,
      'dropoff_address': destinationLocation,
      'item_notes': notes,
      'outlet_cost': outletCost.toInt(),
      'parking_fee': parkingFee.toInt(),
      'delivery_fee': deliveryFee.toInt(),
      'admin_fee': adminFee.toInt(),
      'extra_fee': extraFee.toInt(),
      'total_price': totalCustomerBill.toInt(),
    };
  }
}
