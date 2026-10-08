import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/string_extensions.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/services/update_service.dart';
import '../../core/services/face_matching_service.dart';
import '../../widgets/update_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _handleManualUpdateCheck(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking for app updates...'),
        duration: Duration(seconds: 2),
      ),
    );

    final result = await UpdateService.checkForUpdate(ignoreDismissed: true);

    if (!context.mounted) return;

    if (result.updateAvailable && result.updateInfo != null) {
      UpdateDialog.show(
        context,
        updateInfo: result.updateInfo!,
        currentVersion: result.currentVersion,
      );
    } else if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your app is up to date! (v${result.currentVersion})'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  void _showEditProfileBottomSheet(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    final nameController = TextEditingController(text: user?.name ?? user?.displayName ?? '');
    final mobileController = TextEditingController(text: user?.mobileNumber ?? '');
    final pinController = TextEditingController(text: user?.pin ?? '');
    String selectedUnit = (user?.unit != null && AppConstants.availableUnits.contains(user!.unit))
        ? user.unit!
        : 'Unit 1';
    
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle Bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppTheme.secondaryText),
                            onPressed: () => Navigator.pop(bottomSheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Full Name
                      CustomTextField(
                        controller: nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Mobile Number
                      CustomTextField(
                        controller: mobileController,
                        label: 'Mobile Number',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value == null || value.trim().length < 10 ? 'Enter valid mobile number' : null,
                      ),
                      const SizedBox(height: 16),

                      // Unit Dropdown
                      const Text(
                        'Assigned Unit',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedUnit,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryOrange),
                            items: AppConstants.availableUnits.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  unit,
                                  style: const TextStyle(color: AppTheme.darkNavy, fontWeight: FontWeight.w500),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => selectedUnit = value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // PIN
                      CustomTextField(
                        controller: pinController,
                        label: 'Security PIN (4 digits)',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            value == null || value.trim().length != 4 ? 'PIN must be 4 digits' : null,
                      ),
                      const SizedBox(height: 28),

                      // Save Button
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setState(() => isLoading = true);
                                    try {
                                      await bottomSheetContext.read<AuthProvider>().saveProfile(
                                            pin: pinController.text.trim(),
                                            unit: selectedUnit,
                                            name: nameController.text.trim().toTitleCase(),
                                            mobile: mobileController.text.trim(),
                                          );

                                      if (bottomSheetContext.mounted) {
                                        Navigator.pop(bottomSheetContext);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Profile updated successfully!'),
                                            backgroundColor: AppTheme.successGreen,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (bottomSheetContext.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (bottomSheetContext.mounted) {
                                        setState(() => isLoading = false);
                                      }
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'SAVE CHANGES',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkNavy),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryOrange),
            onPressed: () => _showEditProfileBottomSheet(context),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header Avatar Card
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryOrange.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white,
                      child: Text(
                        user?.name?.isNotEmpty == true
                            ? user!.name![0].toUpperCase()
                            : (user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : '?'),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.formattedName ?? 'EMPLOYEE',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user?.unit ?? 'Unit Not Assigned',
                      style: const TextStyle(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Personal Information Card
            _buildSectionHeader('PERSONAL INFORMATION'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkNavy.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Full Name',
                    value: user?.formattedName ?? 'N/A',
                    onTap: () => _showEditProfileBottomSheet(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildInfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email / Employee ID',
                    value: user?.email ?? 'N/A',
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildInfoTile(
                    icon: Icons.phone_android_rounded,
                    label: 'Mobile Number',
                    value: user?.mobileNumber?.isNotEmpty == true ? user!.mobileNumber! : 'Not Provided',
                    onTap: () => _showEditProfileBottomSheet(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildInfoTile(
                    icon: Icons.business_rounded,
                    label: 'Assigned Unit',
                    value: user?.unit ?? 'Not Assigned',
                    onTap: () => _showEditProfileBottomSheet(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Master Face Verification Section
            _buildSectionHeader('MASTER FACE PROFILE'),
            const SizedBox(height: 12),
            _buildMasterFaceCard(context, user?.email ?? ''),

            const SizedBox(height: 28),

            // Security Details Card
            _buildSectionHeader('SECURITY DETAILS'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkNavy.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.pin_rounded,
                    label: 'Security PIN',
                    value: user?.pin != null ? '••••' : 'Not Set',
                    onTap: () => _showEditProfileBottomSheet(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildInfoTile(
                    icon: Icons.fingerprint_rounded,
                    label: 'Biometric Access',
                    value: 'Enabled',
                  ),
                  const Divider(height: 1, indent: 56),
                  FutureBuilder<bool>(
                    future: FaceMatchingService.hasMasterFace(user?.email ?? ''),
                    builder: (context, snapshot) {
                      final hasFace = snapshot.data ?? false;
                      return _buildInfoTile(
                        icon: Icons.face_rounded,
                        label: 'Master Face Profile',
                        value: hasFace ? 'Enrolled (Tap to Reset)' : 'Not Enrolled',
                        onTap: () async {
                          if (hasFace) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Reset Master Face Profile?'),
                                content: const Text('Your enrolled master face profile will be reset. The next selfie check-in will automatically register your new master face.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(dialogContext, true),
                                    child: const Text('Reset Face', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              await FaceMatchingService.resetMasterFace(user?.email ?? '');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Master Face Profile reset. Next selfie check-in will enroll your new face.'),
                                  backgroundColor: AppTheme.primaryOrange,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Master Face Profile will be automatically registered on your next selfie check-in!'),
                                backgroundColor: AppTheme.primaryOrange,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // App Updates Card
            _buildSectionHeader('APP INFORMATION & SYSTEM STATUS'),
            const SizedBox(height: 12),
            _buildAppUpdateCard(context),

            const SizedBox(height: 36),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () {
                  authProvider.logout();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'LOG OUT',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade200, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.secondaryText.withOpacity(0.8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.darkNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.edit_outlined, size: 18, color: AppTheme.secondaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterFaceCard(BuildContext context, String rawEmail) {
    return FutureBuilder<String>(
      future: _resolveEmail(rawEmail),
      builder: (context, emailSnapshot) {
        final emailToUse = emailSnapshot.data ?? rawEmail;
        return FutureBuilder<bool>(
          future: FaceMatchingService.hasMasterFace(emailToUse),
          builder: (context, snapshot) {
            final hasFace = snapshot.data ?? false;
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasFace ? AppTheme.successGreen.withOpacity(0.4) : AppTheme.primaryOrange.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkNavy.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (hasFace ? AppTheme.successGreen : AppTheme.primaryOrange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.face_rounded,
                          color: hasFace ? AppTheme.successGreen : AppTheme.primaryOrange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Master Face Verification',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasFace ? '1-to-1 Anti-Proxy Matching Active' : 'Automatic Registration Pending',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasFace ? AppTheme.successGreen : AppTheme.primaryOrange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (hasFace ? AppTheme.successGreen : AppTheme.primaryOrange).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasFace ? 'ENROLLED' : 'PENDING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: hasFace ? AppTheme.successGreen : AppTheme.primaryOrange,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasFace
                        ? 'Your face profile is enrolled for strict anti-proxy verification. Only your face is authorized to check in.'
                        : 'Your master face profile will be automatically registered on your very first selfie check-in.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkNavy.withOpacity(0.7),
                      height: 1.3,
                    ),
                  ),
                  if (hasFace) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Reset Master Face Profile?'),
                              content: const Text(
                                'Your enrolled master face profile will be reset. The next selfie check-in will automatically register your new master face.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('Reset Face', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && context.mounted) {
                            await FaceMatchingService.resetMasterFace(emailToUse);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Master Face Profile reset successfully. Next selfie check-in will enroll your new face.'),
                                backgroundColor: AppTheme.primaryOrange,
                              ),
                            );
                            (context as Element).markNeedsBuild();
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.red),
                        label: const Text(
                          'Reset Master Face',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _resolveEmail(String rawEmail) async {
    if (rawEmail.isNotEmpty) return rawEmail;
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
    );
    return await storage.read(key: 'email') ?? 'rachitsaraf@vobpl.com';
  }

  Widget _buildAppUpdateCard(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.hasData ? snapshot.data!.version : '1.3.2';
        final buildNumber = snapshot.hasData ? snapshot.data!.buildNumber : '18';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.successGreen.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkNavy.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.verified_rounded, color: AppTheme.successGreen, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Version v$version (Build $buildNumber)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'System Status: Updated & Active',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LATEST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.successGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text(
                'LATEST UPDATE FEATURES:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryText,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _buildFeatureBullet(Icons.face_rounded, 'Master Face Profile 1-to-1 Anti-Proxy Matching'),
              const SizedBox(height: 6),
              _buildFeatureBullet(Icons.location_on_rounded, 'Enhanced Geofencing (50m Gate / 60m Premises)'),
              const SizedBox(height: 6),
              _buildFeatureBullet(Icons.login_rounded, 'Login Page Selfie Verification Check-In'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleManualUpdateCheck(context),
                  icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                  label: const Text('CHECK FOR SYSTEM UPDATES'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: AppTheme.primaryOrange,
                    side: BorderSide(color: AppTheme.primaryOrange.withOpacity(0.4), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureBullet(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkNavy.withOpacity(0.85),
            ),
          ),
        ),
      ],
    );
  }
}
