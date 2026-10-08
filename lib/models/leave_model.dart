enum LeaveStatus { pending, approved, rejected }
enum LeaveType { leave, halfday }

extension LeaveTypeExtension on LeaveType {
  String get displayName {
    switch (this) {
      case LeaveType.leave:
        return 'Leave';
      case LeaveType.halfday:
        return 'Half Day';
    }
  }
}

class LeaveModel {
  final String id;
  final String userEmail;
  final DateTime startDate;
  final DateTime endDate;
  final LeaveType type;
  final String reason;
  final LeaveStatus status;
  final DateTime requestedAt;

  LeaveModel({
    required this.id,
    required this.userEmail,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.reason,
    this.status = LeaveStatus.pending,
    required this.requestedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': userEmail,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'type': type.name,
      'reason': reason,
      'status': status.name,
      'requested_at': requestedAt.toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic dateVal) {
    if (dateVal == null) return DateTime.now();
    final str = dateVal.toString().trim();
    if (str.isEmpty) return DateTime.now();
    try {
      final formattedStr = str.contains(' ') ? str.replaceAll(' ', 'T') : str;
      return DateTime.tryParse(formattedStr) ?? DateTime.tryParse(str) ?? DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status']?.toString() ?? 'pending').toLowerCase();
    final typeStr = (json['type']?.toString() ?? 'leave').toLowerCase();

    return LeaveModel(
      id: json['id']?.toString() ?? '',
      userEmail: json['email']?.toString() ?? '',
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      type: LeaveType.values.firstWhere(
        (e) => e.name.toLowerCase() == typeStr || (typeStr.contains('half') && e == LeaveType.halfday),
        orElse: () => LeaveType.leave,
      ),
      reason: json['reason']?.toString() ?? '',
      status: LeaveStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == statusStr,
        orElse: () => LeaveStatus.pending,
      ),
      requestedAt: _parseDate(json['requested_at']),
    );
  }
}
