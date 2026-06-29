import 'api_service.dart';

class DeviceService {
  /// Get all devices the current user has access to
  static Future<Map<String, dynamic>> listDevices() {
    return ApiService.get('/devices');
  }

  /// Claim a device using its pairing token from QR code
  static Future<Map<String, dynamic>> claimDevice({
    required int deviceId,
    required String serialNumber,
    required String pairingToken,
  }) {
    return ApiService.post('/devices/claim', {
      'device_id': deviceId,
      'serial_number': serialNumber,
      'pairing_token': pairingToken,
    });
  }

  /// Get details of a single device
  static Future<Map<String, dynamic>> getDevice(int deviceId) {
    return ApiService.get('/devices/$deviceId');
  }

  /// Update device name / notes
  static Future<Map<String, dynamic>> updateDevice(int deviceId, Map<String, dynamic> updates) {
    return ApiService.put('/devices/$deviceId', updates);
  }

  /// Trigger a manual feed for a device
  static Future<Map<String, dynamic>> triggerFeed(int deviceId, {int amountGrams = 5}) {
    return ApiService.post('/devices/$deviceId/feed', {'amount_grams': amountGrams});
  }

  /// Get all members of a device
  static Future<Map<String, dynamic>> getMembers(int deviceId) {
    return ApiService.get('/devices/$deviceId/members');
  }

  /// Invite a member by email
  static Future<Map<String, dynamic>> addMember(int deviceId, String email, {String role = 'member'}) {
    return ApiService.post('/devices/$deviceId/members', {'email': email, 'role': role});
  }

  /// Remove a member by UID
  static Future<Map<String, dynamic>> removeMember(int deviceId, String memberUid) {
    return ApiService.delete('/devices/$deviceId/members/$memberUid');
  }
}
