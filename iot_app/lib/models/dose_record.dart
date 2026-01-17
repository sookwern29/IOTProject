// Model for medicine dose records
class MedicineRecord {
  final String id;
  final String medicineBoxId;
  final String medicineName;
  final int boxNumber;
  final String medicineType;
  final String deviceId;
  final String reminderTimeId;
  final int reminderHour;
  final int reminderMinute;
  final DateTime scheduledTime;
  final DateTime? takenTime;
  final String status; // upcoming, overdue, completed, missed
  final DateTime createdAt;

  MedicineRecord({
    required this.id,
    required this.medicineBoxId,
    required this.medicineName,
    required this.boxNumber,
    required this.medicineType,
    required this.deviceId,
    required this.reminderTimeId,
    required this.reminderHour,
    required this.reminderMinute,
    required this.scheduledTime,
    this.takenTime,
    this.status = 'upcoming',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ==================== SAFE PARSERS ====================

  static String _parseId(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map && value.containsKey('\$oid')) {
      return value['\$oid'];
    }
    return value.toString();
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is String) {
      return DateTime.parse(value);
    }

    // MongoDB BSON date format
    if (value is Map && value.containsKey('\$date')) {
      return DateTime.parse(value['\$date']);
    }

    throw Exception('Invalid date format: $value');
  }

  // ==================== GETTERS ====================

  bool get isTaken => status == 'completed' || takenTime != null;
  bool get isMissed => status == 'missed';

  double get adherenceScore {
    switch (status) {
      case 'completed':
        return 1.0;
      case 'missed':
        return 0.0;
      case 'overdue':
        return 0.5;
      case 'upcoming':
      default:
        return 0.5;
    }
  }

  // ==================== FROM JSON (MongoDB / API) ====================

  factory MedicineRecord.fromJson(Map<String, dynamic> data) {
    // Normalize status
    String recordStatus =
        (data['status'] ?? 'upcoming').toString().toLowerCase();

    // Backward compatibility for old Firestore-style records
    if (!data.containsKey('status')) {
      if (data['isTaken'] == true) {
        recordStatus = 'completed';
      } else if (data['isMissed'] == true) {
        recordStatus = 'missed';
      }
    }

    return MedicineRecord(
      id: _parseId(data['_id'] ?? data['id']),
      medicineBoxId: data['medicineBoxId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      boxNumber: data['boxNumber'] ?? 0,
      medicineType: data['medicineType'] ?? '',
      deviceId: data['deviceId'] ?? '',
      reminderTimeId:
          data['reminderTimeId'] ?? data['reminderId'] ?? '',
      reminderHour: data['reminderHour'] ?? 0,
      reminderMinute: data['reminderMinute'] ?? 0,
      scheduledTime: _parseDate(data['scheduledTime']),
      takenTime:
          data['takenTime'] != null ? _parseDate(data['takenTime']) : null,
      status: recordStatus,
      createdAt: data['createdAt'] != null
          ? _parseDate(data['createdAt'])
          : DateTime.now(),
    );
  }

  // ==================== TO JSON (API SEND) ====================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineBoxId': medicineBoxId,
      'medicineName': medicineName,
      'boxNumber': boxNumber,
      'medicineType': medicineType,
      'deviceId': deviceId,
      'reminderTimeId': reminderTimeId,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'scheduledTime': scheduledTime.toIso8601String(),
      'takenTime': takenTime?.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
