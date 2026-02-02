import 'dart:io';
import 'dart:convert';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  print('🔍 Checking Supabase Connectivity...');

  // 1. Read app_config.json
  final configFile = File('config/app_config.json');
  if (!configFile.existsSync()) {
    print('❌ Error: config/app_config.json not found!');
    exit(1);
  }

  try {
    final jsonString = await configFile.readAsString();
    final config = jsonDecode(jsonString);

    final supabaseConfig = config['supabase'];
    final url = supabaseConfig['project_url'];
    final key = supabaseConfig['anon_key'];

    print('📂 Config loaded:');
    print('   URL: $url');
    print('   Key: ${key.substring(0, 10)}...');

    // 2. Initialize Supabase Client
    final client = SupabaseClient(url, key);

    // 3. Test Connectivity (Health Check)
    try {
      // Trying to select from a public table or just check health
      // We'll try to get the server time or health if available,
      // or just list rows from 'organizations' (publicly readable?) or just auth check.
      // Easiest is to check if we can reach the auth endpoint.

      print('⏳ Testing connection to $url...');
      // Simple fetch to the URL root (often gives a welcome message or 404, but confirms DNS/IP)
      // But we want to check Supabase specifically.

      // Let's try to query 'organizations' with limit 1
      final response = await client
          .from('organizations')
          .select()
          .limit(1)
          .count(CountOption.exact);

      print('✅ Connection Successful!');
      print('   Query result count: ${response.count}');
      print('   Data length: ${response.data.length}');
    } catch (e) {
      print('❌ Connection Failed during query:');
      print('   $e');

      // Try raw socket connection to debug network
      try {
        final uri = Uri.parse(url);
        print('   Trying raw socket connection to ${uri.host}:${uri.port}...');
        final socket = await Socket.connect(
          uri.host,
          uri.port,
          timeout: Duration(seconds: 3),
        );
        print('   ✅ Socket connection successful! (Network is reachable)');
        socket.destroy();
      } catch (socketError) {
        print('   ❌ Socket connection failed: $socketError');
        print('   (This indicates a network/firewall issue or wrong IP)');
      }
    }
  } catch (e) {
    print('❌ Unexpected error: $e');
  }
}
