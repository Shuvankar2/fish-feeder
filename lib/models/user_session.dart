class UserAccount {
  String email;
  String password;
  String name;
  List<String> linkedMethods; // 'email', 'google', 'facebook'
  String? profilePic;
  String? uid;   // Backend MongoDB uid
  String role;   // 'user' | 'admin'

  UserAccount({
    required this.email,
    required this.password,
    required this.name,
    required this.linkedMethods,
    this.profilePic,
    this.uid,
    this.role = 'user',
  });
}

class UserSession {
  static final List<UserAccount> accounts = [
    UserAccount(
      email: 'user@email.com',
      password: 'user123',
      name: 'Shuvankar Debnath',
      linkedMethods: ['email', 'google'],
      profilePic: null,
      role: 'user',
    ),
    UserAccount(
      email: 'admin@email.com',
      password: 'admin123',
      name: 'Super Admin',
      linkedMethods: ['email'],
      role: 'admin',
    ),
  ];

  static UserAccount? currentUser;
  static String currentRole = 'user';

  /// Whether the session is backed by real backend JWT
  static bool get isAuthenticated => currentUser?.uid != null;

  static UserAccount? findUser(String email) {
    try {
      return accounts.firstWhere(
        (a) => a.email.toLowerCase() == email.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static void register(UserAccount account) {
    if (findUser(account.email) == null) {
      accounts.add(account);
    }
  }

  static void updatePassword(String email, String newPassword) {
    final user = findUser(email);
    if (user != null) user.password = newPassword;
  }

  static void linkMethod(String email, String method) {
    final user = findUser(email);
    if (user != null && !user.linkedMethods.contains(method)) {
      user.linkedMethods.add(method);
    }
  }

  static void unlinkMethod(String email, String method) {
    final user = findUser(email);
    if (user != null && user.linkedMethods.length > 1) {
      user.linkedMethods.remove(method);
    }
  }

  static void clearSession() {
    currentUser = null;
    currentRole = 'user';
  }
}
