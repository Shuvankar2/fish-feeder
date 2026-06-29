import 'api_service.dart';

class UserService {
  /// Update display name and/or avatar URL
  static Future<Map<String, dynamic>> updateProfile({String? name, String? avatarUrl}) {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    return ApiService.put('/users/profile', body);
  }

  /// Change password (requires old password)
  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) {
    return ApiService.put('/users/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// Link a social login provider (e.g. 'google', 'facebook')
  static Future<Map<String, dynamic>> linkProvider(String provider) {
    return ApiService.post('/users/link-provider', {'provider': provider});
  }

  /// Unlink a social login provider
  static Future<Map<String, dynamic>> unlinkProvider(String provider) {
    return ApiService.post('/users/unlink-provider', {'provider': provider});
  }
}

class AdminService {
  /// Get admin dashboard KPI stats
  static Future<Map<String, dynamic>> getStats() {
    return ApiService.get('/admin/stats');
  }

  /// List all users (paginated, searchable)
  static Future<Map<String, dynamic>> listUsers({int page = 1, String search = ''}) {
    return ApiService.get('/admin/users?page=$page&search=$search');
  }

  /// Update a user's role or active status
  static Future<Map<String, dynamic>> updateUser(String uid, Map<String, dynamic> data) {
    return ApiService.put('/admin/users/$uid', data);
  }

  /// Delete a user
  static Future<Map<String, dynamic>> deleteUser(String uid) {
    return ApiService.delete('/admin/users/$uid');
  }

  /// List all devices (paginated, searchable)
  static Future<Map<String, dynamic>> listDevices({int page = 1, String search = ''}) {
    return ApiService.get('/admin/devices?page=$page&search=$search');
  }

  /// Pre-register a new device (admin only)
  static Future<Map<String, dynamic>> createDevice(Map<String, dynamic> data) {
    return ApiService.post('/admin/devices', data);
  }

  /// Update device fields (tenant, firmware, status)
  static Future<Map<String, dynamic>> updateDevice(int deviceId, Map<String, dynamic> data) {
    return ApiService.put('/admin/devices/$deviceId', data);
  }

  /// Revoke/delete a device
  static Future<Map<String, dynamic>> deleteDevice(int deviceId) {
    return ApiService.delete('/admin/devices/$deviceId');
  }

  /// Transfer ownership to a new user by email
  static Future<Map<String, dynamic>> transferOwnership(int deviceId, String newOwnerEmail) {
    return ApiService.post('/admin/devices/$deviceId/transfer', {'new_owner_email': newOwnerEmail});
  }

  /// Get all feed logs across all devices (admin view)
  static Future<Map<String, dynamic>> getAllFeedLogs({int page = 1, int? deviceId}) {
    var path = '/admin/feedlogs?page=$page';
    if (deviceId != null) path += '&device_id=$deviceId';
    return ApiService.get(path);
  }

  /// Get admin audit logs
  static Future<Map<String, dynamic>> getAdminLogs({int page = 1}) {
    return ApiService.get('/admin/logs?page=$page');
  }

  /// List all Tenants
  static Future<Map<String, dynamic>> listTenants() {
    return ApiService.get('/admin/tenants');
  }

  /// Create a Tenant
  static Future<Map<String, dynamic>> createTenant(String name, String displayName) {
    return ApiService.post('/admin/tenants', {
      'name': name,
      'display_name': displayName,
    });
  }

  /// Delete a Tenant
  static Future<Map<String, dynamic>> deleteTenant(String name) {
    return ApiService.delete('/admin/tenants/$name');
  }

  /// List all Firmware versions
  static Future<Map<String, dynamic>> listFirmwares() {
    return ApiService.get('/admin/firmwares');
  }

  /// Create a new Firmware version
  static Future<Map<String, dynamic>> createFirmware({
    required String version,
    required String changelog,
    required String espCode,
    int sizeKb = 0,
    bool isLatest = false,
  }) {
    return ApiService.post('/admin/firmwares', {
      'version': version,
      'changelog': changelog,
      'esp_code': espCode,
      'size_kb': sizeKb,
      'is_latest': isLatest,
    });
  }

  /// Delete a Firmware version
  static Future<Map<String, dynamic>> deleteFirmware(String version) {
    return ApiService.delete('/admin/firmwares/$version');
  }
}
