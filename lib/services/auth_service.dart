import 'api_service.dart';
import '../models/user_session.dart';

class AuthService {
  /// Send 6-digit OTP to email
  static Future<Map<String, dynamic>> sendOtp(String email, String type) {
    return ApiService.post('/auth/send-otp', {'email': email, 'type': type}, auth: false);
  }

  /// Verify OTP code
  static Future<Map<String, dynamic>> verifyOtp(String email, String code, String type) {
    return ApiService.post('/auth/verify-otp', {'email': email, 'code': code, 'type': type}, auth: false);
  }

  /// Register with email/password (OTP must be verified first)
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final res = await ApiService.post(
      '/auth/register',
      {'name': name, 'email': email, 'password': password},
      auth: false,
    );
    if (res['success'] == true && res['token'] != null) {
      await ApiService.saveToken(res['token']);
      _syncSession(res['user']);
    }
    return res;
  }

  /// Login with email + password
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await ApiService.post(
      '/auth/login',
      {'email': email, 'password': password},
      auth: false,
    );
    if (res['success'] == true && res['token'] != null) {
      await ApiService.saveToken(res['token']);
      _syncSession(res['user']);
    }
    return res;
  }

  /// Social login (Google / Facebook)
  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    final res = await ApiService.post(
      '/auth/social-login',
      {'provider': provider, 'email': email, 'name': name, 'avatar_url': avatarUrl},
      auth: false,
    );
    if (res['success'] == true && res['token'] != null) {
      await ApiService.saveToken(res['token']);
      _syncSession(res['user']);
    }
    return res;
  }

  /// Forgot password — sends OTP
  static Future<Map<String, dynamic>> forgotPassword(String email) {
    return ApiService.post('/auth/forgot-password', {'email': email}, auth: false);
  }

  /// Reset password after OTP verified
  static Future<Map<String, dynamic>> resetPassword(String email, String password) {
    return ApiService.post('/auth/reset-password', {'email': email, 'password': password}, auth: false);
  }

  /// Get current user profile
  static Future<Map<String, dynamic>> getMe() {
    return ApiService.get('/auth/me');
  }

  /// Logout — clear token and session
  static Future<void> logout() async {
    await ApiService.clearToken();
    UserSession.currentUser = null;
    UserSession.currentRole = 'user';
  }

  /// Sync backend user data into local UserSession
  static void _syncSession(Map<String, dynamic>? userData) {
    if (userData == null) return;
    final email = userData['email'] as String? ?? '';
    final name = userData['name'] as String? ?? '';
    final role = userData['role'] as String? ?? 'user';
    final providers = List<String>.from(userData['auth_providers'] ?? ['email']);
    final avatarUrl = userData['avatar_url'] as String?;

    var existing = UserSession.findUser(email);
    if (existing == null) {
      existing = UserAccount(
        email: email,
        password: '',
        name: name,
        linkedMethods: providers,
        profilePic: avatarUrl,
        uid: userData['uid'],
        role: role,
      );
      UserSession.accounts.add(existing);
    } else {
      existing.name = name;
      existing.linkedMethods = providers;
      existing.profilePic = avatarUrl;
      existing.uid = userData['uid'];
      existing.role = role;
    }
    UserSession.currentUser = existing;
    UserSession.currentRole = role;
  }
}
