// Model for medicine box and reminder configuration

class ReminderTime {
  final String id;
  final int hour;
  final int minute;
  final bool isEnabled;
  final List<int> daysOfWeek; // 0=Sunday, 1=Monday, etc.
  final String status;

  ReminderTime({
    required this.id,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
    required this.daysOfWeek,
    this.status = 'upcoming',
  });

  factory ReminderTime.fromMap(Map<String, dynamic> data) {
    // Handle both old format (individual numbered keys) and new format (daysOfWeek array)
    List<int> days = [];
    
    if (data['daysOfWeek'] != null && data['daysOfWeek'] is List) {
      // New format: daysOfWeek array
      days = List<int>.from(data['daysOfWeek']);
    } else {
      // Old format: individual numbered keys (0, 1, 2, etc.)
      for (int i = 0; i <= 6; i++) {
        if (data[i.toString()] != null) {
          days.add(data[i.toString()] as int);
        }
      }
    }
    
    return ReminderTime(
      id: data['id'] ?? '',
      hour: data['hour'] ?? 0,
      minute: data['minute'] ?? 0,
      isEnabled: data['isEnabled'] ?? true,
      daysOfWeek: days,
      status: data['status'] ?? 'upcoming',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'isEnabled': isEnabled,
      'daysOfWeek': daysOfWeek,
      'status': status,
    };
  }

  String getTimeString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class MedicineBox {
  final String id;
  final String name;
  final int boxNumber;
  final String deviceId;
  final String medicineType;
  final bool isConnected;
  final DateTime? lastUpdated;
  final List<ReminderTime> reminders;
  final dynamic compartments;

  MedicineBox({
    required this.id,
    required this.name,
    required this.boxNumber,
    required this.deviceId,
    this.medicineType = 'prescription',
    this.isConnected = false,
    this.lastUpdated,
    this.reminders = const [],
    this.compartments,
  });

  // Keep fromFirestore for backward compatibility (unused now)
  factory MedicineBox.fromFirestore(dynamic doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    List<ReminderTime> remindersList = [];
    if (data['reminders'] != null && data['reminders'] is List) {
      for (var reminderData in data['reminders']) {
        remindersList.add(ReminderTime.fromMap(reminderData));
      }
    }
    
    return MedicineBox(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? '',
      boxNumber: data['boxNumber'] ?? 0,
      deviceId: data['deviceId'] ?? '',
      medicineType: data['medicineType'] ?? 'prescription',
      isConnected: data['isConnected'] ?? false,
      lastUpdated: data['lastUpdated'] != null 
          ? DateTime.parse(data['lastUpdated'])
          : null,
      reminders: remindersList,
      compartments: data['compartments'],
    );
  }

  factory MedicineBox.fromJson(Map<String, dynamic> data) {
    List<ReminderTime> remindersList = [];
    if (data['reminders'] != null && data['reminders'] is List) {
      for (var reminderData in data['reminders']) {
        remindersList.add(ReminderTime.fromMap(reminderData));
      }
    }
    
    return MedicineBox(
      id: data['id'] ?? data['_id'] ?? '',  // Use 'id' field first, fall back to '_id'
      name: data['name'] ?? '',
      boxNumber: data['boxNumber'] ?? 0,
      deviceId: data['deviceId'] ?? '',
      medicineType: data['medicineType'] ?? 'prescription',
      isConnected: data['isConnected'] ?? false,
      lastUpdated: data['lastUpdated'] != null 
          ? DateTime.parse(data['lastUpdated'])
          : null,
      reminders: remindersList,
      compartments: data['compartments'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'boxNumber': boxNumber,
      'deviceId': deviceId,
      'medicineType': medicineType,
      'isConnected': isConnected,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'reminders': reminders.map((r) => r.toMap()).toList(),
      'compartments': compartments,
    };
  }
  
  // Alias for toJson
  Map<String, dynamic> toJson() => toFirestore();
}
