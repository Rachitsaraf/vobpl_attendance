import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GeofenceCheckResult {
  final bool isAllowed;
  final double distanceMeters;
  final double allowedRadiusMeters;
  final bool isNorthSide;
  final String directionName;
  final double gpsAccuracyMeters;
  final String? errorMessage;

  GeofenceCheckResult({
    required this.isAllowed,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    required this.isNorthSide,
    required this.directionName,
    required this.gpsAccuracyMeters,
    this.errorMessage,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _cachedPosition;
  DateTime? _cachedPositionTime;
  StreamSubscription<Position>? _positionStreamSub;
  bool _isPreWarming = false;

  /// Pre-warms the GPS receiver as soon as the Dashboard opens.
  /// Uses Google Fused Location Provider for sub-second, high-accuracy fixes.
  Future<void> preWarmLocation() async {
    if (_isPreWarming) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      _isPreWarming = true;
      debugPrint('PRE-WARMING GPS: Starting background Fused Location stream...');

      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        forceLocationManager: false, // Uses Google Play Services Fused Location
        intervalDuration: const Duration(seconds: 3),
      );

      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position pos) {
          if (!pos.isMocked) {
            _cachedPosition = pos;
            _cachedPositionTime = DateTime.now();
            debugPrint('GPS PRE-WARMED [${_cachedPositionTime!.toIso8601String()}]: (${pos.latitude}, ${pos.longitude}) Acc: ${pos.accuracy.round()}m');
          }
        },
        onError: (e) {
          debugPrint('Pre-warm location error: $e');
        },
      );
    } catch (e) {
      debugPrint('Error starting pre-warm location stream: $e');
    }
  }

  /// Stops background pre-warm location stream when no longer needed
  void stopPreWarming() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _isPreWarming = false;
  }

  /// Fetches a fresh, high-accuracy GPS location.
  /// Instantly returns pre-warmed cached position if fresh (< 180s old).
  Future<Position> getCurrentLocation() async {
    // 1. Return pre-warmed cached fix if fresh (< 180s / 3 minutes old)
    if (_cachedPosition != null && _cachedPositionTime != null) {
      final age = DateTime.now().difference(_cachedPositionTime!).inSeconds;
      if (age < 180) {
        debugPrint('INSTANT GPS FIX (Pre-Warmed): Age $age sec (Lat: ${_cachedPosition!.latitude}, Lng: ${_cachedPosition!.longitude})');
        return _cachedPosition!;
      }
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location/GPS services are disabled on your phone. Please turn on GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied in phone settings.');
    } 

    // Trigger pre-warming if not already active
    preWarmLocation();

    Position validPosition;
    try {
      final androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
        forceLocationManager: false, // Google Play Services Fused Location
      );

      validPosition = await Geolocator.getCurrentPosition(locationSettings: androidSettings);
    } catch (_) {
      // Fallback 1: Check pre-warmed cache if available
      if (_cachedPosition != null) {
        validPosition = _cachedPosition!;
      } else {
        // Fallback 2: Check system last known position
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && DateTime.now().difference(lastKnown.timestamp).inMinutes < 10) {
          validPosition = lastKnown;
        } else {
          return Future.error('GPS satellite search timed out. Please ensure GPS is enabled and try again.');
        }
      }
    }

    if (validPosition.isMocked) {
      return Future.error('Fake GPS / Mock Location detected! Please disable fake location apps.');
    }

    // Update cache
    _cachedPosition = validPosition;
    _cachedPositionTime = DateTime.now();

    return validPosition;
  }

  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Calculates distance & bearing to apply directional geofence consistently
  GeofenceCheckResult checkDirectionalGeofence({
    required double centerLat,
    required double centerLng,
    required double userLat,
    required double userLng,
    required double gpsAccuracy,
    required double northRadius,
    required double otherRadius,
  }) {
    final distance = calculateDistance(centerLat, centerLng, userLat, userLng);
    final rawBearing = Geolocator.bearingBetween(centerLat, centerLng, userLat, userLng);

    // Standardize bearing to [-180, 180] degrees range across all Android/iOS implementations
    double normalizedBearing = rawBearing;
    while (normalizedBearing > 180.0) {
      normalizedBearing -= 360.0;
    }
    while (normalizedBearing < -180.0) {
      normalizedBearing += 360.0;
    }

    // North side sector is bearing between -45 deg and +45 deg
    final bool isNorthSide = normalizedBearing >= -45.0 && normalizedBearing <= 45.0;
    final double allowedRadius = isNorthSide ? northRadius : otherRadius;
    final String directionName = isNorthSide ? "North (Gate direction)" : "Office Premises";

    // Reject extremely coarse / low-accuracy cell tower fixes (> 65m error)
    if (gpsAccuracy > 65.0) {
      if (distance > allowedRadius) {
        return GeofenceCheckResult(
          isAllowed: false,
          distanceMeters: distance,
          allowedRadiusMeters: allowedRadius,
          isNorthSide: isNorthSide,
          directionName: directionName,
          gpsAccuracyMeters: gpsAccuracy,
          errorMessage: 'GPS accuracy is low (${gpsAccuracy.round()}m error). Please move closer to a window or outdoors to get a satellite GPS fix.',
        );
      }
    }

    // Account for minor indoor GPS signal drift (up to 15m buffer when gpsAccuracy is normal)
    final double accuracyBuffer = (gpsAccuracy * 0.35).clamp(0.0, 15.0);
    final double effectiveAllowedRadius = allowedRadius + accuracyBuffer;

    final bool isAllowed = distance <= effectiveAllowedRadius;
    String? errorMessage;
    if (!isAllowed) {
      errorMessage = 'You are ${distance.round()}m away on $directionName (Allowed: ${allowedRadius.round()}m). Attendance is not allowed.';
    }

    return GeofenceCheckResult(
      isAllowed: isAllowed,
      distanceMeters: distance,
      allowedRadiusMeters: allowedRadius,
      isNorthSide: isNorthSide,
      directionName: directionName,
      gpsAccuracyMeters: gpsAccuracy,
      errorMessage: errorMessage,
    );
  }
}
