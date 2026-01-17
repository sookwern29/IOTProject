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

  // ✅ REACTIVE GETTERS (FIXED)
  bool get isTaken => status == 'completed' || takenTime != null;
  bool get isMissed => status == 'missed';

  // Keep fromFirestore for backward compatibility (unused now)
  factory MedicineRecord.fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicineRecord.fromJson({...data, 'id': doc.id});
  }

  factory MedicineRecord.fromJson(Map<String, dynamic> data) {
    // Normalize status
    String recordStatus = (data['status'] ?? 'upcoming').toString().toLowerCase();

    // Backward compatibility for old records
    if (!data.containsKey('status')) {
      if (data['isTaken'] == true) {
        recordStatus = 'completed';
      } else if (data['isMissed'] == true) {
        recordStatus = 'missed';
      }
    }

    return MedicineRecord(
      id: data['_id'] ?? data['id'] ?? '',
      medicineBoxId: data['medicineBoxId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      boxNumber: data['boxNumber'] ?? 0,
      medicineType: data['medicineType'] ?? '',
      deviceId: data['deviceId'] ?? '',
      reminderTimeId: data['reminderTimeId'] ?? '',
      reminderHour: data['reminderHour'] ?? 0,
      reminderMinute: data['reminderMinute'] ?? 0,
      scheduledTime: DateTime.parse(data['scheduledTime']),
      takenTime: data['takenTime'] != null
          ? DateTime.parse(data['takenTime'])
          : null,
      status: recordStatus,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
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
}
