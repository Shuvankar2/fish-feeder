import 'dart:convert';
import 'package:http/http.dart' as http;

class EspWifiService {
  static const String espIp = '192.168.4.1';
  static const String infoEndpoint = 'http://$espIp/api/device/info';

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final response = await http.get(Uri.parse(infoEndpoint)).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timed out. Ensure you are connected to the ESP32 Wi-Fi AP (AquaGlass-...).');
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch device info: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('ESP Connection Error: $e\nNote: Browsers may block HTTP requests from HTTPS sites. You might need to allow insecure content.');
    }
  }
}
