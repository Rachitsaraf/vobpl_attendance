class BreadcrumbModel {
  final String id;
  final String userEmail;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speed;
  final bool isSynced;

  BreadcrumbModel({
    String? id,
    required this.userEmail,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed = 0.0,
    this.isSynced = false,
  }) : id = id ?? 'bread_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_email': userEmail,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory BreadcrumbModel.fromJson(Map<String, dynamic> json) {
    final timestampStr = (json['timestamp'] ?? '').toString().replaceFirst(' ', 'T');
    return BreadcrumbModel(
      id: json['id']?.toString(),
      userEmail: json['user_email']?.toString() ?? '',
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      timestamp: DateTime.parse(timestampStr),
      speed: double.parse((json['speed'] ?? 0.0).toString()),
      isSynced: (json['is_synced'] == 1 || json['is_synced'] == true),
    );
  }
}
