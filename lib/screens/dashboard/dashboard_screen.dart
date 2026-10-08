import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/attendance_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../attendance/camera_screen.dart';
import '../attendance/history_screen.dart';

import '../dashboard/leave_request_screen.dart';
import '../dashboard/rules_screen.dart';
import '../dashboard/alerts_screen.dart';
import '../profile/profile_screen.dart';

import '../../core/services/update_service.dart';
import '../../core/services/feature_flag_service.dart';
import '../../widgets/update_dialog.dart';
import '../../widgets/field_remark_dialog.dart';

import '../../providers/connectivity_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool? _wasOnline;
  bool _isHindiThought = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<AuthProvider>().user;
      final userEmail = user?.email ?? '';
      final userUnit = user?.unit;
      
      // Fetch user-targeted feature flags from server and refresh UI
      await FeatureFlagService().fetchTargetedFlags(userEmail, unit: userUnit);
      if (mounted) setState(() {});

      if (mounted) {
        context.read<AttendanceProvider>().preWarmLocation();
        context.read<AttendanceProvider>().checkActiveSession(userEmail);
        context.read<AttendanceProvider>().syncOfflineRecords(userEmail);
        context.read<AttendanceProvider>().fetchHistory(userEmail);
        _checkForAppUpdates();
      }
    });
  }

  void _checkForAppUpdates() async {
    final result = await UpdateService.checkForUpdate();
    if (mounted && result.updateAvailable && result.updateInfo != null) {
      UpdateDialog.show(
        context,
        updateInfo: result.updateInfo!,
        currentVersion: result.currentVersion,
      );
    }
  }

  void _handleConnectivityChange(bool isOnline) {
    if (_wasOnline != null && _wasOnline != isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isOnline) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.wifi_rounded, color: AppTheme.successGreen, size: 48),
              title: const Text('Internet Restored', style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text(
                'You are connected to internet now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );

          final userEmail = context.read<AuthProvider>().user?.email ?? '';
          context.read<AttendanceProvider>().syncOfflineRecords(userEmail);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection lost. Working offline.'),
              backgroundColor: Colors.blueGrey,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
    _wasOnline = isOnline;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final user = authProvider.user;
    final isOnline = Provider.of<ConnectivityProvider>(context).isOnline;

    _handleConnectivityChange(isOnline);

    return Scaffold(
      drawer: _buildAppDrawer(context, authProvider, user),
      backgroundColor: AppTheme.bgLight,
      body: CustomScrollView(
        slivers: [
          // 1. Premium Orange Gradient Header
          _buildHeader(context, authProvider, user),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Offline Alert Banner
                if (!isOnline) _buildOfflineBanner(),

                // 2. Workday Status Card
                _buildWorkdayStatusCard(context, attendanceProvider, user),

                const SizedBox(height: 32),

                // 3. Today Summary Section Header
                _buildSectionHeader(context),

                const SizedBox(height: 16),

                // 4. Summary Cards (Side-by-side)
                _buildSummaryCards(attendanceProvider),

                const SizedBox(height: 32),

                // 5. Quick Actions Section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.widgets_rounded,
                        color: AppTheme.primaryOrange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: AppTheme.darkNavy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildQuickActions(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionItem(
                context,
                icon: Icons.person_rounded,
                title: 'My Profile',
                subtitle: 'Personal & Unit details',
                accentColor: AppTheme.accentBlue,
                bgColor: AppTheme.lightBlueBg,
                destination: const ProfileScreen(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionItem(
                context,
                icon: Icons.event_note_rounded,
                title: 'Leave Request',
                subtitle: 'Apply & track status',
                accentColor: AppTheme.successGreen,
                bgColor: AppTheme.lightGreenBg,
                destination: const LeaveRequestScreen(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionItem(
                context,
                icon: Icons.gavel_rounded,
                title: 'Company Policy',
                subtitle: 'Attendance rules',
                accentColor: AppTheme.primaryOrange,
                bgColor: AppTheme.lightOrangeBg,
                destination: const RulesScreen(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionItem(
                context,
                icon: Icons.notifications_active_rounded,
                title: 'Shift Alerts',
                subtitle: 'Notices & reminders',
                accentColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEE2E2),
                destination: const AlertsScreen(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color bgColor,
    required Widget? destination,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkNavy.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: destination != null
              ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination))
              : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppTheme.darkNavy,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.secondaryText.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider authProvider, dynamic user) {
    final isOnline = Provider.of<ConnectivityProvider>(context).isOnline;

    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 55, 24, 25),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.bgLight,
                              child: Text(
                                user?.formattedName.substring(0, 1).toUpperCase() ?? '?',
                                style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            user?.formattedName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AlertsScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (scaffoldContext) => GestureDetector(
                        onTap: () => Scaffold.of(scaffoldContext).openDrawer(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          StreamBuilder(
                            stream: Stream.periodic(const Duration(seconds: 1)),
                            builder: (context, snapshot) {
                              return Text(
                                DateFormat('hh:mm:ss a').format(DateTime.now()),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        user?.unit == AppConstants.fieldUnit ? Icons.explore_rounded : Icons.location_on_rounded, 
                        color: user?.unit == AppConstants.fieldUnit ? Colors.amberAccent : Colors.white70, 
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user?.unit == AppConstants.fieldUnit
                            ? 'Assigned: Field Worker (Flexible GPS)'
                            : 'Assigned Unit: ${user?.unit ?? "Not Assigned"}',
                        style: TextStyle(
                          color: user?.unit == AppConstants.fieldUnit ? Colors.amberAccent : Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.white.withOpacity(0.25), height: 1),
                  const SizedBox(height: 12),
                  _buildThoughtOfTheDayCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkdayStatusCard(BuildContext context, AttendanceProvider attendanceProvider, dynamic user) {
    bool checkedIn = attendanceProvider.isCheckedIn;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkNavy.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: checkedIn ? AppTheme.lightGreenBg : AppTheme.lightOrangeBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  checkedIn ? Icons.check_circle_rounded : Icons.info_rounded,
                  color: checkedIn ? AppTheme.successGreen : AppTheme.primaryOrange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  checkedIn ? 'WORKDAY IN PROGRESS' : 'READY TO START WORK',
                  style: TextStyle(
                    color: checkedIn ? AppTheme.successGreen : AppTheme.primaryOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 1st Place: Dynamic Action Card (Smart Face Verification or Quick GPS Punch)
          _buildModernActionCard(
            context: context,
            icon: FeatureFlagService.isEnabled('enable_face_matching') ? Icons.face_rounded : Icons.location_on_rounded,
            title: FeatureFlagService.isEnabled('enable_face_matching')
                ? (checkedIn ? 'SMART FACE CHECK-OUT' : 'SMART FACE CHECK-IN')
                : (checkedIn ? 'QUICK GPS CHECK-OUT' : 'QUICK GPS CHECK-IN'),
            subtitle: FeatureFlagService.isEnabled('enable_face_matching')
                ? (checkedIn ? 'Verify master face profile to finish workday' : '1-to-1 master face profile verification')
                : (checkedIn ? 'Instant GPS location verification' : 'Instant GPS location verification'),
            accentColor: FeatureFlagService.isEnabled('enable_face_matching') ? AppTheme.accentBlue : AppTheme.primaryOrange,
            onTap: attendanceProvider.isChecking
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);

                    // Prompt for Field Remark / Visit Purpose if Field Worker
                    String? remark;
                    if (user?.unit == AppConstants.fieldUnit) {
                      remark = await FieldRemarkDialog.show(context, isCheckOut: checkedIn);
                      if (remark == null || !mounted) return;
                    }

                    String? selfiePath;
                    if (FeatureFlagService.isEnabled('enable_face_matching')) {
                      selfiePath = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(builder: (context) => const CameraScreen()),
                      );
                      if (selfiePath == null || !mounted) return;
                    }

                    if (checkedIn) {
                      final error = await attendanceProvider.checkOut(
                        user?.email ?? 'unknown',
                        selfiePath: selfiePath,
                        unit: user?.unit,
                        remark: remark,
                      );

                      if (!mounted) return;

                      if (error != null) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(error), backgroundColor: Colors.red),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(FeatureFlagService.isEnabled('enable_face_matching') ? 'Selfie check-out successful!' : 'GPS check-out successful!'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    } else {
                      final error = await attendanceProvider.validateLocationAndCheckIn(
                        selfiePath,
                        user?.email ?? 'unknown',
                        user?.unit,
                        remark: remark,
                      );

                      if (!mounted) return;

                      if (error != null) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(error), backgroundColor: Colors.red),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(FeatureFlagService.isEnabled('enable_face_matching') ? 'Selfie check-in successful!' : 'GPS check-in successful!'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    }
                  },
          ),

          if (FeatureFlagService.isEnabled('enable_biometrics')) ...[
            const SizedBox(height: 16),

            // 2nd Place: Fingerprint Main CTA Button
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
              child: ElevatedButton(
                onPressed: attendanceProvider.isChecking
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);

                        if (!FeatureFlagService.isEnabled('enable_biometrics')) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Biometric Punch is disabled by administrator.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                      // Prompt for Field Remark / Visit Purpose if Field Worker
                      String? remark;
                      if (user?.unit == AppConstants.fieldUnit) {
                        remark = await FieldRemarkDialog.show(context, isCheckOut: checkedIn);
                        if (remark == null || !mounted) return;
                      }

                      if (checkedIn) {
                        final confirm = await _showCheckOutDialog(context);
                        if (confirm != true || !mounted) return;

                        final error = await attendanceProvider.checkOutWithBiometrics(
                          user?.email ?? 'unknown',
                          unit: user?.unit,
                          remark: remark,
                        );

                        if (error != null) {
                          final isOffline = error.contains('offline') || error.contains('locally');
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: isOffline ? Colors.blueGrey : Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Check-out successful!'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        }
                      } else {
                        final error = await attendanceProvider.checkInWithBiometrics(
                          user?.email ?? 'unknown',
                          user?.unit,
                          remark: remark,
                        );

                        if (error != null) {
                          final isOffline = error.contains('offline') || error.contains('locally');
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: isOffline ? Colors.blueGrey : Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Check-in successful!'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: attendanceProvider.isChecking
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              checkedIn ? 'FINISH WORKDAY' : 'START WORKDAY',
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.w900, 
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              checkedIn ? 'Tap for Fingerprint Check-Out' : 'Tap for Fingerprint Check-In',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: AppTheme.primaryOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Day Summary',
              style: TextStyle(
                color: AppTheme.darkNavy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen())),
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('Full History'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryOrange,
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(AttendanceProvider attendanceProvider) {
    final now = DateTime.now();

    // Get current/latest shift for today to remain uniform with Full History
    AttendanceModel? todayRecord;

    if (attendanceProvider.currentAttendance != null &&
        attendanceProvider.currentAttendance!.checkInTime.year == now.year &&
        attendanceProvider.currentAttendance!.checkInTime.month == now.month &&
        attendanceProvider.currentAttendance!.checkInTime.day == now.day) {
      todayRecord = attendanceProvider.currentAttendance;
    } else {
      final todayRecords = attendanceProvider.history.where((r) =>
          r.checkInTime.year == now.year &&
          r.checkInTime.month == now.month &&
          r.checkInTime.day == now.day
      ).toList();

      if (todayRecords.isNotEmpty) {
        todayRecords.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
        todayRecord = todayRecords.first; // Latest shift today
      }
    }

    String checkInStr = '--:--';
    String checkOutStr = '--:--';
    String workingHoursStr = '0h 0m';

    if (todayRecord != null) {
      checkInStr = DateFormat('hh:mm a').format(todayRecord.checkInTime);

      if (todayRecord.checkOutTime != null) {
        checkOutStr = DateFormat('hh:mm a').format(todayRecord.checkOutTime!);
        final duration = todayRecord.checkOutTime!.difference(todayRecord.checkInTime);
        workingHoursStr = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
      } else {
        final duration = now.difference(todayRecord.checkInTime);
        workingHoursStr = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
      }
    } else if (attendanceProvider.todayTotalTime != '0h 0m') {
      workingHoursStr = attendanceProvider.todayTotalTime;
    }

    return Row(
      children: [
        // Check-in Card
        _buildStatCard(
          label: 'CHECK-IN',
          value: checkInStr,
          icon: Icons.login_rounded,
          iconColor: AppTheme.successGreen,
          iconBgColor: AppTheme.lightGreenBg,
        ),
        const SizedBox(width: 10),
        // Check-out Card
        _buildStatCard(
          label: 'CHECK-OUT',
          value: checkOutStr,
          icon: Icons.logout_rounded,
          iconColor: Colors.red,
          iconBgColor: Colors.red.withOpacity(0.1),
        ),
        const SizedBox(width: 10),
        // Working Hours Card
        _buildStatCard(
          label: 'WORKING HOURS',
          value: workingHoursStr,
          icon: Icons.hourglass_top_rounded,
          iconColor: AppTheme.primaryOrange,
          iconBgColor: AppTheme.lightOrangeBg,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: iconColor.withOpacity(0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkNavy.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.darkNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.secondaryText.withOpacity(0.85),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkNavy.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.darkNavy,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.darkNavy.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: accentColor.withOpacity(0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThoughtOfTheDayCard() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final thoughts = const [
      {
        "quote": "Great things in business are never done by one person. They're done by a team of people.",
        "quoteHindi": "व्यापार में महान कार्य कभी एक व्यक्ति द्वारा नहीं किए जाते। वे लोगों की एक टीम द्वारा किए जाते हैं।",
        "author": "Steve Jobs",
        "authorHindi": "स्टीव जॉब्स",
        "tag": "TEAMWORK",
        "tagHindi": "टीमवर्क"
      },
      {
        "quote": "Small daily improvements over time lead to stunning results.",
        "quoteHindi": "समय के साथ छोटे-छोटे दैनिक सुधार आश्चर्यजनक परिणाम लाते हैं।",
        "author": "Robin Sharma",
        "authorHindi": "रॉबिन शर्मा",
        "tag": "GROWTH",
        "tagHindi": "विकास"
      },
      {
        "quote": "Quality means doing it right when no one is looking.",
        "quoteHindi": "गुणवत्ता का अर्थ है जब कोई न देख रहा हो तब भी सही काम करना।",
        "author": "Henry Ford",
        "authorHindi": "हेनरी फोर्ड",
        "tag": "EXCELLENCE",
        "tagHindi": "उत्कृष्टता"
      },
      {
        "quote": "Focus on being productive instead of busy.",
        "quoteHindi": "व्यस्त रहने के बजाय उत्पादक बनने पर ध्यान केंद्रित करें।",
        "author": "Tim Ferriss",
        "authorHindi": "टिम फेरिस",
        "tag": "PRODUCTIVITY",
        "tagHindi": "उत्पादकता"
      },
      {
        "quote": "Success is the sum of small efforts, repeated day in and day out.",
        "quoteHindi": "सफलता हर दिन दोहराए जाने वाले छोटे-छोटे प्रयासों का योग है।",
        "author": "Robert Collier",
        "authorHindi": "रॉबर्ट कोलियर",
        "tag": "DEDICATION",
        "tagHindi": "समर्पण"
      },
      {
        "quote": "Attitude is a little thing that makes a big difference.",
        "quoteHindi": "सकारात्मक दृष्टिकोण एक छोटी सी चीज है जो बड़ा अंतर लाती है।",
        "author": "Winston Churchill",
        "authorHindi": "विंस्टन चर्चिल",
        "tag": "POSITIVITY",
        "tagHindi": "सकारात्मकता"
      },
      {
        "quote": "The only way to do great work is to love what you do.",
        "quoteHindi": "महान कार्य करने का एक ही तरीका है कि आप जो करते हैं उससे प्यार करें।",
        "author": "Steve Jobs",
        "authorHindi": "स्टीव जॉब्स",
        "tag": "PASSION",
        "tagHindi": "जुनून"
      },
      {
        "quote": "Leadership is not about being in charge. It is about taking care of those in your charge.",
        "quoteHindi": "नेतृत्व प्रभारी होने के बारे में नहीं है। यह उनकी देखभाल करने के बारे में है जो आपके प्रभार में हैं।",
        "author": "Simon Sinek",
        "authorHindi": "साइमन सिनेक",
        "tag": "LEADERSHIP",
        "tagHindi": "नेतृत्व"
      },
      {
        "quote": "Innovation distinguishes between a leader and a follower.",
        "quoteHindi": "नवाचार (इन्नोवेशन) एक नेता और एक अनुयायी के बीच अंतर करता है।",
        "author": "Steve Jobs",
        "authorHindi": "स्टीव जॉब्स",
        "tag": "INNOVATION",
        "tagHindi": "नवाचार"
      },
      {
        "quote": "Efficiency is doing things right; effectiveness is doing the right things.",
        "quoteHindi": "कार्यकुशलता काम को सही तरीके से करना है; प्रभावशीलता सही काम करना है।",
        "author": "Peter Drucker",
        "authorHindi": "पीटर ड्रकर",
        "tag": "EFFICIENCY",
        "tagHindi": "कार्यकुशलता"
      },
      {
        "quote": "The secret of getting ahead is getting started.",
        "quoteHindi": "आगे बढ़ने का रहस्य शुरुआत करना है।",
        "author": "Mark Twain",
        "authorHindi": "मार्क ट्वेन",
        "tag": "INITIATIVE",
        "tagHindi": "पहल"
      },
      {
        "quote": "Integrity is doing the right thing, even when no one is watching.",
        "quoteHindi": "ईमानदारी तब भी सही काम करना है जब कोई न देख रहा हो।",
        "author": "C.S. Lewis",
        "authorHindi": "सी.एस. लुईस",
        "tag": "INTEGRITY",
        "tagHindi": "ईमानदारी"
      },
      {
        "quote": "Action is the foundational key to all success.",
        "quoteHindi": "कर्म ही सभी सफलताओं की मूलभूत कुंजी है।",
        "author": "Pablo Picasso",
        "authorHindi": "पाब्लो पिकासो",
        "tag": "ACTION",
        "tagHindi": "कर्म"
      },
      {
        "quote": "Opportunities don't happen. You create them.",
        "quoteHindi": "अवसर अपने आप नहीं मिलते, आप उन्हें खुद बनाते हैं।",
        "author": "Chris Grosser",
        "authorHindi": "क्रिस ग्रोसर",
        "tag": "OPPORTUNITY",
        "tagHindi": "अवसर"
      },
      {
        "quote": "Try not to become a man of success. Rather become a man of value.",
        "quoteHindi": "सफल इंसान बनने की बजाय मूल्यों वाला इंसान बनने का प्रयास करें।",
        "author": "Albert Einstein",
        "authorHindi": "अल्बर्ट आइंस्टीन",
        "tag": "VALUE",
        "tagHindi": "मूल्य"
      },
      {
        "quote": "Failure is simply the opportunity to begin again, this time more intelligently.",
        "quoteHindi": "असफलता फिर से शुरुआत करने का अवसर है, इस बार अधिक समझदारी के साथ।",
        "author": "Henry Ford",
        "authorHindi": "हेनरी फोर्ड",
        "tag": "RESILIENCE",
        "tagHindi": "सहनशीलता"
      },
      {
        "quote": "Alone we can do so little; together we can do so much.",
        "quoteHindi": "अकेले हम बहुत कम कर सकते हैं; साथ मिलकर हम बहुत कुछ कर सकते हैं।",
        "author": "Helen Keller",
        "authorHindi": "हेलेन केलर",
        "tag": "COLLABORATION",
        "tagHindi": "सहयोग"
      },
      {
        "quote": "Always deliver more than expected.",
        "quoteHindi": "हमेशा उम्मीद से अधिक देने का प्रयास करें।",
        "author": "Larry Page",
        "authorHindi": "लैरी पेज",
        "tag": "CUSTOMER FIRST",
        "tagHindi": "ग्राहक प्रथम"
      },
      {
        "quote": "Patience, persistence and perspiration make an unbeatable combination for success.",
        "quoteHindi": "धैर्य, दृढ़ता और कड़ी मेहनत सफलता का एक बेजोड़ संयोजन बनाते हैं।",
        "author": "Napoleon Hill",
        "authorHindi": "नेपोलियन हिल",
        "tag": "PERSEVERANCE",
        "tagHindi": "दृढ़ता"
      },
      {
        "quote": "Your most unhappy customers are your greatest source of learning.",
        "quoteHindi": "आपके सबसे असंतुष्ट ग्राहक सीखने का सबसे बड़ा जरिया हैं।",
        "author": "Bill Gates",
        "authorHindi": "बिल गेट्स",
        "tag": "LEARNING",
        "tagHindi": "सीख"
      },
      {
        "quote": "Without continual growth and progress, such words as improvement, achievement, and success have no meaning.",
        "quoteHindi": "निरंतर वृद्धि के बिना सुधार, उपलब्धि और सफलता जैसे शब्दों का कोई अर्थ नहीं है।",
        "author": "Benjamin Franklin",
        "authorHindi": "बेंजामिन फ्रेंकलिन",
        "tag": "CONTINUOUS IMPROVEMENT",
        "tagHindi": "सतत सुधार"
      },
      {
        "quote": "Safety is not a gadget but a state of mind.",
        "quoteHindi": "सुरक्षा कोई उपकरण नहीं बल्कि एक मानसिक स्थिति है।",
        "author": "Eleanor Everet",
        "authorHindi": "एलेनोर एवरेट",
        "tag": "SAFETY FIRST",
        "tagHindi": "सुरक्षा प्रथम"
      },
      {
        "quote": "The best way to predict the future is to create it.",
        "quoteHindi": "भविष्य का अनुमान लगाने का सबसे अच्छा तरीका इसे स्वयं बनाना है।",
        "author": "Peter Drucker",
        "authorHindi": "पीटर ड्रकर",
        "tag": "VISION",
        "tagHindi": "दृष्टिकोण"
      },
      {
        "quote": "Excellence is not an act, but a habit.",
        "quoteHindi": "उत्कृष्टता कोई एक कार्य नहीं, बल्कि एक आदत है।",
        "author": "Aristotle",
        "authorHindi": "अरस्तू",
        "tag": "HABIT",
        "tagHindi": "आदत"
      },
      {
        "quote": "Disciplined execution is the bridge between goals and accomplishment.",
        "quoteHindi": "अनुशासित क्रियान्वयन लक्ष्यों और उपलब्धियों के बीच का पुल है।",
        "author": "Jim Rohn",
        "authorHindi": "जिम रोन",
        "tag": "DISCIPLINE",
        "tagHindi": "अनुशासन"
      },
      {
        "quote": "Believe you can and you're halfway there.",
        "quoteHindi": "विश्वास रखें कि आप कर सकते हैं, तो समझो आधा रास्ता तय हो गया।",
        "author": "Theodore Roosevelt",
        "authorHindi": "थियोडोर रूजवेल्ट",
        "tag": "CONFIDENCE",
        "tagHindi": "आत्मविश्वास"
      },
      {
        "quote": "Customer service shouldn't just be a department, it should be the entire company.",
        "quoteHindi": "ग्राहक सेवा केवल एक विभाग नहीं, बल्कि पूरी कंपनी की सोच होनी चाहिए।",
        "author": "Tony Hsieh",
        "authorHindi": "टोनी हसीह",
        "tag": "SERVICE",
        "tagHindi": "सेवा"
      },
      {
        "quote": "Work hard in silence, let your success be your noise.",
        "quoteHindi": "खामोशी से मेहनत करें, अपनी सफलता को शोर मचाने दें।",
        "author": "Frank Ocean",
        "authorHindi": "फ्रैंक ओशन",
        "tag": "FOCUS",
        "tagHindi": "एकाग्रता"
      },
      {
        "quote": "Continuous learning is the minimum requirement for success in any field.",
        "quoteHindi": "निरंतर सीखते रहना किसी भी क्षेत्र में सफलता की न्यूनतम आवश्यकता है।",
        "author": "Brian Tracy",
        "authorHindi": "ब्रायन ट्रेसी",
        "tag": "SKILL DEVELOPMENT",
        "tagHindi": "कौशल विकास"
      },
      {
        "quote": "Strive for perfection in everything you do. Take the best that exists and make it better.",
        "quoteHindi": "आप जो भी करें उसमें पूर्णता के लिए प्रयास करें। जो सर्वोत्तम है उसे लें और बेहतर बनाएं।",
        "author": "Sir Henry Royce",
        "authorHindi": "सर हेनरी रॉयस",
        "tag": "QUALITY",
        "tagHindi": "गुणवत्ता"
      },
      {
        "quote": "Success usually comes to those who are too busy to be looking for it.",
        "quoteHindi": "सफलता आमतौर पर उन लोगों के पास आती है जो इसे खोजने में बहुत व्यस्त होते हैं।",
        "author": "Henry David Thoreau",
        "authorHindi": "हेनरी डेविड थोरो",
        "tag": "HARD WORK",
        "tagHindi": "कड़ी मेहनत"
      },
    ];
    final todayThought = thoughts[dayOfYear % thoughts.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_rounded, color: Colors.amberAccent, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    _isHindiThought
                        ? 'दैनिक विचार • ${todayThought['tagHindi']}'
                        : 'DAILY BULLETIN • ${todayThought['tag']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isHindiThought = !_isHindiThought;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.translate_rounded, color: Colors.white, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      _isHindiThought ? 'English' : 'हिन्दी',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isHindiThought
              ? '"${todayThought['quoteHindi']}"'
              : '"${todayThought['quote']}"',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            _isHindiThought
                ? '— ${todayThought['authorHindi']}'
                : '— ${todayThought['author']}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You are currently offline. Attendance will be saved locally.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context, AuthProvider authProvider, dynamic user) {
    final isOnline = Provider.of<ConnectivityProvider>(context).isOnline;
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);

    return Drawer(
      backgroundColor: AppTheme.bgLight,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.formattedName.isNotEmpty == true 
                    ? user!.formattedName.substring(0, 1).toUpperCase() 
                    : '?',
                style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            accountName: Text(
              user?.formattedName ?? 'User',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            accountEmail: Row(
              children: [
                Expanded(
                  child: Text(
                    user?.email ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOnline ? 'ONLINE' : 'OFFLINE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_rounded, color: AppTheme.primaryOrange),
                  title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: AppTheme.primaryOrange),
                  title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded, color: AppTheme.primaryOrange),
                  title: const Text('Attendance History', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_note_rounded, color: AppTheme.primaryOrange),
                  title: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LeaveRequestScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded, color: AppTheme.primaryOrange),
                  title: const Text('Rules & Policy', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RulesScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryOrange),
                  title: const Text('Alerts & Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AlertsScreen()),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.sync_rounded, color: Colors.blueGrey),
                  title: const Text('Sync Offline Data', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    final userEmail = user?.email ?? '';
                    attendanceProvider.syncOfflineRecords(userEmail);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing offline attendance data...'),
                        backgroundColor: AppTheme.primaryOrange,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    authProvider.logout();
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Text(
              'VOBPL Attendance v1.0.0',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showCheckOutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Finish Workday?'),
        content: const Text('This will end your shift and record your current location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('NOT YET', style: TextStyle(color: AppTheme.secondaryText))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('YES, FINISH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
class CircleAvatarWithIcon extends StatelessWidget {
  const CircleAvatarWithIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
