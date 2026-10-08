class AttendanceModel {
  final String id;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double latitude;
  final double longitude;
  final String status; // 'Present', 'Late', etc.
  final String? unit; // 'Unit 1', 'Unit 2', 'Unit 3', 'Field / On Duty'
  final String? selfiePath;
  final String? remark;
  final bool isSynced;

  AttendanceModel({
    String? id,
    required this.checkInTime,
    this.checkOutTime,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.unit,
    this.selfiePath,
    this.remark,
    this.isSynced = false,
  }) : id = id ?? 'local_${DateTime.now().millisecondsSinceEpoch}';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'check_in': checkInTime.toIso8601String(),
      'check_out': checkOutTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'unit': unit,
      'selfie_path': selfiePath,
      'remark': remark,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    final checkInStr = (json['check_in'] ?? '').toString().replaceFirst(' ', 'T');
    final checkOutStr = (json['check_out'] != null && json['check_out'].toString() != 'null' && json['check_out'].toString().isNotEmpty)
        ? json['check_out'].toString().replaceFirst(' ', 'T')
        : null;

    return AttendanceModel(
      id: json['id']?.toString(),
      checkInTime: DateTime.parse(checkInStr),
      checkOutTime: checkOutStr != null && checkOutStr.isNotEmpty ? DateTime.parse(checkOutStr) : null,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      status: json['status']?.toString() ?? 'Present',
      unit: json['unit']?.toString(),
      selfiePath: json['selfie_path']?.toString(),
      remark: json['remark']?.toString(),
      isSynced: true,
    );
  }
}
