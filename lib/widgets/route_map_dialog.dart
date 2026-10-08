import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/breadcrumb_model.dart';
import '../models/attendance_model.dart';
import '../core/theme/app_theme.dart';

class RouteMapDialog extends StatelessWidget {
  final AttendanceModel attendance;
  final List<BreadcrumbModel> breadcrumbs;

  const RouteMapDialog({
    super.key,
    required this.attendance,
    required this.breadcrumbs,
  });

  /// Computes total travel distance in kilometers across consecutive breadcrumbs
  double _calculateTotalDistanceKm() {
    if (breadcrumbs.length < 2) return 0.0;

    double totalMeters = 0.0;
    for (int i = 0; i < breadcrumbs.length - 1; i++) {
      final p1 = breadcrumbs[i];
      final p2 = breadcrumbs[i + 1];
      final distMeters = Geolocator.distanceBetween(
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );
      // Ignore minor indoor GPS drift under 10 meters when standing still
      if (distMeters >= 10.0) {
        totalMeters += distMeters;
      }
    }
    return totalMeters / 1000.0;
  }

  /// Opens Google Maps with the origin check-in location and destination check-out location
  Future<void> _openGoogleMaps(BuildContext context) async {
    final double lat = breadcrumbs.isNotEmpty ? breadcrumbs.first.latitude : attendance.latitude;
    final double lng = breadcrumbs.isNotEmpty ? breadcrumbs.first.longitude : attendance.longitude;

    String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    if (breadcrumbs.length > 1) {
      final last = breadcrumbs.last;
      googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$lat,$lng&destination=${last.latitude},${last.longitude}';
    }

    final Uri uri = Uri.parse(googleMapsUrl);
    try {
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Google Maps: $googleMapsUrl')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please perform a Full App Re-run (Stop & Start in Android Studio) to register native plugin.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalKm = _calculateTotalDistanceKm();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(attendance.checkInTime);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.route_rounded, color: AppTheme.primaryOrange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'On-Duty Route Tracking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Distance & Stats Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'TOTAL DISTANCE',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${totalKm.toStringAsFixed(1)} KM',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  Container(height: 32, width: 1, color: Colors.white30),
                  Column(
                    children: [
                      const Text(
                        'GPS BREADCRUMBS',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${breadcrumbs.isNotEmpty ? breadcrumbs.length : 1} PINS',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Google Maps Launch Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openGoogleMaps(context),
                icon: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'OPEN FULL ROUTE IN GOOGLE MAPS',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'LOCATION TIMELINE LOGS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.secondaryText, letterSpacing: 0.8),
              ),
            ),
            const SizedBox(height: 10),

            // Timeline List
            Expanded(
              child: breadcrumbs.isEmpty
                  ? _buildSinglePinFallback()
                  : ListView.builder(
                      itemCount: breadcrumbs.length,
                      itemBuilder: (context, index) {
                        final item = breadcrumbs[index];
                        final timeStr = DateFormat('hh:mm a').format(item.timestamp);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? Colors.green.withOpacity(0.15)
                                      : (index == breadcrumbs.length - 1 ? Colors.red.withOpacity(0.15) : AppTheme.primaryOrange.withOpacity(0.15)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'PIN #${index + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: index == 0
                                        ? Colors.green[800]
                                        : (index == breadcrumbs.length - 1 ? Colors.red[800] : AppTheme.primaryOrange),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lat: ${item.latitude.toStringAsFixed(5)}, Lng: ${item.longitude.toStringAsFixed(5)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkNavy),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Captured at $timeStr',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.location_on_rounded, color: AppTheme.primaryOrange, size: 18),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePinFallback() {
    final checkInStr = DateFormat('hh:mm a').format(attendance.checkInTime);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('PIN #1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lat: ${attendance.latitude.toStringAsFixed(5)}, Lng: ${attendance.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkNavy),
                ),
                const SizedBox(height: 2),
                Text('Punch-In location recorded at $checkInStr', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
