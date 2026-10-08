import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../../models/update_model.dart';
import '../constants/app_constants.dart';

class UpdateCheckResult {
  final bool updateAvailable;
  final AppUpdateInfo? updateInfo;
  final String currentVersion;
  final int currentBuildNumber;
  final String? errorMessage;

  UpdateCheckResult({
    required this.updateAvailable,
    this.updateInfo,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.errorMessage,
  });
}

class UpdateService {
  static int? _dismissedVersionCode;

  /// Check for app updates from company server
  static Future<UpdateCheckResult> checkForUpdate({bool ignoreDismissed = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      final url = Uri.parse('${AppConstants.baseUrl}${AppConstants.updateCheckEndpoint}');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          errorMessage: 'Server returned error status (${response.statusCode})',
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final updateInfo = AppUpdateInfo.fromJson(data);

      // Security Check: Validate APK URL (HTTPS + Trusted Domain)
      if (updateInfo.apkUrl.isNotEmpty) {
        final apkUri = Uri.tryParse(updateInfo.apkUrl);
        if (apkUri == null || apkUri.scheme != 'https') {
          debugPrint('Security Warning: APK URL must use HTTPS');
          return UpdateCheckResult(
            updateAvailable: false,
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
            errorMessage: 'Security policy error: Update URL must use HTTPS.',
          );
        }

        final isTrustedDomain = AppConstants.trustedUpdateDomains.any(
          (domain) => apkUri.host == domain || apkUri.host.endsWith('.$domain'),
        );

        if (!isTrustedDomain) {
          debugPrint('Security Warning: APK host ${apkUri.host} is not in trusted domain list.');
          return UpdateCheckResult(
            updateAvailable: false,
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
            errorMessage: 'Security policy error: Untrusted update server.',
          );
        }
      }

      // Version Comparison
      final isNewerBuild = updateInfo.versionCode > currentBuildNumber;
      final isNewerVersion = _compareVersions(updateInfo.latestVersion, currentVersion) > 0;
      final bool isUpdateNeeded = isNewerBuild || isNewerVersion;

      // Check if user previously dismissed optional update during this session
      if (isUpdateNeeded && !updateInfo.forceUpdate && !ignoreDismissed) {
        if (_dismissedVersionCode == updateInfo.versionCode) {
          return UpdateCheckResult(
            updateAvailable: false,
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
          );
        }
      }

      return UpdateCheckResult(
        updateAvailable: isUpdateNeeded,
        updateInfo: isUpdateNeeded ? updateInfo : null,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
      );
    } catch (e) {
      debugPrint('Error checking for update: $e');
      return UpdateCheckResult(
        updateAvailable: false,
        currentVersion: 'Unknown',
        currentBuildNumber: 1,
        errorMessage: 'Unable to check for updates: $e',
      );
    }
  }

  /// Mark optional update as dismissed for the current app session
  static void dismissUpdate(int versionCode) {
    _dismissedVersionCode = versionCode;
  }

  /// Compare semantic version strings (e.g., "1.1.0" vs "1.0.0")
  static int _compareVersions(String v1, String v2) {
    try {
      final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
      for (int i = 0; i < maxLength; i++) {
        final num1 = i < parts1.length ? parts1[i] : 0;
        final num2 = i < parts2.length ? parts2[i] : 0;
        if (num1 > num2) return 1;
        if (num1 < num2) return -1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
