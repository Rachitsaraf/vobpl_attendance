import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:android_id/android_id.dart';

class SecurityCheckResult {
  final bool isSafe;
  final String? errorMessage;

  SecurityCheckResult({required this.isSafe, this.errorMessage});
}

class SecurityService {
  static const _androidId = AndroidId();
  static SecurityCheckResult? _cachedSecurityResult;

  /// Gets unique hardware Device ID for Device Binding
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final id = await _androidId.getId();
        return id ?? 'unknown_android_device';
      }
      return 'non_android_device';
    } catch (e) {
      debugPrint('Error getting Device ID: $e');
      return 'unknown_device';
    }
  }

  /// Verifies device safety in parallel with result caching (< 10ms after pre-warm)
  static Future<SecurityCheckResult> checkDeviceSecurity({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSecurityResult != null) {
      return _cachedSecurityResult!;
    }

    try {
      // Execute all 3 security checks in parallel
      final results = await Future.wait([
        SafeDevice.isJailBroken,
        SafeDevice.isRealDevice,
        SafeDevice.isMockLocation,
      ]);

      final isJailBroken = results[0];
      final isRealDevice = results[1];
      final isMockLocation = results[2];

      SecurityCheckResult result = SecurityCheckResult(isSafe: true);

      if (isJailBroken) {
        result = SecurityCheckResult(
          isSafe: false,
          errorMessage: 'Security Policy Violation: Rooted / Jailbroken device detected. Attendance & Login blocked for security.',
        );
      } else if (!isRealDevice) {
        result = SecurityCheckResult(
          isSafe: false,
          errorMessage: 'Security Policy Violation: Android Emulator detected. App must be run on a physical mobile phone.',
        );
      } else if (isMockLocation) {
        result = SecurityCheckResult(
          isSafe: false,
          errorMessage: 'Security Policy Violation: Fake GPS / Mock Location app active. Please disable Fake GPS to proceed.',
        );
      }

      _cachedSecurityResult = result;
      return result;
    } catch (e) {
      debugPrint('Security check error: $e');
      final result = SecurityCheckResult(isSafe: true); // Fail open if library unsupported on specific OS version
      _cachedSecurityResult = result;
      return result;
    }
  }
}
