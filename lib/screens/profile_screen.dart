import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart'; // Contains UserService
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isChangingPassword = false;
  bool _isLinking = false;

  // Preset avatars for the DP selection option
  final List<Map<String, String>> _presetAvatars = [
    {'name': 'Neon Goldfish', 'emoji': '🐠'},
    {'name': 'Clownfish', 'emoji': '🤡'},
    {'name': 'Sharky', 'emoji': '🦈'},
    {'name': 'Octo', 'emoji': '🐙'},
    {'name': 'Aqua Whale', 'emoji': '🐋'},
    {'name': 'Deep Sea Diver', 'emoji': '🧑‍🚀'},
  ];

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        backgroundColor:
            isError ? Colors.redAccent.withOpacity(0.9) : const Color(0xFF00FF87),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }

  // Choose profile photo preset sheet
  void _showChangeDpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A221A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: const Color(0xFF00FF87).withOpacity(0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Profile Avatar',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _presetAvatars.length,
                    itemBuilder: (context, index) {
                      final preset = _presetAvatars[index];
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          setState(() => _isLinking = true);
                          try {
                            final res = await UserService.updateProfile(avatarUrl: preset['emoji']);
                            if (res['success'] == true) {
                              setState(() {
                                UserSession.currentUser?.profilePic = preset['emoji'];
                              });
                              _showSnackBar('Profile picture updated to ${preset['name']}! 🎉');
                            } else {
                              _showSnackBar(res['message'] ?? 'Failed to update avatar', isError: true);
                            }
                          } catch (_) {
                            _showSnackBar('Connection failed', isError: true);
                          }
                          setState(() => _isLinking = false);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                preset['emoji']!,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                preset['name']!,
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleLink(String method) async {
    setState(() => _isLinking = true);
    try {
      final res = await UserService.linkProvider(method.toLowerCase());
      if (res['success'] == true) {
        setState(() {
          UserSession.linkMethod(UserSession.currentUser!.email, method);
        });
        _showSnackBar('$method linked to your account successfully! 🔗');
      } else {
        _showSnackBar(res['message'] ?? 'Failed to link $method', isError: true);
      }
    } catch (_) {
      _showSnackBar('Connection error', isError: true);
    }
    setState(() => _isLinking = false);
  }

  void _handleUnlink(String method) async {
    final linked = UserSession.currentUser!.linkedMethods;
    if (linked.length <= 1) {
      _showSnackBar('Cannot unlink. You must keep at least one login method.', isError: true);
      return;
    }
    setState(() => _isLinking = true);
    try {
      final res = await UserService.unlinkProvider(method.toLowerCase());
      if (res['success'] == true) {
        setState(() {
          UserSession.unlinkMethod(UserSession.currentUser!.email, method);
        });
        _showSnackBar('$method unlinked from your account successfully! 🔓');
      } else {
        _showSnackBar(res['message'] ?? 'Failed to unlink $method', isError: true);
      }
    } catch (_) {
      _showSnackBar('Connection error', isError: true);
    }
    setState(() => _isLinking = false);
  }

  void _handleChangePassword() async {
    final curr = _currentPassController.text;
    final newP = _newPassController.text;
    final conf = _confirmPassController.text;

    if (curr.isEmpty || newP.isEmpty || conf.isEmpty) {
      _showSnackBar('Please fill in all password fields', isError: true);
      return;
    }

    if (newP.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    if (newP != conf) {
      _showSnackBar('New passwords do not match', isError: true);
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final res = await UserService.changePassword(curr, newP);
      if (res['success'] == true) {
        setState(() {
          UserSession.updatePassword(UserSession.currentUser!.email, newP);
          _currentPassController.clear();
          _newPassController.clear();
          _confirmPassController.clear();
        });
        _showSnackBar('Password updated successfully! 🔒');
      } else {
        _showSnackBar(res['message'] ?? 'Failed to change password', isError: true);
      }
    } catch (_) {
      _showSnackBar('Connection error', isError: true);
    }

    setState(() => _isChangingPassword = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('No User Found')));

    final name = user.name;
    final email = user.email;
    final avatarDisplay = user.profilePic ?? (name.isNotEmpty ? name[0].toUpperCase() : 'S');
    final isEmojiAvatar = user.profilePic != null && user.profilePic!.runes.length <= 2;

    return Scaffold(
      backgroundColor: const Color(0xFF05120E),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Navigation Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Account Settings',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // DP / Profile Header (Expanding Avatar layout)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // DP Container with Edit Camera option
                    GestureDetector(
                      onTap: _showChangeDpSheet,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Hero(
                            tag: 'user-avatar',
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF00FF87).withOpacity(0.15),
                                border: Border.all(color: const Color(0xFF00FF87).withOpacity(0.3), width: 2),
                              ),
                              alignment: Alignment.center,
                              child: user.profilePic == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Color(0xFF00FF87),
                                      size: 48,
                                    )
                                  : Text(
                                      user.profilePic!,
                                      style: const TextStyle(fontSize: 48),
                                    ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00FF87),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Glass container body containing settings
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    // Linked login methods card
                    _buildSettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LINKED LOGIN METHODS',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00FF87),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildMethodRow('Email', Icons.email_outlined, Colors.blueAccent),
                          _buildMethodRow('Google', Icons.g_mobiledata_rounded, Colors.redAccent),
                          _buildMethodRow('Facebook', Icons.facebook_outlined, const Color(0xFF1877F2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password change card
                    _buildSettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHANGE PASSWORD',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00FF87),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingsField(
                            controller: _currentPassController,
                            hint: 'Current Password',
                            icon: Icons.lock_outline,
                          ),
                          const SizedBox(height: 10),
                          _buildSettingsField(
                            controller: _newPassController,
                            hint: 'New Password',
                            icon: Icons.vpn_key_outlined,
                          ),
                          const SizedBox(height: 10),
                          _buildSettingsField(
                            controller: _confirmPassController,
                            hint: 'Confirm New Password',
                            icon: Icons.lock_reset_outlined,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isChangingPassword ? null : _handleChangePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FF87),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: const Color(0xFF00FF87).withOpacity(0.3),
                              ),
                              child: _isChangingPassword
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Update Password',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Log out button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await AuthService.logout();
                          if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(
                          'Log Out',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.08),
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _buildMethodRow(String method, IconData icon, Color color) {
    final linked = UserSession.currentUser!.linkedMethods;
    final isLinked = linked.contains(method);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: isLinked ? color : Colors.white24, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method,
                  style: GoogleFonts.outfit(
                    color: isLinked ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isLinked ? 'Linked' : 'Not Linked',
                  style: GoogleFonts.outfit(
                    color: isLinked ? const Color(0xFF00FF87) : Colors.white24,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isLinked)
            ElevatedButton(
              onPressed: linked.length > 1 ? () => _handleUnlink(method) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.08),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                ),
              ),
              child: Text('Unlink', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            ElevatedButton(
              onPressed: () => _handleLink(method),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF87).withOpacity(0.08),
                foregroundColor: const Color(0xFF00FF87),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.4)),
                ),
              ),
              child: Text('Link', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white30, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
