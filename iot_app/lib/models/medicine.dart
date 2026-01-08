import 'package:cloud_firestore/cloud_firestore.dart';

class Medicine {
  final String id;
  final String name;
  final String boxId;
  final int compartmentNumber;
  final List<String> reminderTimes; // Times in HH:mm format
  final int dosagePerTime;
  final String? notes;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  Medicine({
    required this.id,
    required this.name,
    required this.boxId,
    required this.compartmentNumber,
    required this.reminderTimes,
    required this.dosagePerTime,
    this.notes,
    required this.startDate,
    this.endDate,
    this.isActive = true,
  });

  factory Medicine.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Medicine(
      id: doc.id,
      name: data['name'] ?? '',
      boxId: data['boxId'] ?? '',
      compartmentNumber: data['compartmentNumber'] ?? 0,
      reminderTimes: List<String>.from(data['reminderTimes'] ?? []),
      dosagePerTime: data['dosagePerTime'] ?? 1,
      notes: data['notes'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null 
          ? (data['endDate'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'boxId': boxId,
      'compartmentNumber': compartmentNumber,
      'reminderTimes': reminderTimes,
      'dosagePerTime': dosagePerTime,
      'notes': notes,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isActive': isActive,
    };
  }
}
