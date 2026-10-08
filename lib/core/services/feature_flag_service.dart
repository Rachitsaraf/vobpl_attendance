import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // Default fallback flags (used when offline or before server load)
  final Map<String, bool> _flags = {
    'enable_face_matching': true,
    'enable_geofencing': true,
    'enable_biometrics': true,
    'enable_route_tracking': true,
    'enable_offline_mode': true,
    'maintenance_mode': false,
  };

  /// Returns true if a feature is enabled for the current user session
  static bool isEnabled(String featureKey, {bool defaultValue = true}) {
    return _instance._flags[featureKey] ?? defaultValue;
  }

  /// Read-only map of all active feature flags
  Map<String, bool> get allFlags => Map.unmodifiable(_flags);

  /// Fetches user-targeted feature flags from PHP REST API server
  Future<void> fetchTargetedFlags(String userEmail, {String? unit}) async {
    if (userEmail.isEmpty) return;

    try {
      final uri = Uri.parse(
        '${AppConstants.baseUrl}/attendance/get_feature_flags.php?email=${Uri.encodeComponent(userEmail)}&unit=${Uri.encodeComponent(unit ?? '')}',
      );

      debugPrint('FETCHING TARGETED FEATURE FLAGS: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['flags'] != null) {
          final Map<String, dynamic> remoteFlags = data['flags'];
          remoteFlags.forEach((key, value) {
            _flags[key] = value == true || value == 1 || value == '1' || value == 'true';
          });
          _isLoaded = true;
          debugPrint('FEATURE FLAGS TARGETED FOR $userEmail ($unit): $_flags');
        }
      }
    } catch (e) {
      debugPrint('Error fetching feature flags: $e (using fallback local defaults)');
    }
  }
}
