enum UserRole { customer, driver, admin }

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.driver:
        return 'Driver';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class UserModel {
  String id;
  String fullName;
  String phone;
  String email;
  String password;
  UserRole role;
  bool isActive;
  bool isOnbid;
  String currentLocation;
  double latitude;
  double longitude;
  int dailyOnbidMinutes;
  String vehiclePlate;
  String vehicleType;
  double walletBalance; // Saldo Deposit Driver / Saldo HarlesPay

  UserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.password,
    required this.role,
    this.isActive = true,
    this.isOnbid = false,
    this.currentLocation = 'Jeruklegi, Cilacap',
    this.latitude = -7.7021,
    this.longitude = 109.0234,
    this.dailyOnbidMinutes = 0,
    this.vehiclePlate = '',
    this.vehicleType = '',
    this.walletBalance = 150000.0,
  });

  int get onbidHours => dailyOnbidMinutes ~/ 60;
  int get onbidRemainingMinutes => dailyOnbidMinutes % 60;
  bool get isExceeded18Hours => dailyOnbidMinutes >= 1080;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    UserRole parsedRole = UserRole.customer;
    final roleString = map['role']?.toString().toLowerCase();
    if (roleString == 'driver') {
      parsedRole = UserRole.driver;
    } else if (roleString == 'admin') {
      parsedRole = UserRole.admin;
    }

    return UserModel(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? map['fullName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      role: parsedRole,
      isActive: map['is_active'] ?? map['isActive'] ?? true,
      isOnbid: map['is_onbid'] ?? map['is_online'] ?? map['isOnbid'] ?? false,
      currentLocation: map['current_location']?.toString() ??
          map['currentLocation']?.toString() ??
          'Pusat Kota Harles',
      latitude: (map['latitude'] ?? map['lat'] ?? -7.7021).toDouble(),
      longitude: (map['longitude'] ?? map['lng'] ?? 109.0234).toDouble(),
      dailyOnbidMinutes: map['daily_onbid_minutes'] ??
          map['dailyOnbidMinutes'] ??
          0,
      vehiclePlate: map['vehicle_plate']?.toString() ?? map['vehiclePlate']?.toString() ?? '',
      vehicleType: map['vehicle_type']?.toString() ?? map['vehicleType']?.toString() ?? '',
      walletBalance: (map['wallet_balance'] ?? map['walletBalance'] ?? 150000).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role.name,
      'is_active': isActive,
      'is_onbid': isOnbid,
      'is_online': isOnbid,
      'current_location': currentLocation,
      'latitude': latitude,
      'longitude': longitude,
      'daily_onbid_minutes': dailyOnbidMinutes,
      'vehicle_plate': vehiclePlate,
      'vehicle_type': vehicleType,
      'wallet_balance': walletBalance.toInt(),
    };
  }
}
