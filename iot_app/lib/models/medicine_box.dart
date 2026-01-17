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
    List<int> days = [];
    for (int i = 0; i <= 6; i++) {
      if (data[i.toString()] != null) {
        days.add(data[i.toString()] as int);
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
    Map<String, dynamic> map = {
      'id': id,
      'hour': hour,
      'minute': minute,
      'isEnabled': isEnabled,
      'status': status,
    };
    
    for (int i = 0; i < daysOfWeek.length; i++) {
      map[i.toString()] = daysOfWeek[i];
    }
    
    return map;
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
      id: data['_id'] ?? data['id'] ?? '',
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
