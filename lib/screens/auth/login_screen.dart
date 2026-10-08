import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/string_extensions.dart';
import 'register_screen.dart';
import '../../core/services/security_service.dart';
import '../../core/services/feature_flag_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  
  String? _storedName;
  String? _storedUnit;
  String? _storedEmail;

  @override
  void initState() {
    super.initState();
    SecurityService.checkDeviceSecurity(); // Pre-warm security check in background
    _checkBiometrics();
    _loadStoredUserData();
  }

  Future<void> _loadStoredUserData() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
    );
    final name = await storage.read(key: 'name');
    final unit = await storage.read(key: 'unit');
    final email = await storage.read(key: 'email');
    if (mounted) {
      setState(() {
        _storedName = name != null ? name.toTitleCase() : null;
        _storedUnit = unit;
        _storedEmail = email;
        if (email != null) _emailController.text = email;
      });
    }
  }

  Future<void> _checkBiometrics() async {
    final available = await context.read<AuthProvider>().checkBiometricSupport(); 
    final isFlagEnabled = FeatureFlagService.isEnabled('enable_biometrics');
    if (mounted) setState(() => _isBiometricAvailable = available && isFlagEnabled);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final email = _emailController.text.trim();
        final pin = _passwordController.text.trim();
        final firebasePassword = "${pin}VOBPL";
        
        await context.read<AuthProvider>().login(
              email,
              firebasePassword,
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _handleBiometricLogin() async {
    final security = await SecurityService.checkDeviceSecurity();
    if (!security.isSafe && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(security.errorMessage!), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().biometricLogin();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePinLogin() async {
    final security = await SecurityService.checkDeviceSecurity();
    if (!security.isSafe && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(security.errorMessage!), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
      );
      return;
    }

    final email = _storedEmail ?? _emailController.text.trim();
    final pin = _pinController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter 4-digit PIN')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().loginWithPin(email, pin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }





  @override
  Widget build(BuildContext context) {
    final bool isWelcomeBack = _storedName != null && _storedUnit != null;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Stack(
        children: [
          // Background Decorative Circle
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 30),
                    // Header Original Company Logo Image
                    Center(
                      child: Image.asset(
                        'assets/images/app_logo.jpg',
                        height: 70,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/app_logo.png',
                            height: 70,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 35),

                    if (isWelcomeBack) ...[
                      // Modern Glassmorphic Welcome Back Header Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.darkNavy.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Circular Initial Avatar
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white,
                                child: Text(
                                  _storedName!.trim().isNotEmpty ? _storedName![0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryOrange,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Welcome Back,',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryText.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _storedName!.toTitleCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkNavy,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.business_rounded, size: 14, color: AppTheme.primaryOrange),
                                  const SizedBox(width: 6),
                                  Text(
                                    _storedUnit!,
                                    style: const TextStyle(
                                      color: AppTheme.primaryOrange,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_isBiometricAvailable) ...[
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _isLoading ? null : _handleBiometricLogin,
                                child: Container(
                                  height: 84,
                                  width: 84,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryOrange.withOpacity(0.25),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2), width: 1.5),
                                  ),
                                  child: const Icon(Icons.fingerprint_rounded, size: 48, color: AppTheme.primaryOrange),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap for Fingerprint Login',
                                style: TextStyle(
                                  color: AppTheme.darkNavy.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            const Expanded(child: Divider(thickness: 1, endIndent: 10)),
                            Text(
                              'OR ENTER 4-DIGIT PIN',
                              style: TextStyle(
                                color: AppTheme.secondaryText.withOpacity(0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Expanded(child: Divider(thickness: 1, indent: 10)),
                          ],
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Stylish PIN Input
                      Center(
                        child: Container(
                          width: 240,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 28, letterSpacing: 24, fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
                            decoration: const InputDecoration(
                              counterText: "",
                              hintText: "••••",
                              hintStyle: TextStyle(color: Colors.grey, letterSpacing: 24),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handlePinLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'CONTINUE',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => setState(() => _storedName = null),
                        child: Text(
                          'NOT YOU? SWITCH ACCOUNT',
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Standard Login for new/other users
                      const Text(
                        'Sign In',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Access your attendance dashboard',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 48),
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email / Employee ID',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter email' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Enter 4-Digit PIN',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null || value.length != 4 ? 'PIN must be 4 digits' : null,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'SIGN IN',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
                                ),
                        ),
                      ),

                      if (_isBiometricAvailable) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider(thickness: 1, endIndent: 10)),
                            Text(
                              'QUICK LOGIN',
                              style: TextStyle(
                                color: AppTheme.secondaryText.withOpacity(0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Expanded(child: Divider(thickness: 1, indent: 10)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: GestureDetector(
                            onTap: _isLoading ? null : _handleBiometricLogin,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.fingerprint_rounded, size: 36, color: AppTheme.primaryOrange),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? ", style: TextStyle(color: AppTheme.secondaryText)),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            ),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
