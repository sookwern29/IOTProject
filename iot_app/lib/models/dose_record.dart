import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Backward compatibility getters
  bool get isTaken => status == 'completed';
  bool get isMissed => status == 'missed';

  factory MedicineRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle migration from old boolean fields to new status field
    String recordStatus;
    if (data.containsKey('status')) {
      recordStatus = data['status'] ?? 'upcoming';
    } else {
      // Backward compatibility: convert old booleans to status
      if (data['isTaken'] == true) {
        recordStatus = 'completed';
      } else if (data['isMissed'] == true) {
        recordStatus = 'missed';
      } else {
        recordStatus = 'upcoming';
      }
    }
    
    return MedicineRecord(
      id: data['id'] ?? doc.id,
      medicineBoxId: data['medicineBoxId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      boxNumber: data['boxNumber'] ?? 0,
      medicineType: data['medicineType'] ?? '',
      deviceId: data['deviceId'] ?? '',
      reminderTimeId: data['reminderTimeId'] ?? '',
      reminderHour: data['reminderHour'] ?? 0,
      reminderMinute: data['reminderMinute'] ?? 0,
      scheduledTime: (data['scheduledTime'] as Timestamp).toDate(),
      takenTime: data['takenTime'] != null 
          ? (data['takenTime'] as Timestamp).toDate() 
          : null,
      status: recordStatus,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
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
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'takenTime': takenTime != null ? Timestamp.fromDate(takenTime!) : null,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
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
