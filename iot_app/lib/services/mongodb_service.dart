import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/medicine_box.dart';
import '../models/dose_record.dart';
import 'auth_service.dart';

/// MongoDB Service for Medicine Box App
/// Replaces FirestoreService with MongoDB Atlas backend
class MongoDBService {
  static const String _baseUrl =
      'https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app';
  final AuthService _authService = AuthService();

  String get _userId => _authService.currentUserId ?? 'user123';

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    // Note: Add token to headers when your MongoDB API supports authentication
    return headers;
  }

  // ==================== MEDICINE BOX CRUD ====================

  Future<MedicineBox> addMedicineBox(MedicineBox box) async {
    print('📤 Creating medicine box');
    print('📦 Box data: ${json.encode(box.toJson())}');

    final response = await http.post(
      Uri.parse('$_baseUrl/medicineBoxes'),
      headers: _headers,
      body: json.encode(box.toJson()),
    );

    print('📥 Create response status: ${response.statusCode}');
    print('📥 Create response body: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add medicine box: ${response.body}');
    }

    // Return the box with the MongoDB-assigned ID
    final responseData = json.decode(response.body);
    return MedicineBox.fromJson(responseData);
  }

  Future<void> updateMedicineBox(MedicineBox box) async {
    final boxJson = box.toJson();
    print('📤 Updating medicine box ${box.id}');
    print('📦 Box data: ${json.encode(boxJson)}');
    print('🔔 Reminders count: ${box.reminders.length}');

    final response = await http.put(
      Uri.parse('$_baseUrl/medicineBoxes/${box.id}'),
      headers: _headers,
      body: json.encode(boxJson),
    );

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to update medicine box: ${response.body}');
    }
  }

  Future<void> deleteMedicineBox(String boxId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/medicineBoxes/$boxId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete medicine box: ${response.body}');
    }
  }

  Stream<List<MedicineBox>> getMedicineBoxes() async* {
    // Poll periodically since MongoDB doesn't have real-time listeners like Firestore
    while (true) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/medicineBoxes'),
          headers: _headers,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          yield data.map((item) => MedicineBox.fromJson(item)).toList();
        } else {
          yield [];
        }
      } catch (e) {
        print('Error fetching medicine boxes: $e');
        yield [];
      }

      await Future.delayed(Duration(seconds: 5)); // Poll every 5 seconds
    }
  }

  Future<List<MedicineBox>> getMedicineBoxesList() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/medicineBoxes'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => MedicineBox.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching medicine boxes: $e');
    }
    return [];
  }

  Future<MedicineBox?> getMedicineBox(String boxId) async {
    try {
      print('🔍 Fetching medicine box with ID: $boxId');

      // Since GET /medicineBoxes/{id} endpoint doesn't exist,
      // we fetch all boxes and find the one we need
      final boxes = await getMedicineBoxesList();
      print('📦 Total boxes in database: ${boxes.length}');

      final box = boxes.firstWhere(
        (b) => b.id == boxId,
        orElse: () => throw Exception('Box not found'),
      );

      print('✅ Box found: ${box.name}, reminders: ${box.reminders.length}');
      return box;
    } catch (e) {
      print('❌ Error fetching medicine box: $e');
      return null;
    }
  }

  Future<MedicineBox?> getMedicineBoxByNumber(int boxNumber) async {
    try {
      final boxes = await getMedicineBoxesList();
      return boxes.firstWhere(
        (box) => box.boxNumber == boxNumber,
        orElse: () => throw Exception('Box not found'),
      );
    } catch (e) {
      print('Error finding medicine box by number: $e');
      return null;
    }
  }

  Future<void> updateAllReminderStatuses() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/updateReminderStatuses'),
        headers: _headers,
      );
    } catch (e) {
      print('Error updating reminder statuses: $e');
    }
  }

  // ==================== MEDICINE RECORDS CRUD ====================

  Future<void> createRecord(MedicineRecord record) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/createRecord'),
      headers: _headers,
      body: json.encode({
        'recordId': record.id,
        'deviceId': record.deviceId,
        'boxNumber': record.boxNumber,
        'medicineName': record.medicineName,
        'medicineType': record.medicineType,
        'medicineBoxId': record.medicineBoxId,
        'scheduledTime': record.scheduledTime.toIso8601String(),
        'status': record.status,
        'userId': _userId,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create record: ${response.body}');
    }
  }

  Future<void> updateRecord(MedicineRecord record) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/updateRecord'),
      headers: _headers,
      body: json.encode({
        'recordId': record.id,
        'status': record.status,
        'takenTime': record.takenTime?.toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update record: ${response.body}');
    }
  }

  Future<void> deleteRecord(String recordId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/deleteRecord'),
      headers: _headers,
      body: json.encode({'recordId': recordId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete record: ${response.body}');
    }
  }

  Future<List<MedicineRecord>> getRecords({String? deviceId}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/getRecords'),
        headers: _headers,
        body: json.encode({'deviceId': deviceId ?? ''}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => MedicineRecord.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching records: $e');
    }
    return [];
  }

  // ==================== SPECIFIC QUERIES ====================

  Future<List<MedicineRecord>> getTodayDoses() async {
    final now = DateTime.now();
    print('📅 getTodayDoses() called');
    print('🕐 Client time: ${now.toIso8601String()}');
    print(
      '📆 Today date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );

    List<MedicineRecord> apiDoses = [];

    // Get user's local date (midnight in user's timezone)
    final userDate = DateTime(now.year, now.month, now.day);
    print('📤 Sending user date to backend: ${userDate.toIso8601String()}');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/doses/today'),
        headers: _headers,
        body: json.encode({'userDate': userDate.toIso8601String()}),
      );

      print('📥 /doses/today response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle new response format with debug info
        final List<dynamic> data;
        if (responseData is Map && responseData.containsKey('records')) {
          data = responseData['records'];
          // Print debug info from backend
          if (responseData.containsKey('debug')) {
            print('🐛 Backend debug: ${responseData['debug']}');
          }
        } else {
          // Old format - just array
          data = responseData;
        }

        apiDoses = data.map((item) => MedicineRecord.fromJson(item)).toList();
        print('✅ API returned ${apiDoses.length} doses');

        // Debug: Show what API returned
        for (var dose in apiDoses) {
          print(
            '  📊 ${dose.medicineName}: scheduled=${dose.scheduledTime.toIso8601String()}, status=${dose.status}',
          );
        }

        // If API has real records, use them (they have actual DB IDs for updates)
        if (apiDoses.isNotEmpty) {
          print('📊 Using API records with actual DB IDs');
          return apiDoses
            ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
        }
      }
    } catch (e) {
      print('⚠️ Error fetching today doses from API: $e');
    }

    // Fallback: generate from reminders only if API returned nothing
    print('🔄 API empty, generating doses from reminders as fallback');
    try {
      final generated = await _generateTodayDosesFromReminders();
      print('✅ Generated ${generated.length} doses from reminders');
      return generated
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    } catch (e) {
      print('❌ Error generating today doses from reminders: $e');
    }

    return [];
  }

  /// Build today's doses from medicine box reminders when the API endpoint is missing
  Future<List<MedicineRecord>> _generateTodayDosesFromReminders() async {
    final doses = <MedicineRecord>[];
    final now = DateTime.now();
    final todayWeekday = now.weekday % 7; // 0=Sun,1=Mon,...6=Sat

    print(
      '🗓️ Today is weekday: $todayWeekday (${_weekdayName(todayWeekday)})',
    );

    final boxes = await getMedicineBoxesList();
    print('📦 Found ${boxes.length} medicine boxes');

    for (final box in boxes) {
      print('🔍 Checking box: ${box.name} (${box.reminders.length} reminders)');
      for (final reminder in box.reminders) {
        print(
          '  ⏰ Reminder: ${reminder.hour}:${reminder.minute}, enabled=${reminder.isEnabled}, days=${reminder.daysOfWeek}',
        );

        if (!reminder.isEnabled) {
          print('    ❌ Skipped: not enabled');
          continue;
        }
        if (!reminder.daysOfWeek.contains(todayWeekday)) {
          print('    ❌ Skipped: today not in schedule');
          continue;
        }

        final scheduled = DateTime(
          now.year,
          now.month,
          now.day,
          reminder.hour,
          reminder.minute,
        );

        final dose = MedicineRecord(
          id: 'dose_${box.id}_${reminder.id}_${now.toIso8601String().split('T').first}',
          medicineBoxId: box.id,
          medicineName: box.name,
          boxNumber: box.boxNumber,
          medicineType: box.medicineType,
          deviceId: box.deviceId,
          reminderTimeId: reminder.id,
          reminderHour: reminder.hour,
          reminderMinute: reminder.minute,
          scheduledTime: scheduled,
          status: 'upcoming',
        );
        doses.add(dose);

        print(
          '    ✅ Added dose: ${box.name} at ${reminder.hour}:${reminder.minute}',
        );
      }
    }

    doses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    print('📊 Total doses generated: ${doses.length}');
    return doses;
  }

  String _weekdayName(int day) {
    const names = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return names[day];
  }

  Stream<List<MedicineRecord>> getTodayDosesFromBoxes() async* {
    // Poll for today's doses
    while (true) {
      yield await getTodayDoses();
      await Future.delayed(Duration(seconds: 5));
    }
  }

  Future<List<MedicineRecord>> getRecordsInRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/getRecordsInRange'),
        headers: _headers,
        body: json.encode({
          'startDate': start.toIso8601String(),
          'endDate': end.toIso8601String(),
          'userId': _userId,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => MedicineRecord.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching records in range: $e');
    }
    return [];
  }

  Stream<List<MedicineRecord>> getRecordsInRangeStream(
    DateTime start,
    DateTime end,
  ) async* {
    while (true) {
      yield await getRecordsInRange(start, end);
      await Future.delayed(
        Duration(seconds: 10),
      ); // Less frequent polling for reports
    }
  }

  // ==================== RECORD STATUS UPDATES ====================

  Future<void> markRecordAsTaken(String recordId) async {
    try {
      print('📤 Marking record $recordId as taken');

      // Check if this is a generated dose (ID starts with 'dose_')
      if (recordId.startsWith('dose_')) {
        print('🔄 Generated dose detected, marking reminder as taken in DB');

        // Parse the generated ID: dose_boxId_reminderId_date
        final parts = recordId.split('_');
        if (parts.length >= 3) {
          final boxId = parts[1];
          final reminderId = parts[2];

          print('📋 Extracted: boxId=$boxId, reminderId=$reminderId');

          // Update the reminder status directly
          final response = await http.post(
            Uri.parse('$_baseUrl/markReminderAsTaken'),
            headers: _headers,
            body: json.encode({
              'medicineBoxId': boxId,
              'reminderId': reminderId,
              'takenTime': DateTime.now().toIso8601String(),
              'userId': _userId,
            }),
          );

          print('📥 Response status: ${response.statusCode}');
          print('📥 Response body: ${response.body}');

          if (response.statusCode == 200) {
            print('✅ Reminder marked as taken successfully');
            return;
          }
        }
        print(
          '⚠️ Could not parse generated ID, trying standard endpoint anyway',
        );
      }

      // Standard approach for real DB records
      final response = await http.post(
        Uri.parse('$_baseUrl/updateRecord'),
        headers: _headers,
        body: json.encode({
          'recordId': recordId,
          'status': 'completed',
          'takenTime': DateTime.now().toIso8601String(),
        }),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to mark record as taken: ${response.body}');
      }

      print('✅ Record marked as taken successfully');
    } catch (e) {
      print('❌ Error marking record as taken: $e');
      rethrow;
    }
  }

  Future<void> markRecordAsMissed(String recordId) async {
    try {
      print('📤 Marking record $recordId as missed');

      // Check if this is a generated dose (ID starts with 'dose_')
      if (recordId.startsWith('dose_')) {
        print('🔄 Generated dose detected, marking reminder as missed in DB');

        // Parse the generated ID: dose_boxId_reminderId_date
        final parts = recordId.split('_');
        if (parts.length >= 3) {
          final boxId = parts[1];
          final reminderId = parts[2];

          print('📋 Extracted: boxId=$boxId, reminderId=$reminderId');

          // Update the reminder status directly
          final response = await http.post(
            Uri.parse('$_baseUrl/markReminderAsMissed'),
            headers: _headers,
            body: json.encode({
              'medicineBoxId': boxId,
              'reminderId': reminderId,
              'userId': _userId,
            }),
          );

          print('📥 Response status: ${response.statusCode}');
          if (response.statusCode == 200) {
            print('✅ Reminder marked as missed successfully');
            return;
          }
        }
        print(
          '⚠️ Could not parse generated ID, trying standard endpoint anyway',
        );
      }

      // Standard approach for real DB records
      final response = await http.post(
        Uri.parse('$_baseUrl/updateRecord'),
        headers: _headers,
        body: json.encode({'recordId': recordId, 'status': 'missed'}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark record as missed');
      }

      print('✅ Record marked as missed successfully');
    } catch (e) {
      print('❌ Error marking record as missed: $e');
      rethrow;
    }
  }

  Future<void> autoCompleteRecordFromDevice(
    String deviceId,
    int boxNumber,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/autoCompleteRecord'),
        headers: _headers,
        body: json.encode({'deviceId': deviceId, 'boxNumber': boxNumber}),
      );

      if (response.statusCode != 200) {
        print('Failed to auto-complete record: ${response.body}');
      }
    } catch (e) {
      print('Error auto-completing record: $e');
    }
  }

  // ==================== BULK OPERATIONS ====================

  Future<void> deleteFutureRecordsForReminder(
    String medicineBoxId,
    String reminderId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/deleteFutureRecords'),
        headers: _headers,
        body: json.encode({
          'medicineBoxId': medicineBoxId,
          'reminderId': reminderId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete future records');
      }
    } catch (e) {
      print('Error deleting future records: $e');
      rethrow;
    }
  }

  Future<void> generateRecordsForReminder(
    MedicineBox box,
    ReminderTime reminder,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generateRecords'),
        headers: _headers,
        body: json.encode({
          'medicineBoxId': box.id,
          'boxNumber': box.boxNumber,
          'medicineName': box.name,
          'medicineType': box.medicineType,
          'deviceId': box.deviceId,
          'reminder': {
            'id': reminder.id,
            'hour': reminder.hour,
            'minute': reminder.minute,
            'daysOfWeek': reminder.daysOfWeek,
            'isEnabled': reminder.isEnabled,
          },
          'userId': _userId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate records');
      }
    } catch (e) {
      print('Error generating records: $e');
      rethrow;
    }
  }

  // Alias method for backward compatibility
  Future<void> generateRecordsForBox(MedicineBox box) async {
    for (var reminder in box.reminders) {
      await generateRecordsForReminder(box, reminder);
    }
  }

  // ==================== DEVICE MANAGEMENT ====================

  Future<void> saveDeviceToFirestore(
    String deviceId,
    String ip,
    String name,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/saveDevice'),
        headers: _headers,
        body: json.encode({
          'deviceId': deviceId,
          'ip': ip,
          'name': name,
          'userId': _userId, // Add current user ID
          'lastSeen': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save device: ${response.body}');
      }
    } catch (e) {
      print('Error saving device: $e');
      rethrow;
    }
  }

  /// Get devices for current user only
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/getUserDevices'),
        headers: _headers,
        body: json.encode({'userId': _userId}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error fetching user devices: $e');
    }
    return [];
  }

  Future<String?> getDeviceIp(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/getDevice'),
        headers: _headers,
        body: json.encode({'deviceId': deviceId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ip'] as String?;
      }
    } catch (e) {
      print('Error fetching device IP: $e');
    }
    return null;
  }

  /// Direct reminder update methods for when generating doses from reminders
  Future<void> markReminderAsTaken(
    String medicineBoxId,
    String reminderId,
  ) async {
    try {
      print('📤 Marking reminder $reminderId in box $medicineBoxId as taken');

      // Try to find and update the box reminder
      final response = await http.post(
        Uri.parse('$_baseUrl/updateMedicineBoxReminder'),
        headers: _headers,
        body: json.encode({
          'medicineBoxId': medicineBoxId,
          'reminderId': reminderId,
          'status': 'completed',
          'takenTime': DateTime.now().toIso8601String(),
          'userId': _userId,
        }),
      );

      print('📥 Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ Reminder marked as taken successfully');
      }
    } catch (e) {
      print('❌ Error marking reminder as taken: $e');
    }
  }

  Future<void> markReminderAsMissed(
    String medicineBoxId,
    String reminderId,
  ) async {
    try {
      print('📤 Marking reminder $reminderId in box $medicineBoxId as missed');

      final response = await http.post(
        Uri.parse('$_baseUrl/updateMedicineBoxReminder'),
        headers: _headers,
        body: json.encode({
          'medicineBoxId': medicineBoxId,
          'reminderId': reminderId,
          'status': 'missed',
          'userId': _userId,
        }),
      );

      print('📥 Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ Reminder marked as missed successfully');
      }
    } catch (e) {
      print('❌ Error marking reminder as missed: $e');
    }
  }
}
