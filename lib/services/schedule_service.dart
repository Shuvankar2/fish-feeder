import 'api_service.dart';

class ScheduleService {
  /// Get all schedules for a device
  static Future<Map<String, dynamic>> getSchedules(int deviceId) {
    return ApiService.get('/schedules/$deviceId');
  }

  /// Create a new schedule for a device
  static Future<Map<String, dynamic>> createSchedule(
    int deviceId, {
    required String label,
    required String time,
    required List<String> days,
    int amountGrams = 5,
    bool isActive = true,
  }) {
    return ApiService.post('/schedules/$deviceId', {
      'label': label,
      'time': time,
      'days': days,
      'amount_grams': amountGrams,
      'is_active': isActive,
    });
  }

  /// Delete a schedule by its MongoDB _id
  static Future<Map<String, dynamic>> deleteSchedule(int deviceId, String scheduleId) {
    return ApiService.delete('/schedules/$deviceId/$scheduleId');
  }
}

class FeedLogService {
  /// Get paginated feed logs for a device
  static Future<Map<String, dynamic>> getLogs(
    int deviceId, {
    int page = 1,
    int limit = 20,
    String? date, // format: 'YYYY-MM-DD'
  }) {
    var path = '/feedlogs/$deviceId?page=$page&limit=$limit';
    if (date != null) path += '&date=$date';
    return ApiService.get(path);
  }
}
