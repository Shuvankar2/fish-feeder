import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../models/user_session.dart';
import '../config/auth_config.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  int _selectedTab = 0; // 0 = User, 1 = Admin

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Test credentials
  static const Map<String, Map<String, String>> _testCredentials = {
    'user': {'email': 'user@email.com', 'password': 'user123'},
    'admin': {'email': 'admin@email.com', 'password': 'admin123'},
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.login(email, password);
      if (!mounted) return;

      if (res['success'] == true) {
        final role = UserSession.currentRole;
        final name = UserSession.currentUser?.name ?? 'User';
        _showSnackBar('Welcome, $name! 🎉');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => role == 'admin'
                  ? const AdminDashboardScreen()
                  : DashboardScreen(role: role),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        _showSnackBar(res['message'] ?? 'Invalid credentials', isError: true);
      }
    } catch (e) {
      _showSnackBar('Connection failed. Check your internet.', isError: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _executeMockLogin(bool isGoogle) async {
    setState(() => _isLoading = true);
    final email = isGoogle ? 'google_user@email.com' : 'facebook_user@email.com';
    final name = isGoogle ? 'Google Test User' : 'Facebook Test User';
    final provider = isGoogle ? 'google' : 'facebook';

    try {
      final res = await AuthService.socialLogin(
        provider: provider,
        email: email,
        name: name,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        _showSnackBar('${isGoogle ? "Google" : "Facebook"} Sign-In Successful! 🎉');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardScreen(role: 'user'),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        _showSnackBar(res['message'] ?? 'Social login failed', isError: true);
      }
    } catch (e) {
      _showSnackBar('Connection failed. Check backend is running.', isError: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showConfigAlert(bool isGoogle) {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A221A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
        ),
        title: Text(
          'OAuth Configuration Required',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Google / Facebook OAuth keys are missing in lib/config/auth_config.dart.\n\n'
          'To run the real flow:\n'
          '1. Paste your Web Client ID / App ID into auth_config.dart.\n'
          '2. Restart the app.\n\n'
          'Would you like to simulate a successful login for local testing?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white30)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF87),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _executeMockLogin(isGoogle);
            },
            child: Text('Simulate Login', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _handleGoogleLogin() async {
    if (AuthConfig.googleClientIdWeb.isEmpty) {
      _showConfigAlert(true);
      return;
    }

    setState(() => _isLoading = true);
    _showSnackBar('Connecting to Google Sign-In SDK...');
    
    try {
      await GoogleSignIn.instance.initialize(
        clientId: AuthConfig.googleClientIdWeb,
      );
      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();
      
      if (account != null) {
        final email = account.email;
        final name = account.displayName ?? 'Google User';
        
        var user = UserSession.findUser(email);
        if (user == null) {
          user = UserAccount(
            email: email,
            password: 'social_login_default',
            name: name,
            linkedMethods: ['Google'],
          );
          UserSession.accounts.add(user);
        } else {
          if (!user.linkedMethods.contains('Google')) {
            user.linkedMethods.add('Google');
          }
        }
        
        UserSession.currentUser = user;
        UserSession.currentRole = 'user';
        _showSnackBar('Google Sign-In Successful! 🎉');
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardScreen(role: 'user'),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
    } catch (e) {
      _showSnackBar('Google Login failed: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  void _handleFacebookLogin() async {
    if (AuthConfig.facebookAppId.isEmpty) {
      _showConfigAlert(false);
      return;
    }

    setState(() => _isLoading = true);
    _showSnackBar('Connecting to Facebook Login SDK...');
    
    try {
      if (kIsWeb) {
        await FacebookAuth.instance.webAndDesktopInitialize(
          appId: AuthConfig.facebookAppId,
          cookie: true,
          xfbml: true,
          version: "v15.0",
        );
      }
      
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );
      
      if (result.status == LoginStatus.success) {
        final userData = await FacebookAuth.instance.getUserData();
        final email = userData['email'] ?? 'facebook_user@email.com';
        final name = userData['name'] ?? 'Facebook User';
        
        var user = UserSession.findUser(email);
        if (user == null) {
          user = UserAccount(
            email: email,
            password: 'social_login_default',
            name: name,
            linkedMethods: ['Facebook'],
          );
          UserSession.accounts.add(user);
        } else {
          if (!user.linkedMethods.contains('Facebook')) {
            user.linkedMethods.add('Facebook');
          }
        }
        
        UserSession.currentUser = user;
        UserSession.currentRole = 'user';
        _showSnackBar('Facebook Sign-In Successful! 🎉');
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardScreen(role: 'user'),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        _showSnackBar('Facebook Login status: ${result.message}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Facebook Login failed: $e', isError: true);
    }
    setState(() => _isLoading = false);
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

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final emailController = TextEditingController();
        final otpController = TextEditingController();
        final passwordController = TextEditingController();
        final confirmPasswordController = TextEditingController();

        int step = 1; // 1 = Enter Email, 2 = Enter Code & Reset
        String? generatedOtp;
        DateTime? otpExpiry;
        DateTime? nextAllowedResend;
        Timer? cooldownTimer;
        int cooldownSecondsLeft = 0;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void startCooldown() {
              nextAllowedResend = DateTime.now().add(const Duration(seconds: 90));
              cooldownSecondsLeft = 90;
              cooldownTimer?.cancel();
              cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                setDialogState(() {
                  cooldownSecondsLeft = nextAllowedResend!.difference(DateTime.now()).inSeconds;
                  if (cooldownSecondsLeft <= 0) {
                    timer.cancel();
                  }
                });
              });
            }

            void sendOtp(String email) async {
              if (email.isEmpty) {
                _showSnackBar('Please enter your email address', isError: true);
                return;
              }

              final user = UserSession.findUser(email);
              if (user == null) {
                _showSnackBar('No registered user found with this email.', isError: true);
                return;
              }

              setDialogState(() => isSubmitting = true);
              await Future.delayed(const Duration(milliseconds: 1000));

              // Generate random 6 digit code
              final code = (100000 + math.Random().nextInt(900000)).toString();
              generatedOtp = code;
              otpExpiry = DateTime.now().add(const Duration(minutes: 15));

              // Print to console (Mock Nodemailer)
              print('=====================================================');
              print('[NODEMAILER SMTP SERVER] sending to $email...');
              print('From: noreply.noteloom@gmail.com');
              print('Subject: AquaGlass OTP Verification Code');
              print('Body: Your 6-digit verification code is: $code');
              print('This code is valid for 15 minutes.');
              print('=====================================================');

              _showSnackBar('Code sent to $email: $code (Check console)');
              startCooldown();

              setDialogState(() {
                isSubmitting = false;
                step = 2;
              });
            }

            void handleReset() async {
              final code = otpController.text.trim();
              final pass = passwordController.text.trim();
              final confirm = confirmPasswordController.text.trim();

              if (code.isEmpty || pass.isEmpty || confirm.isEmpty) {
                _showSnackBar('Please fill in all verification fields', isError: true);
                return;
              }

              if (code != generatedOtp) {
                _showSnackBar('Invalid verification code.', isError: true);
                return;
              }

              if (DateTime.now().isAfter(otpExpiry!)) {
                _showSnackBar('Verification code has expired (15 mins limit).', isError: true);
                return;
              }

              if (pass != confirm) {
                _showSnackBar('Passwords do not match', isError: true);
                return;
              }

              if (pass.length < 6) {
                _showSnackBar('Password must be at least 6 characters', isError: true);
                return;
              }

              setDialogState(() => isSubmitting = true);
              await Future.delayed(const Duration(milliseconds: 1000));

              UserSession.updatePassword(emailController.text.trim(), pass);

              _showSnackBar('Password reset successful! 🎉');
              cooldownTimer?.cancel();
              if (context.mounted) Navigator.pop(context);
            }

            return WillPopScope(
              onWillPop: () async {
                cooldownTimer?.cancel();
                return true;
              },
              child: AlertDialog(
                backgroundColor: const Color(0xFF0A221A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
                ),
                title: Text(
                  step == 1 ? 'Forgot Password' : 'Verify Email & Reset',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (step == 1) ...[
                        Text(
                          'Enter your email to receive a 6-digit verification code.',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        _buildDialogField(
                          controller: emailController,
                          hint: 'Email Address',
                          icon: Icons.email_outlined,
                        ),
                      ] else ...[
                        Text(
                          'A 6-digit code has been sent to ${emailController.text}.',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _buildDialogField(
                          controller: otpController,
                          hint: '6-digit Code',
                          icon: Icons.vpn_key_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        _buildDialogField(
                          controller: passwordController,
                          hint: 'New Password',
                          icon: Icons.lock_outline,
                          obscure: true,
                        ),
                        const SizedBox(height: 12),
                        _buildDialogField(
                          controller: confirmPasswordController,
                          hint: 'Confirm Password',
                          icon: Icons.lock_reset_outlined,
                          obscure: true,
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      cooldownTimer?.cancel();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  ),
                  if (step == 2 && cooldownSecondsLeft <= 0)
                    TextButton(
                      onPressed: () {
                        sendOtp(emailController.text.trim());
                      },
                      child: Text(
                        'Resend Code',
                        style: GoogleFonts.outfit(color: const Color(0xFF00FF87)),
                      ),
                    )
                  else if (step == 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Text(
                        'Resend in ${cooldownSecondsLeft ~/ 60}:${(cooldownSecondsLeft % 60).toString().padLeft(2, '0')}',
                        style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            if (step == 1) {
                              sendOtp(emailController.text.trim());
                            } else {
                              handleReset();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF87),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            step == 1 ? 'Send Code' : 'Reset Password',
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

  Widget _buildDialogField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white30, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
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
        child: Stack(
          children: [
            // Floating aquatic background grid (Blinkit style)
            _buildBackgroundGrid(),

            // Main interactive layout
            SafeArea(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Row (Skip Login)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, right: 16.0, left: 16.0),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: _buildSkipLoginButton(),
                          ),
                        ),
                        
                        const SizedBox(height: 40),

                        // Bottom Sheet Card (Login Content)
                        SlideTransition(
                          position: _slideAnim,
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: _buildLoginSheet(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGrid() {
    final List<IconData> icons = [
      Icons.water_drop, Icons.waves, Icons.bubble_chart, Icons.opacity,
      Icons.timer_outlined, Icons.notifications_none, Icons.settings_outlined, Icons.analytics_outlined,
      Icons.device_thermostat, Icons.calendar_month_outlined, Icons.opacity, Icons.science_outlined,
      Icons.schedule, Icons.speed, Icons.hourglass_empty, Icons.opacity,
    ];
    
    final List<Color> colors = [
      const Color(0xFF00FF87), const Color(0xFF00E676), const Color(0xFF69F0AE), const Color(0xFFB9F6CA),
      const Color(0xFF00E5FF), const Color(0xFF1DE9B6), const Color(0xFF00FF87), const Color(0xFF00E676),
    ];

    return Positioned.fill(
      bottom: 250, // Fade out before it hits the bottom card
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.transparent],
            stops: [0.4, 0.95],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: 28,
          itemBuilder: (context, index) {
            final icon = icons[index % icons.length];
            final color = colors[index % colors.length];
            return Transform.rotate(
              angle: (index % 3 - 1) * 0.1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Center(
                  child: Icon(icon, color: color.withOpacity(0.6), size: 28),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkipLoginButton() {
    return TextButton(
      onPressed: () {
        final role = _selectedTab == 0 ? 'user' : 'admin';
        final cred = _testCredentials[role]!;
        _emailController.text = cred['email']!;
        _passwordController.text = cred['password']!;
        _handleLogin();
      },
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Skip login',
            style: GoogleFonts.outfit(
              color: const Color(0xFF00FF87),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF00FF87)),
        ],
      ),
    );
  }

  Widget _buildLoginSheet() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: const Color(0xFF05120E).withOpacity(0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo and Brand Section (Blinkit Logo Card style)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF87),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FF87).withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.water_drop, color: Colors.black, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AquaGlass',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'Smart Fish Feeder',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                Text(
                  'Log In or Sign Up',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Selector
                _buildTabSelector(),
                const SizedBox(height: 24),

                // Email field
                _buildTextField(
                  controller: _emailController,
                  hint: _selectedTab == 0 ? 'user@email.com' : 'admin@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Password field
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
                
                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00FF87),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Login button
                _buildPillButton(
                  label: _isLoading ? '' : 'Continue',
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FF87), Color(0xFF00E676)],
                  ),
                ),

                // Social logins (Google & Facebook) - only for User login
                if (_selectedTab == 0 && !_isLoading) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'or Proceed with',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google circular button
                      GestureDetector(
                        onTap: _handleGoogleLogin,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Center(
                            child: Text(
                              'G',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Facebook circular button
                      GestureDetector(
                        onTap: _handleFacebookLogin,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Center(
                            child: Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const SignupScreen(),
                            transitionsBuilder: (_, anim, __, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOutCubic)),
                                child: child,
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 400),
                          ),
                        );
                      },
                      child: Text(
                        "Sign Up",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF00FF87),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: Colors.white.withOpacity(0.06),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _buildTab('User Login', 0, Icons.person_outline)),
          Expanded(
              child:
                  _buildTab('Admin Login', 1, Icons.admin_panel_settings_outlined)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _emailController.clear();
          _passwordController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF00FF87), Color(0xFF00E676)],
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00FF87).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.black : Colors.white60,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
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
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.35)),
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
    bool isOutline = false,
    Gradient? gradient,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: isOutline
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: const Color(0xFF00FF87).withOpacity(0.4), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                backgroundColor: Colors.white.withOpacity(0.03),
              ),
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF00FF87),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF87).withOpacity(0.25),
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
                              color: Colors.black,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            label,
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
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
}
