import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/string_extensions.dart';
import '../../widgets/custom_text_field.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String _selectedUnit = 'Unit 1';
  bool _isLoading = false;

  final List<String> _units = AppConstants.availableUnits;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user?.displayName != null) {
      _nameController.text = user!.displayName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await context.read<AuthProvider>().saveProfile(
          pin: _pinController.text.trim(),
          unit: _selectedUnit,
          name: _nameController.text.trim().toTitleCase(),
          mobile: _mobileController.text.trim(),
        );
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
  }

  @override
  Widget build(BuildContext context) {
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
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Header Logo/Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'VOBPL',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        const Text(
                          ' ATTENDANCE',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    const Text(
                      'Complete Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Just a few more details to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondaryText),
                    ),
                    const SizedBox(height: 48),
                    
                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    CustomTextField(
                      controller: _mobileController,
                      label: 'Mobile Number',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (value) => value == null || value.length < 10 ? 'Enter valid mobile' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUnit,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryOrange),
                          items: _units.map((unit) {
                            return DropdownMenuItem(value: unit, child: Text(unit, style: const TextStyle(color: AppTheme.darkNavy, fontWeight: FontWeight.w500)));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedUnit = value!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    CustomTextField(
                      controller: _pinController,
                      label: 'Create 4-Digit PIN',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.length != 4 ? 'PIN must be 4 digits' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    CustomTextField(
                      controller: _confirmPinController,
                      label: 'Confirm PIN',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      keyboardType: TextInputType.number,
                      validator: (value) => value != _pinController.text ? 'PINs do not match' : null,
                    ),
                    const SizedBox(height: 48),
                    
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
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SAVE & CONTINUE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 40),
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
