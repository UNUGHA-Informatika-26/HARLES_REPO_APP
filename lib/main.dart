import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (_) {
      // Jika inisialisasi gagal, aplikasi tetap jalan normal
    }
  }

  runApp(const HarlesJujugApp());
}

class HarlesJujugApp extends StatelessWidget {
  const HarlesJujugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harles Jujug',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF13C5BC),
          primary: const Color(0xFF13C5BC),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
