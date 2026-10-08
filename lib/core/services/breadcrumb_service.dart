import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'location_service.dart';
import '../../models/breadcrumb_model.dart';

class BreadcrumbService {
  static final BreadcrumbService _instance = BreadcrumbService._internal();
  factory BreadcrumbService() => _instance;
  BreadcrumbService._internal();

  final LocationService _locationService = LocationService();
  Timer? _timer;
  bool _isTracking = false;
  String? _currentUserEmail;

  bool get isTracking => _isTracking;

  /// Default interval is 15 minutes.
  static const Duration defaultInterval = Duration(minutes: 15);

  /// Starts periodic background GPS breadcrumb collection while on-duty
  Future<void> startTracking(String userEmail, {Duration interval = defaultInterval}) async {
    if (_isTracking && _currentUserEmail == userEmail) {
      debugPrint('BreadcrumbService: Already tracking for $userEmail');
      return;
    }

    _currentUserEmail = userEmail;
    _isTracking = true;

    debugPrint('BreadcrumbService: Starting periodic tracking for $userEmail (Interval: ${interval.inMinutes}m)');

    // Log first breadcrumb immediately
    await _captureAndSaveBreadcrumb();

    // Schedule periodic timer
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      if (_isTracking && _currentUserEmail != null) {
        await _captureAndSaveBreadcrumb();
      }
    });
  }

  /// Stops tracking when user checks out
  void stopTracking() {
    debugPrint('BreadcrumbService: Stopping tracking for $_currentUserEmail');
    _timer?.cancel();
    _timer = null;
    _isTracking = false;
    _currentUserEmail = null;
  }

  /// Manually triggers an immediate location breadcrumb fix
  Future<void> captureImmediateBreadcrumb(String userEmail) async {
    _currentUserEmail = userEmail;
    await _captureAndSaveBreadcrumb();
  }

  Future<void> _captureAndSaveBreadcrumb() async {
    if (_currentUserEmail == null || _currentUserEmail!.isEmpty) return;

    try {
      final position = await _locationService.getCurrentLocation();
      final breadcrumb = BreadcrumbModel(
        userEmail: _currentUserEmail!,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        speed: position.speed,
      );

      await DatabaseHelper.instance.insertBreadcrumb(breadcrumb);
      debugPrint('BREADCRUMB LOGGED [${breadcrumb.timestamp}]: (${position.latitude}, ${position.longitude}) @ ${position.speed.round()}m/s');
    } catch (e) {
      debugPrint('Breadcrumb capture error: $e');
    }
  }
}
