import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnackBar('Please fill in all fields', isError: true);
      return;
    }

    if (password != confirm) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.sendOtp(email, 'signup');
      if (!mounted) return;
      if (res['success'] == true) {
        _showSnackBar('Verification code sent to $email');
        setState(() => _isLoading = false);
        _showVerificationDialog(name, email, password);
      } else {
        _showSnackBar(res['message'] ?? 'Failed to send code', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // Fallback: offline mode
      setState(() => _isLoading = false);
      _showSnackBar('Backend unreachable — using offline mode', isError: false);
      _showVerificationDialog(name, email, password, offlineMode: true);
    }
  }

  void _showVerificationDialog(String name, String email, String password, {bool offlineMode = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final otpController = TextEditingController();
        // Offline fallback code (only used if backend is unreachable)
        String offlineCode = (100000 + math.Random().nextInt(900000)).toString();
        int cooldownSecondsLeft = 90;
        Timer? timer;

        if (offlineMode) {
          print('=== OFFLINE OTP: $offlineCode ===');
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (timer == null) {
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                setDialogState(() {
                  cooldownSecondsLeft--;
                  if (cooldownSecondsLeft <= 0) t.cancel();
                });
              });
            }

            void resendCode() async {
              if (offlineMode) {
                offlineCode = (100000 + math.Random().nextInt(900000)).toString();
                print('=== OFFLINE OTP RESENT: $offlineCode ===');
                setDialogState(() => cooldownSecondsLeft = 90);
                return;
              }
              try {
                final res = await AuthService.sendOtp(email, 'signup');
                if (res['success'] == true) {
                  setDialogState(() => cooldownSecondsLeft = 90);
                  _showSnackBar('New code sent to $email');
                } else {
                  _showSnackBar(res['message'] ?? 'Failed to resend', isError: true);
                }
              } catch (_) {
                _showSnackBar('Failed to resend code', isError: true);
              }
            }

            void verifyAndRegister() async {
              final entered = otpController.text.trim();
              if (entered.isEmpty || entered.length != 6) {
                _showSnackBar('Please enter the 6-digit code', isError: true);
                return;
              }

              timer?.cancel();

              if (offlineMode) {
                if (entered != offlineCode) {
                  _showSnackBar('Invalid code', isError: true);
                  return;
                }
                Navigator.pop(context);
                final newUser = UserAccount(
                  email: email, password: password, name: name,
                  linkedMethods: ['email'],
                );
                UserSession.register(newUser);
                UserSession.currentUser = newUser;
                UserSession.currentRole = 'user';
                
                _showSnackBar('Account created (offline mode)! 🎉');
                await Future.delayed(const Duration(milliseconds: 800));
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const DashboardScreen(role: 'user'),
                      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 500),
                    ),
                    (route) => false,
                  );
                }
                return;
              }

              try {
                final verRes = await AuthService.verifyOtp(email, entered, 'signup');
                if (verRes['success'] != true) {
                  _showSnackBar(verRes['message'] ?? 'Invalid code', isError: true);
                  return;
                }

                final regRes = await AuthService.register(name, email, password);
                if (!mounted) return;
                Navigator.pop(context);

                if (regRes['success'] == true) {
                  _showSnackBar('Account created! Welcome, $name! 🎉');
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const DashboardScreen(role: 'user'),
                        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 500),
                      ),
                      (route) => false,
                    );
                  }
                } else {
                  _showSnackBar(regRes['message'] ?? 'Registration failed', isError: true);
                }
              } catch (e) {
                _showSnackBar('Connection error', isError: true);
              }
            }

            return WillPopScope(
              onWillPop: () async {
                timer?.cancel();
                return true;
              },
              child: AlertDialog(
                backgroundColor: const Color(0xFF0A221A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
                ),
                title: Text(
                  'Verify Your Email',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Please enter the 6-digit verification code sent to $email.',
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '6-digit Code',
                          hintStyle: GoogleFonts.outfit(color: Colors.white38),
                          prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white30, size: 18),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      timer?.cancel();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  ),
                  if (cooldownSecondsLeft <= 0)
                    TextButton(
                      onPressed: resendCode,
                      child: Text(
                        'Resend Code',
                        style: GoogleFonts.outfit(color: const Color(0xFF00FF87)),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Text(
                        'Resend in ${cooldownSecondsLeft ~/ 60}:${(cooldownSecondsLeft % 60).toString().padLeft(2, '0')}',
                        style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: verifyAndRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF87),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Verify',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF05120E), Color(0xFF0A221A), Color(0xFF0E3327)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Back button row
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white70, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Logo
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00FF87), Color(0xFF00E676)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FF87).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_add_outlined,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join AquaGlass today',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Glass card
                    _buildGlassCard(
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            hint: 'Full Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            hint: 'Password',
                            icon: Icons.lock_outline,
                            obscure: !_isPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hint: 'Confirm Password',
                            icon: Icons.lock_outline,
                            obscure: !_isConfirmPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Sign up button
                          _buildPillButton(
                            label: _isLoading ? '' : 'Sign Up',
                            onPressed: _isLoading ? null : _handleSignup,
                            isLoading: _isLoading,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00FF87), Color(0xFF00E676)],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Already have account
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Color(0xFF00FF87),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    Gradient? gradient,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF87).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: MaterialButton(
              onPressed: onPressed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(
      {required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: child,
        ),
      ),
    );
  }
}
