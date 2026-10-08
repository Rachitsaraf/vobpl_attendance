import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/route_map_dialog.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var userEmail = context.read<AuthProvider>().user?.email ?? '';
      if (userEmail.isEmpty) {
        userEmail = await _storage.read(key: 'email') ?? '';
      }
      if (mounted) {
        context.read<AttendanceProvider>().fetchHistory(userEmail);
      }
    });
  }

  Map<String, String> _calculateAnalytics(List<dynamic> history) {
    if (history.isEmpty) {
      return {
        'avgIn': '--:--',
        'avgOut': '--:--',
        'avgDuration': '0h 0m',
        'totalShifts': '0',
        'totalHours': '0h 0m',
        'completedShifts': '0',
      };
    }

    int totalInMinutes = 0;
    for (var record in history) {
      final checkIn = record.checkInTime as DateTime;
      totalInMinutes += checkIn.hour * 60 + checkIn.minute;
    }

    final avgInMins = (totalInMinutes / history.length).round();
    final avgInHour = avgInMins ~/ 60;
    final avgInMinute = avgInMins % 60;
    final avgInDateTime = DateTime(2026, 1, 1, avgInHour, avgInMinute);
    final avgInStr = DateFormat('hh:mm a').format(avgInDateTime);

    final completed = history.where((r) => r.checkOutTime != null).toList();

    String avgOutStr = '--:--';
    String avgDurationStr = '0h 0m';
    String totalHoursStr = '0h 0m';

    if (completed.isNotEmpty) {
      int totalOutMinutes = 0;
      Duration totalDuration = Duration.zero;

      for (var record in completed) {
        final checkOut = record.checkOutTime as DateTime;
        final checkIn = record.checkInTime as DateTime;

        totalOutMinutes += checkOut.hour * 60 + checkOut.minute;
        totalDuration += checkOut.difference(checkIn);
      }

      final avgOutMins = (totalOutMinutes / completed.length).round();
      final avgOutHour = avgOutMins ~/ 60;
      final avgOutMinute = avgOutMins % 60;
      final avgOutDateTime = DateTime(2026, 1, 1, avgOutHour, avgOutMinute);
      avgOutStr = DateFormat('hh:mm a').format(avgOutDateTime);

      final avgDurationMins = (totalDuration.inMinutes / completed.length).round();
      final avgDurHours = avgDurationMins ~/ 60;
      final avgDurMins = avgDurationMins % 60;
      avgDurationStr = '${avgDurHours}h ${avgDurMins}m';

      totalHoursStr = '${totalDuration.inHours}h ${totalDuration.inMinutes.remainder(60)}m';
    }

    return {
      'avgIn': avgInStr,
      'avgOut': avgOutStr,
      'avgDuration': avgDurationStr,
      'totalShifts': '${history.length}',
      'totalHours': totalHoursStr,
      'completedShifts': '${completed.length}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Attendance & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          actions: [
            if (attendanceProvider.history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                onPressed: () {
                  final employeeName = context.read<AuthProvider>().user?.formattedName ?? 'Employee';
                  PdfService.generateAttendanceReport(attendanceProvider.history, employeeName);
                },
                tooltip: 'Download Report',
              ),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryOrange,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Analytics'),
              Tab(icon: Icon(Icons.history_rounded), text: 'History Log'),
            ],
          ),
        ),
        body: attendanceProvider.isLoadingHistory
            ? _buildShimmerLoading()
            : attendanceProvider.history.isEmpty
                ? _buildEmptyState(attendanceProvider.historyError)
                : TabBarView(
                    children: [
                      _buildAnalyticsView(attendanceProvider.history),
                      _buildRecordsView(attendanceProvider),
                    ],
                  ),
      ),
    );
  }

  Widget _buildAnalyticsView(List<dynamic> history) {
    final stats = _calculateAnalytics(history);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workday Averages & Metrics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
          ),
          const SizedBox(height: 4),
          Text(
            'Calculated across ${stats['totalShifts']} logged shift(s)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // 2x2 Grid of KPI Metric Cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildAnalyticsCard(
                title: 'Avg Check-In',
                value: stats['avgIn']!,
                subtitle: 'Average arrival time',
                icon: Icons.login_rounded,
                color: Colors.green,
              ),
              _buildAnalyticsCard(
                title: 'Avg Check-Out',
                value: stats['avgOut']!,
                subtitle: 'Average departure time',
                icon: Icons.logout_rounded,
                color: Colors.deepOrange,
              ),
              _buildAnalyticsCard(
                title: 'Avg Shift Duration',
                value: stats['avgDuration']!,
                subtitle: 'Flexible workday avg',
                icon: Icons.timer_rounded,
                color: AppTheme.accentBlue,
              ),
              _buildAnalyticsCard(
                title: 'Total Shifts',
                value: stats['totalShifts']!,
                subtitle: 'Logged present days',
                icon: Icons.calendar_month_rounded,
                color: Colors.indigo,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Total Work Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                        color: AppTheme.primaryOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: AppTheme.primaryOrange, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Attendance Summary',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkNavy),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryStatItem('Total Shifts', stats['totalShifts']!, Icons.event_available_rounded, AppTheme.accentBlue),
                    Container(height: 36, width: 1, color: Colors.grey[200]),
                    _buildSummaryStatItem('Completed Shifts', stats['completedShifts']!, Icons.check_circle_rounded, Colors.green),
                    Container(height: 36, width: 1, color: Colors.grey[200]),
                    _buildSummaryStatItem('Total Hours', stats['totalHours']!, Icons.schedule_rounded, Colors.teal),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkNavy,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.darkNavy)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildRecordsView(AttendanceProvider attendanceProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: attendanceProvider.history.length,
      itemBuilder: (context, index) {
        final record = attendanceProvider.history[index];
        return _buildHistoryCard(record);
      },
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: error != null ? Colors.red[300] : Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              error != null ? 'Failed to load history' : 'No records found',
              style: TextStyle(fontSize: 18, color: error != null ? Colors.red[700] : Colors.grey[500], fontWeight: FontWeight.bold),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                var email = context.read<AuthProvider>().user?.email ?? '';
                if (email.isEmpty) {
                  email = await _storage.read(key: 'email') ?? 'rachitsaraf@vobpl.com';
                }
                if (mounted) {
                  context.read<AttendanceProvider>().fetchHistory(email);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic record) {
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(record.checkInTime);
    final checkInStr = DateFormat('hh:mm a').format(record.checkInTime);
    final checkOutStr = record.checkOutTime != null 
        ? DateFormat('hh:mm a').format(record.checkOutTime!) 
        : '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                if (record.selfiePath != null && record.selfiePath!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: record.selfiePath!.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: record.selfiePath!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.indigo),
                            )
                          : Image.file(
                              File(record.selfiePath!),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.indigo),
                            ),
                    ),
                  ),
                const Icon(Icons.calendar_today, size: 16, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Present',
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          if (record.remark != null && record.remark!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.note_alt_rounded, size: 14, color: AppTheme.primaryOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Purpose: ${record.remark}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeInfo('CHECK-IN', checkInStr, Icons.login, Colors.green),
                Container(height: 30, width: 1, color: Colors.grey[200]),
                _buildTimeInfo('CHECK-OUT', checkOutStr, Icons.logout, Colors.red),
                Container(height: 30, width: 1, color: Colors.grey[200]),
                _buildTimeInfo('WORKING', _calculateDuration(record), Icons.timer_outlined, Colors.orange),
              ],
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () async {
              final attendanceProvider = context.read<AttendanceProvider>();
              var email = context.read<AuthProvider>().user?.email ?? '';
              if (email.isEmpty) {
                email = await _storage.read(key: 'email') ?? 'rachitsaraf@vobpl.com';
              }
              final breadcrumbs = await attendanceProvider.getBreadcrumbsForDate(email, record.checkInTime);
              if (!mounted) return;

              showDialog(
                context: context,
                builder: (dialogContext) => RouteMapDialog(
                  attendance: record,
                  breadcrumbs: breadcrumbs,
                ),
              );
            },
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.route_rounded, size: 16, color: AppTheme.primaryOrange),
                  const SizedBox(width: 6),
                  Text(
                    'VIEW ROUTE & MAP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryOrange,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.primaryOrange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E))),
      ],
    );
  }

  String _calculateDuration(dynamic record) {
    if (record.checkOutTime == null) return '--:--';
    final diff = record.checkOutTime!.difference(record.checkInTime);
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
}
