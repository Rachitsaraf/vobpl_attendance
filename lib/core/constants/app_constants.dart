class UnitLocation {
  final double latitude;
  final double longitude;
  final double northRadiusMeters;
  final double otherRadiusMeters;

  const UnitLocation({
    required this.latitude,
    required this.longitude,
    this.northRadiusMeters = 100.0,
    this.otherRadiusMeters = 100.0,
  });
}

class AppConstants {
  // Field Worker Unit Constant
  static const String fieldUnit = 'Field / On Duty';
  static const List<String> availableUnits = [
    'Unit 1',
    'Unit 2',
    'Unit 3',
    'Field / On Duty',
  ];

  // Unit-specific GPS Coordinates with exact Office Center & 100m Geofence Radius
  static const Map<String, UnitLocation> units = {
    'Unit 1': UnitLocation(
      latitude: 22.779023,
      longitude: 75.843565,
      northRadiusMeters: 100.0,
      otherRadiusMeters: 100.0,
    ),
    'Unit 2': UnitLocation(
      latitude: 22.783991,
      longitude: 75.841035,
      northRadiusMeters: 100.0,
      otherRadiusMeters: 100.0,
    ),
    'Unit 3': UnitLocation(
      latitude: 22.869168,
      longitude: 75.888069,
      northRadiusMeters: 100.0,
      otherRadiusMeters: 100.0,
    ),
  };

  // API Endpoints (Custom PHP REST API on Subdomain)
  static const String baseUrl = 'https://api.vobplsmart.in/api';
  static const String checkInEndpoint = '/attendance/check_in.php';
  static const String checkOutEndpoint = '/attendance/check_out.php';
  static const String historyEndpoint = '/attendance/history.php';
  
  // Profile Management
  static const String saveProfileEndpoint = '/attendance/save_profile.php';
  static const String getProfileEndpoint = '/attendance/get_profile.php';

  // App Update Management
  static const String updateCheckEndpoint = '/attendance/check_update.php';
  
  // Trusted domains for APK downloads (Security validation)
  static const List<String> trustedUpdateDomains = [
    'vobplsmart.in',
    'api.vobplsmart.in',
    'companywebsite.com',
  ];
}
