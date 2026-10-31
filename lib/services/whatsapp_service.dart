import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';

class WhatsAppService {
  /// Nomor WhatsApp Admin Resmi Harles Jujug
  static const String adminPhone = '6288227810296';

  /// Format nomor HP ke format internasional WhatsApp (628...)
  static String normalizePhone(String rawPhone) {
    String cleaned = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('8')) {
      cleaned = '62$cleaned';
    }
    return cleaned;
  }

  /// Buka WhatsApp dengan nomor tujuan dan pesan yang sudah terisi otomatis
  static Future<bool> openWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = normalizePhone(phone);
    final encodedMessage = Uri.encodeComponent(message);

    // 1. Coba URI skema whatsapp:// langsung (membuka aplikasi WhatsApp tanpa browser)
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback buka via browser
        return await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      try {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  /// Format Surat Tugas Resmi "JUJUG PESENAN" dari Admin ke Driver
  static String formatDispatchToDriver(OrderModel order) {
    final notes = order.notes.trim().isNotEmpty
        ? order.notes.trim()
        : '- 1x Menu/Barang sesuai pesanan';

    // Format list pesanan agar rapi
    final formattedItems = notes
        .split('\n')
        .map((line) => line.trim().startsWith('-') || line.trim().startsWith('*')
            ? line.trim()
            : '- ${line.trim()}')
        .join('\n');

    return '''*JUJUG PESENAN*
_{Layanan Belanja Makanan, Minuman & Barang}_

#Penerima: ${order.customerName}
#Alamat: ${order.destinationLocation}
#Kontak: +${normalizePhone(order.customerPhone)}

1#Outlet / Tempat Beli: ${order.pickupLocation}
#Alamat Outlet: ${order.pickupLocation}
#Daftar Pesanan:
$formattedItems

#Biaya / Tarif: Rp ${order.price.toInt()}
#Kendaraan: 🛵
#Pembayaran: Cash / Transfer
#Status Order: #${order.id}

By *HARLES JUJUG*
_Dekat, Cepat, Siap Membantu_''';
  }

  /// Format Konfirmasi dari Driver ke Pelanggan
  static String formatDriverToCustomer(OrderModel order, String driverName) {
    return '''Halo Kak *${order.customerName}*, saya *$driverName* mitra driver resmi *Harles Jujug* 🛵.

Pesanan Kakak (*#${order.id} - ${order.serviceType}*) sudah saya terima dan sedang saya proses ya kak!

📍 *Titik Beli/Jemput:* ${order.pickupLocation}
🏁 *Titik Antar:* ${order.destinationLocation}
💵 *Ongkir/Biaya:* Rp ${order.price.toInt()}

Jika ada patokan alamat atau pesanan tambahan, silakan balas chat ini ya kak. Mohon ditunggu! 🙏😊''';
  }

  /// Format Pesan dari Pelanggan ke Driver
  static String formatCustomerToDriver(OrderModel order, String customerName) {
    return '''Halo Mas/Mbak Driver (*${order.assignedDriverName ?? 'Harles Jujug'}*) 🛵,

Saya *$customerName* pemesan *#${order.id}*.
Saya ingin konfirmasi mengenai pesanan yang diantar ke:
📍 *${order.destinationLocation}*

Terima kasih banyak ya mas/mbak! 🙏''';
  }

  /// Format Rincian Order & Potongan Bagi Hasil Resmi Harles Jujug ke Driver
  static String formatRincianOrderToDriver(
    OrderModel order, {
    required double currentDepositBalance,
  }) {
    final cleanPhone = normalizePhone(order.customerPhone);
    final parkirStr = order.parkingFee > 0 ? '${order.parkingFee.toInt()}' : '';
    final extraStr = order.extraFee > 0 ? '${order.extraFee.toInt()}' : '0';
    final remainingDeposit = currentDepositBalance.toInt();

    return '''Rincian order *Harles Jujug:*
- Jenis layanan: *${order.serviceCode}*
- Customer: ${order.customerName}      |  Wa.me/$cleanPhone
- Outlet 1: Rp. ${order.outletCost.toInt()},-
- Parkir: Rp. $parkirStr,-
- Tarif Jujug Pesenan: Rp. ${order.deliveryFee.toInt()},-
- Adm: Rp. ${order.adminFee.toInt()},-
- Biaya Tambahan Driver: Rp. $extraStr,-
- *Total: Rp. ${order.totalCustomerBill.toInt()},-*

- Potongan Profit Sharing 20% dan Adm: Rp. ${order.totalCommissionDeduction.toInt()},-
- Saldo Deposit Saat ini: Rp. $remainingDeposit,-''';
  }

  /// Format Kirim Data Akun Baru dari Admin ke Customer atau Driver
  static String formatNewAccountToUser({
    required String name,
    required String role,
    required String email,
    required String phone,
    required String password,
  }) {
    return '''Halo Kak *$name*, akun *Harles Jujug ($role)* Anda telah berhasil dibuatkan & diaktifkan oleh Admin! 🎉

Berikut data login Anda untuk masuk ke aplikasi:
📱 *Email / Nomor WA:* $email / $phone
🔑 *Password:* $password

Silakan buka aplikasi *Harles Jujug*, lalu pilih Masuk (Login) dan masukkan data di atas.
Jika ada kendala saat masuk, silakan hubungi CS/Admin Harles Jujug. Terima kasih! 🙏🛵''';
  }
}
