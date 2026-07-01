class SerialService {
  static Future<String> getESPParameters(String? secret) async {
    throw Exception('Wired Serial COM is only supported in web browsers.');
  }

  static Future<void> flashFirmware(String base64Data, Function(double) onProgress) async {
    throw Exception('Flashing firmware is only supported in web browsers.');
  }
}
