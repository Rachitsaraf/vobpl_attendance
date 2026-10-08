import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/services/location_service.dart';
import '../core/services/biometric_service.dart';
import '../core/services/security_service.dart';
import '../core/services/database_helper.dart';
import '../core/services/notification_service.dart';
import '../core/services/breadcrumb_service.dart';
import '../core/services/feature_flag_service.dart';
import '../core/constants/app_constants.dart';
import '../models/attendance_model.dart';
import '../models/breadcrumb_model.dart';
import '../repositories/attendance_repository.dart';

class AttendanceProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  final BiometricService _biometricService = BiometricService();
  final AttendanceRepository _repository = AttendanceRepository();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  bool _isChecking = false;
  bool _isCheckedIn = false;
  AttendanceModel? _currentAttendance;
  List<AttendanceModel> _history = [];
  bool _isLoadingHistory = false;
  String _todayTotalTime = '0h 0m';

  bool get isChecking => _isChecking;
  bool get isCheckedIn => _isCheckedIn;
  AttendanceModel? get currentAttendance => _currentAttendance;
  List<AttendanceModel> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;
  String get todayTotalTime => _todayTotalTime;

  String? _historyError;
  String? get historyError => _historyError;

  Future<void> fetchHistory(String userEmail) async {
    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();
    try {
      final fetchedHistory = await _repository.fetchAttendanceHistory(userEmail);
      final localHistory = await DatabaseHelper.instance.getAllAttendance();

      // Combine local SQLite records and server records without losing distinct shifts on the same day
      final List<AttendanceModel> mergedList = List.from(localHistory);

      for (var server in fetchedHistory) {
        final existingIndex = mergedList.indexWhere((l) =>
            l.id == server.id ||
            (l.checkInTime.difference(server.checkInTime).inMinutes.abs() < 5));

        if (existingIndex == -1) {
          mergedList.add(server);
        } else {
          final local = mergedList[existingIndex];
          if (server.checkOutTime != null && local.checkOutTime == null) {
            mergedList[existingIndex] = AttendanceModel(
              id: local.id.isNotEmpty ? local.id : server.id,
              checkInTime: local.checkInTime,
              checkOutTime: server.checkOutTime,
              latitude: local.latitude,
              longitude: local.longitude,
              status: local.status,
              unit: local.unit ?? server.unit,
              selfiePath: local.selfiePath ?? server.selfiePath,
              remark: local.remark ?? server.remark,
            );
          }
        }
      }

      mergedList.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      _history = mergedList;

      // Automatically sync active session state for today from merged history
      final now = DateTime.now();
      AttendanceModel? activeTodayRecord;
      AttendanceModel? latestTodayRecord;

      for (var record in mergedList) {
        if (record.checkInTime.year == now.year &&
            record.checkInTime.month == now.month &&
            record.checkInTime.day == now.day) {
          latestTodayRecord ??= record;
          if (record.checkOutTime == null) {
            activeTodayRecord = record;
            break; // Active session found
          }
        }
      }

      if (activeTodayRecord != null) {
        _isCheckedIn = true;
        _currentAttendance = activeTodayRecord;
      } else if (latestTodayRecord != null) {
        _isCheckedIn = false;
        _currentAttendance = latestTodayRecord;
        if (latestTodayRecord.checkOutTime != null) {
          final duration = latestTodayRecord.checkOutTime!.difference(latestTodayRecord.checkInTime);
          _todayTotalTime = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
        }
      }
    } catch (e) {
      _historyError = e.toString();
      debugPrint('Error fetching history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> checkActiveSession(String userEmail) async {
    try {
      String emailToUse = userEmail;
      if (emailToUse.isEmpty) {
        emailToUse = await _storage.read(key: 'email') ?? '';
      }

      final activeLocal = await DatabaseHelper.instance.getActiveAttendance();
      final now = DateTime.now();

      if (activeLocal != null) {
        if (activeLocal.checkInTime.year == now.year &&
            activeLocal.checkInTime.month == now.month &&
            activeLocal.checkInTime.day == now.day) {
          _isCheckedIn = true;
          _currentAttendance = activeLocal;
          if (emailToUse.isNotEmpty) {
            BreadcrumbService().startTracking(emailToUse);
          }
          notifyListeners();
          return;
        }
      }

      // If not in local SQLite (e.g. app data cleared or reinstalled), check server history!
      if (emailToUse.isNotEmpty) {
        final history = await _repository.fetchAttendanceHistory(emailToUse);
        AttendanceModel? todayActiveServerRecord;
        for (var record in history) {
          if (record.checkInTime.year == now.year &&
              record.checkInTime.month == now.month &&
              record.checkInTime.day == now.day &&
              record.checkOutTime == null) {
            todayActiveServerRecord = record;
            break;
          }
        }

        if (todayActiveServerRecord != null) {
          // Restore into local SQLite so local state & check-out work
          await DatabaseHelper.instance.insertAttendance(todayActiveServerRecord, synced: true);
          _isCheckedIn = true;
          _currentAttendance = todayActiveServerRecord;
          BreadcrumbService().startTracking(emailToUse);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error checking active session: $e');
    }
  }

  Future<void> syncOfflineRecords(String userEmail) async {
    try {
      final unsynced = await DatabaseHelper.instance.getUnsyncedAttendance();
      for (var record in unsynced) {
        // Always try to submit the base attendance (Check-in) first.
        // Our updated submitAttendance now also includes check_out_time if available.
        bool success = await _repository.submitAttendance(record, userEmail);
        
        if (success) {
          await DatabaseHelper.instance.markAsSynced(record.id);
        }
      }

      // Also sync background GPS breadcrumbs
      await syncOfflineBreadcrumbs(userEmail);
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  Future<void> syncOfflineBreadcrumbs(String userEmail) async {
    try {
      final unsyncedBreadcrumbs = await DatabaseHelper.instance.getUnsyncedBreadcrumbs();
      if (unsyncedBreadcrumbs.isNotEmpty) {
        await _repository.submitBreadcrumbs(unsyncedBreadcrumbs, userEmail);
      }
    } catch (e) {
      debugPrint('Breadcrumbs sync error: $e');
    }
  }

  Future<List<BreadcrumbModel>> getBreadcrumbsForDate(String userEmail, DateTime date) async {
    return await DatabaseHelper.instance.getBreadcrumbsForDate(userEmail, date);
  }

  /// Pre-warms the GPS receiver as soon as the Dashboard opens for instant check-in
  void preWarmLocation() {
    _locationService.preWarmLocation();
  }

  Future<String?> checkInWithBiometrics(String userEmail, String? unit, {String? remark}) async {
    if (!FeatureFlagService.isEnabled('enable_biometrics')) {
      return 'Biometric punch is disabled by administrator.';
    }
    _isChecking = true;
    notifyListeners();

    try {
      final isAuthenticated = await _biometricService.authenticate();
      if (!isAuthenticated) {
        _isChecking = false;
        notifyListeners();
        return 'Biometric authentication failed';
      }

      return await _performCheckIn(userEmail, null, unit, remark: remark);
    } catch (e) {
      _isChecking = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> validateLocationAndCheckIn(String? selfiePath, String userEmail, String? unit, {String? remark}) async {
    _isChecking = true;
    notifyListeners();
    return await _performCheckIn(userEmail, selfiePath, unit, remark: remark);
  }

  ({String unitName, UnitLocation unitLocation, GeofenceCheckResult geofenceResult}) _resolvePhysicalUnit(
    Position position, 
    String preferredUnitName,
  ) {
    // 1. Flexible GPS & Dynamic Geofencing for Field Workers
    if (preferredUnitName == AppConstants.fieldUnit || preferredUnitName.contains('Field')) {
      debugPrint('FIELD WORKER PUNCH: Flexible GPS Stamped (Lat: ${position.latitude}, Lng: ${position.longitude})');
      return (
        unitName: AppConstants.fieldUnit,
        unitLocation: UnitLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          northRadiusMeters: 999999.0,
          otherRadiusMeters: 999999.0,
        ),
        geofenceResult: GeofenceCheckResult(
          isAllowed: true,
          distanceMeters: 0,
          allowedRadiusMeters: 999999.0,
          isNorthSide: false,
          directionName: 'Field Location (GPS Stamped)',
          gpsAccuracyMeters: position.accuracy,
        ),
      );
    }

    String targetUnitName = preferredUnitName;
    if (!AppConstants.units.containsKey(targetUnitName)) {
      targetUnitName = 'Unit 1';
    }

    var targetUnit = AppConstants.units[targetUnitName]!;
    var geofenceResult = _locationService.checkDirectionalGeofence(
      centerLat: targetUnit.latitude,
      centerLng: targetUnit.longitude,
      userLat: position.latitude,
      userLng: position.longitude,
      gpsAccuracy: position.accuracy,
      northRadius: targetUnit.northRadiusMeters,
      otherRadius: targetUnit.otherRadiusMeters,
    );

    if (geofenceResult.isAllowed) {
      return (unitName: targetUnitName, unitLocation: targetUnit, geofenceResult: geofenceResult);
    }

    String? closestUnitName;
    UnitLocation? closestUnit;
    GeofenceCheckResult? closestGeofence;
    double minDistance = double.infinity;

    for (var entry in AppConstants.units.entries) {
      final uName = entry.key;
      final uLoc = entry.value;

      final res = _locationService.checkDirectionalGeofence(
        centerLat: uLoc.latitude,
        centerLng: uLoc.longitude,
        userLat: position.latitude,
        userLng: position.longitude,
        gpsAccuracy: position.accuracy,
        northRadius: uLoc.northRadiusMeters,
        otherRadius: uLoc.otherRadiusMeters,
      );

      if (res.isAllowed) {
        debugPrint('AUTO-UNIT ADJUSTMENT: Employee is physically at $uName (${res.distanceMeters.round()}m away)');
        return (unitName: uName, unitLocation: uLoc, geofenceResult: res);
      }

      if (res.distanceMeters < minDistance) {
        minDistance = res.distanceMeters;
        closestUnitName = uName;
        closestUnit = uLoc;
        closestGeofence = res;
      }
    }

    return (
      unitName: closestUnitName ?? targetUnitName,
      unitLocation: closestUnit ?? targetUnit,
      geofenceResult: closestGeofence ?? geofenceResult,
    );
  }

  Future<String?> _performCheckIn(String userEmail, String? selfiePath, String? unit, {String? remark}) async {
    if (_isCheckedIn) {
      _isChecking = false;
      notifyListeners();
      return 'You are already checked in for today!';
    }

    try {
      final security = await SecurityService.checkDeviceSecurity();
      if (!security.isSafe) {
        _isChecking = false;
        notifyListeners();
        return security.errorMessage;
      }
      final activeLocal = await DatabaseHelper.instance.getActiveAttendance();
      if (activeLocal != null) {
        final now = DateTime.now();
        if (activeLocal.checkInTime.year == now.year &&
            activeLocal.checkInTime.month == now.month &&
            activeLocal.checkInTime.day == now.day) {
          _isCheckedIn = true;
          _currentAttendance = activeLocal;
          _isChecking = false;
          notifyListeners();
          return 'You are already checked in for today!';
        }
      }

      final storedUnit = await _storage.read(key: 'unit');
      final preferredUnitName = (unit != null && (AppConstants.units.containsKey(unit) || unit == AppConstants.fieldUnit)) 
          ? unit 
          : ((storedUnit != null && (AppConstants.units.containsKey(storedUnit) || storedUnit == AppConstants.fieldUnit)) ? storedUnit : 'Unit 1');

      final position = await _locationService.getCurrentLocation();
      debugPrint('DEBUG: Your Current Coordinates are: ${position.latitude}, ${position.longitude}');

      final resolved = _resolvePhysicalUnit(position, preferredUnitName);
      final targetUnitName = resolved.unitName;
      final geofenceResult = resolved.geofenceResult;

      debugPrint('DEBUG DISTANCE to $targetUnitName: ${geofenceResult.distanceMeters} meters (Allowed: ${geofenceResult.allowedRadiusMeters}m on ${geofenceResult.directionName})');

      final bool isGeofenceAllowed = !FeatureFlagService.isEnabled('enable_geofencing') || geofenceResult.isAllowed;

      if (isGeofenceAllowed) {
        final attendance = AttendanceModel(
          checkInTime: DateTime.now(),
          latitude: position.latitude,
          longitude: position.longitude,
          status: 'Present',
          unit: targetUnitName,
          selfiePath: selfiePath,
          remark: remark,
        );

        // Schedule 8-hour checkout reminder notification
        NotificationService.scheduleCheckoutReminder(attendance.checkInTime);

        // Start background GPS breadcrumb tracking if enabled for this user
        if (FeatureFlagService.isEnabled('enable_route_tracking')) {
          BreadcrumbService().startTracking(userEmail);
        }

        // 1. Save locally to SQLite immediately
        await DatabaseHelper.instance.insertAttendance(attendance);

        // 2. Trigger HTTP server sync asynchronously in background without blocking UI
        _repository.syncAttendanceInBackground(attendance, userEmail);

        _isCheckedIn = true;
        _currentAttendance = attendance;

        // Update local _history in memory immediately so UI reflects check-in instantly
        final index = _history.indexWhere((r) => r.id == attendance.id);
        if (index != -1) {
          _history[index] = attendance;
        } else {
          _history.insert(0, attendance);
        }

        _isChecking = false;
        notifyListeners();

        return null; // Instant Check-In Success (< 0.3s)
      } else {
        _isChecking = false;
        notifyListeners();
        return geofenceResult.errorMessage ?? 
            'You are ${geofenceResult.distanceMeters.round()}m away on ${geofenceResult.directionName} (Allowed: ${geofenceResult.allowedRadiusMeters.round()}m). Check In is not allowed.';
      }
    } catch (e) {
      _isChecking = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> checkOutWithBiometrics(String userEmail, {String? unit, String? remark}) async {
    if (!FeatureFlagService.isEnabled('enable_biometrics')) {
      return 'Biometric punch is disabled by administrator.';
    }
    _isChecking = true;
    notifyListeners();

    try {
      final isAuthenticated = await _biometricService.authenticate();
      if (!isAuthenticated) {
        _isChecking = false;
        notifyListeners();
        return 'Biometric authentication failed';
      }

      return await checkOut(userEmail, unit: unit, remark: remark);
    } catch (e) {
      _isChecking = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> checkOut(String userEmail, {String? selfiePath, String? unit, String? remark}) async {
    _isChecking = true;
    notifyListeners();

    try {
      final security = await SecurityService.checkDeviceSecurity();
      if (!security.isSafe) {
        _isChecking = false;
        notifyListeners();
        return security.errorMessage;
      }

      String preferredUnitName;
      if (_currentAttendance?.unit != null && (AppConstants.units.containsKey(_currentAttendance!.unit) || _currentAttendance!.unit == AppConstants.fieldUnit)) {
        preferredUnitName = _currentAttendance!.unit!;
      } else if (unit != null && (AppConstants.units.containsKey(unit) || unit == AppConstants.fieldUnit)) {
        preferredUnitName = unit;
      } else {
        final storedUnit = await _storage.read(key: 'unit');
        if (storedUnit != null && (AppConstants.units.containsKey(storedUnit) || storedUnit == AppConstants.fieldUnit)) {
          preferredUnitName = storedUnit;
        } else {
          preferredUnitName = 'Unit 1';
        }
      }

      final position = await _locationService.getCurrentLocation();
      debugPrint('DEBUG: Your Current Coordinates are: ${position.latitude}, ${position.longitude}');

      final resolved = _resolvePhysicalUnit(position, preferredUnitName);
      final assignedUnitName = resolved.unitName;
      final geofenceResult = resolved.geofenceResult;

      debugPrint('DEBUG DISTANCE (Check-Out) to $assignedUnitName: ${geofenceResult.distanceMeters} meters (Allowed: ${geofenceResult.allowedRadiusMeters}m on ${geofenceResult.directionName})');

      if (geofenceResult.isAllowed) {
        final checkOutTime = DateTime.now();
        final activeLocal = await DatabaseHelper.instance.getActiveAttendance();
        final currentRec = _currentAttendance ?? activeLocal;

        final checkInTime = currentRec?.checkInTime ?? DateTime.now();
        final recordId = currentRec?.id;
        
        final completedAttendance = AttendanceModel(
          id: recordId,
          checkInTime: checkInTime,
          checkOutTime: checkOutTime,
          latitude: position.latitude,
          longitude: position.longitude,
          status: 'Present',
          unit: assignedUnitName,
          selfiePath: selfiePath ?? currentRec?.selfiePath,
          remark: remark ?? currentRec?.remark,
        );

        // 1. Update local SQLite immediately
        await DatabaseHelper.instance.insertAttendance(completedAttendance);

        // Cancel pending 8-hour checkout reminder & stop background breadcrumb tracking
        NotificationService.cancelCheckoutReminder();
        BreadcrumbService().stopTracking();

        // 2. Trigger HTTP server check-out sync in background without blocking UI
        _repository.syncCheckOutInBackground(completedAttendance, userEmail);

        final duration = checkOutTime.difference(completedAttendance.checkInTime);
        _todayTotalTime = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';

        _isCheckedIn = false;
        _currentAttendance = completedAttendance;

        // Update local _history in memory immediately so UI reflects check-out instantly
        final index = _history.indexWhere((r) =>
            r.id == completedAttendance.id ||
            (r.checkOutTime == null &&
             r.checkInTime.year == checkOutTime.year &&
             r.checkInTime.month == checkOutTime.month &&
             r.checkInTime.day == checkOutTime.day));
        if (index != -1) {
          _history[index] = completedAttendance;
        } else {
          _history.insert(0, completedAttendance);
        }

        _isChecking = false;
        notifyListeners();
        fetchHistory(userEmail);

        return null; // Instant Check-Out Success (< 0.3s)
      } else {
        _isChecking = false;
        notifyListeners();
        return geofenceResult.errorMessage ??
            'You are ${geofenceResult.distanceMeters.round()}m away on ${geofenceResult.directionName} (Allowed: ${geofenceResult.allowedRadiusMeters.round()}m). Check Out is not allowed.';
      }
    } catch (e) {
      _isChecking = false;
      notifyListeners();
      return e.toString();
    }
  }

  void resetAttendance() {
    _isCheckedIn = false;
    _currentAttendance = null;
    notifyListeners();
  }
}
