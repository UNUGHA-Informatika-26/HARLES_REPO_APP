import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ayteepsqhkgkenawjmee.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF5dGVlcHNxaGtna2VuYXdqbWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIyNTA2OTgsImV4cCI6MjEwNzgyNjY5OH0.-5254Iv1IvLJGFBuQeh4eXehpuM_r0dsaxdJbCJ8xds';

  /// Cek apakah kredensial Supabase sudah diisi
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE');

  /// Helper akses client Supabase
  static SupabaseClient get client => Supabase.instance.client;
}
