import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_box.dart';
import '../models/dose_record.dart';
import 'notification_service.dart';

/// Firestore Service for Medicine Box App
/// 
/// Data Flow:
/// 1. medicineBox collection: Stores current medicine box configurations and reminders
/// 2. medicineRecords collection: Stores all scheduled doses with complete box info
///    - Records persist even after box/reminder deletion (for dashboard/history)
///    - Each record includes: boxId, boxNumber, medicineName, medicineType, deviceId, etc.
///    - Generated 30 days ahead when box/reminder is created
///    - Regenerated when reminder is edited
///    - Future records deleted when reminder is removed (past records remain)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId = 'user123'; // In production, get from Firebase Auth
  final NotificationService _notificationService = NotificationService();

  // Medicine Box CRUD operations
  Future<void> addMedicineBox(MedicineBox box) async {
    await _db.collection('medicineBox').doc(box.id).set(box.toFirestore());
  }

  Future<void> updateMedicineBox(MedicineBox box) async {
    await _db.collection('medicineBox').doc(box.id).update(box.toFirestore());
  }

  Future<void> deleteMedicineBox(String boxId) async {
    await _db.collection('medicineBox').doc(boxId).delete();
  }

  Stream<List<MedicineBox>> getMedicineBoxes() {
    return _db
        .collection('medicineBox')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MedicineBox.fromFirestore(doc)).toList());
  }

  Future<MedicineBox?> getMedicineBox(String boxId) async {
    final doc = await _db.collection('medicineBox').doc(boxId).get();
    if (doc.exists) {
      return MedicineBox.fromFirestore(doc);
    }
    return null;
  }

  Future<MedicineBox?> getMedicineBoxByBoxNumber(int boxNumber) async {
    final snapshot = await _db
        .collection('medicineBox')
        .where('boxNumber', isEqualTo: boxNumber)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return MedicineBox.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  /// Update reminder status in Firestore
  Future<void> updateReminderStatus(String boxId, String reminderId, String newStatus) async {
    try {
      // Get the medicine box
      final boxDoc = await _db.collection('medicineBox').doc(boxId).get();
      if (!boxDoc.exists) return;

      final box = MedicineBox.fromFirestore(boxDoc);
      
      // Find and update the reminder
      final updatedReminders = box.reminders.map((reminder) {
        if (reminder.id == reminderId) {
          return ReminderTime(
            id: reminder.id,
            hour: reminder.hour,
            minute: reminder.minute,
            isEnabled: reminder.isEnabled,
            daysOfWeek: reminder.daysOfWeek,
            status: newStatus,
          );
        }
        return reminder;
      }).toList();

      // Create updated box with new reminders
      final updatedBox = MedicineBox(
        id: box.id,
        name: box.name,
        boxNumber: box.boxNumber,
        deviceId: box.deviceId,
        medicineType: box.medicineType,
        isConnected: box.isConnected,
        lastUpdated: DateTime.now(),
        reminders: updatedReminders,
        compartments: box.compartments,
      );

      // Save to Firestore
      await updateMedicineBox(updatedBox);
    } catch (e) {
      print('Error updating reminder status: $e');
    }
  }

  /// Update all reminder statuses based on current time
  /// Note: 'completed' status is ONLY set when user marks dose as taken
  /// This method only sets: upcoming, overdue, or missed
  Future<void> updateAllReminderStatuses() async {
    try {
      final snapshot = await _db.collection('medicineBox').get();
      final now = DateTime.now();
      final currentDayOfWeek = now.weekday % 7; // 0=Sunday
      final today = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      for (var doc in snapshot.docs) {
        final box = MedicineBox.fromFirestore(doc);
        bool needsUpdate = false;
        
        final updatedReminders = await Future.wait(box.reminders.map((reminder) async {
          if (!reminder.isEnabled) {
            return reminder;
          }

          final scheduledTime = DateTime(
            today.year,
            today.month,
            today.day,
            reminder.hour,
            reminder.minute,
          );

          // Check if user has already marked ANY dose for this reminder today as taken
          final todayRecordsSnapshot = await _db
              .collection('medicineRecords')
              .where('medicineBoxId', isEqualTo: box.id)
              .where('reminderTimeId', isEqualTo: reminder.id)
              .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
              .where('scheduledTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
              .get();

          // Check if ANY record for today is taken
          final hasTakenToday = todayRecordsSnapshot.docs.any((doc) {
            final record = MedicineRecord.fromFirestore(doc);
            return record.isTaken;
          });

          // If marked as taken, set status as completed
          if (hasTakenToday) {
            if (reminder.status != 'completed') {
              needsUpdate = true;
              return ReminderTime(
                id: reminder.id,
                hour: reminder.hour,
                minute: reminder.minute,
                isEnabled: reminder.isEnabled,
                daysOfWeek: reminder.daysOfWeek,
                status: 'completed',
              );
            }
            return reminder;
          }

          String newStatus;
          final isPrescription = box.medicineType.toLowerCase() == 'prescription';
          final isSupplement = box.medicineType.toLowerCase() == 'supplement';

          // Check if reminder is scheduled for today
          if (reminder.daysOfWeek.contains(currentDayOfWeek)) {
            if (now.isBefore(scheduledTime)) {
              // Before scheduled time - upcoming
              newStatus = 'upcoming';
            } else {
              // After scheduled time
              if (isPrescription) {
                // Prescription: overdue within 1 hour, missed after 1 hour
                final timeSinceScheduled = now.difference(scheduledTime);
                if (timeSinceScheduled.inMinutes <= 60) {
                  newStatus = 'overdue';
                } else {
                  newStatus = 'missed';
                }
              } else if (isSupplement) {
                // Supplement: overdue whole day, missed when next day
                if (now.isBefore(endOfDay)) {
                  newStatus = 'overdue';
                } else {
                  newStatus = 'missed';
                }
              } else {
                // Default behavior for other types (treat like prescription)
                final timeSinceScheduled = now.difference(scheduledTime);
                if (timeSinceScheduled.inMinutes <= 60) {
                  newStatus = 'overdue';
                } else {
                  newStatus = 'missed';
                }
              }
            }
          } else {
            // Not scheduled for today - upcoming
            newStatus = 'upcoming';
          }

          // Only update if status changed and not already completed
          if (reminder.status != newStatus && reminder.status != 'completed') {
            needsUpdate = true;
            
            // Update ALL medicineRecords for this reminder (not just today)
            final allRecordsSnapshot = await _db
                .collection('medicineRecords')
                .where('medicineBoxId', isEqualTo: box.id)
                .where('reminderTimeId', isEqualTo: reminder.id)
                .where('status', whereIn: ['upcoming', 'overdue']) // Only update if not completed/missed
                .get();
            
            final isPrescription = box.medicineType.toLowerCase() == 'prescription';
            final isSupplement = box.medicineType.toLowerCase() == 'supplement';
            
            // Update each record based on its own scheduledTime
            for (var recordDoc in allRecordsSnapshot.docs) {
              final record = MedicineRecord.fromFirestore(recordDoc);
              final recordScheduledTime = record.scheduledTime;
              final recordDayOfWeek = recordScheduledTime.weekday % 7;
              final recordDate = DateTime(recordScheduledTime.year, recordScheduledTime.month, recordScheduledTime.day);
              final recordEndOfDay = DateTime(recordDate.year, recordDate.month, recordDate.day, 23, 59, 59);
              
              String recordStatus;
              
              // Check if this record is scheduled for a day the reminder is enabled
              if (reminder.daysOfWeek.contains(recordDayOfWeek)) {
                if (now.isBefore(recordScheduledTime)) {
                  // Future record - upcoming
                  recordStatus = 'upcoming';
                } else {
                  // Past record - calculate overdue or missed
                  if (isPrescription) {
                    final timeSinceScheduled = now.difference(recordScheduledTime);
                    if (timeSinceScheduled.inMinutes <= 60) {
                      recordStatus = 'overdue';
                    } else {
                      recordStatus = 'missed';
                    }
                  } else if (isSupplement) {
                    if (now.isBefore(recordEndOfDay)) {
                      recordStatus = 'overdue';
                    } else {
                      recordStatus = 'missed';
                    }
                  } else {
                    // Default behavior
                    final timeSinceScheduled = now.difference(recordScheduledTime);
                    if (timeSinceScheduled.inMinutes <= 60) {
                      recordStatus = 'overdue';
                    } else {
                      recordStatus = 'missed';
                    }
                  }
                }
              } else {
                // Not scheduled for this day
                recordStatus = 'upcoming';
              }
              
              // Only update if status changed
              if (record.status != recordStatus) {
                await recordDoc.reference.update({'status': recordStatus});
              }
            }
            
            return ReminderTime(
              id: reminder.id,
              hour: reminder.hour,
              minute: reminder.minute,
              isEnabled: reminder.isEnabled,
              daysOfWeek: reminder.daysOfWeek,
              status: newStatus,
            );
          }
          return reminder;
        }));

        // Only update Firestore if something changed
        if (needsUpdate) {
          final updatedBox = MedicineBox(
            id: box.id,
            name: box.name,
            boxNumber: box.boxNumber,
            deviceId: box.deviceId,
            medicineType: box.medicineType,
            isConnected: box.isConnected,
            lastUpdated: DateTime.now(),
            reminders: updatedReminders,
            compartments: box.compartments,
          );

          await _db.collection('medicineBox').doc(box.id).update(updatedBox.toFirestore());
        }
      }
    } catch (e) {
      print('Error updating all reminder statuses: $e');
    }
  }

  // Medicine Record operations
  Future<void> addMedicineRecord(MedicineRecord record) async {
    await _db.collection('medicineRecords').doc(record.id).set(record.toFirestore());
  }

  Future<void> updateMedicineRecord(MedicineRecord record) async {
    await _db
        .collection('medicineRecords')
        .doc(record.id)
        .update(record.toFirestore());
  }

  Future<void> markRecordAsTaken(String recordId) async {
    // Update the record
    await _db
        .collection('medicineRecords')
        .doc(recordId)
        .update({
      'status': 'completed',
      'takenTime': Timestamp.now(),
    });
    
    // Cancel notification for this dose
    await _notificationService.cancelNotification(recordId);
    
    // Get the record to update corresponding reminder status
    final recordDoc = await _db.collection('medicineRecords').doc(recordId).get();
    if (recordDoc.exists) {
      final record = MedicineRecord.fromFirestore(recordDoc);
      // Update reminder status to 'completed'
      await updateReminderStatus(record.medicineBoxId, record.reminderTimeId, 'completed');
    }
  }

  Future<void> markRecordAsMissed(String recordId) async {
    // Update the record
    await _db
        .collection('medicineRecords')
        .doc(recordId)
        .update({
      'status': 'missed',
    });
    
    // Cancel notification for this dose
    await _notificationService.cancelNotification(recordId);
    
    // Get the record to update corresponding reminder status
    final recordDoc = await _db.collection('medicineRecords').doc(recordId).get();
    if (recordDoc.exists) {
      final record = MedicineRecord.fromFirestore(recordDoc);
      // Update reminder status to 'missed'
      await updateReminderStatus(record.medicineBoxId, record.reminderTimeId, 'missed');
    }
  }

  Stream<List<MedicineRecord>> getTodayRecords() {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));

    return _db
        .collection('medicineRecords')
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('scheduledTime')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MedicineRecord.fromFirestore(doc)).toList());
  }

  // Get today's doses from medicineBox reminders (real-time check)
  Stream<List<MedicineRecord>> getTodayDosesFromBoxes() {
    return getMedicineBoxes().asyncMap((boxes) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentDayOfWeek = now.weekday % 7; // Convert to 0-6 (Sunday=0)
      
      List<MedicineRecord> todayRecords = [];

      for (var box in boxes) {
        for (var reminder in box.reminders) {
          // Check if reminder is enabled and scheduled for today
          if (reminder.isEnabled && reminder.daysOfWeek.contains(currentDayOfWeek)) {
            final scheduledTime = DateTime(
              today.year,
              today.month,
              today.day,
              reminder.hour,
              reminder.minute,
            );

            final recordId = 'temp_${box.id}_${reminder.id}_${scheduledTime.millisecondsSinceEpoch}';

            // Check if a record already exists in database for this exact time
            final existingRecords = await _db
                .collection('medicineRecords')
                .where('medicineBoxId', isEqualTo: box.id)
                .where('reminderTimeId', isEqualTo: reminder.id)
                .where('scheduledTime', isEqualTo: Timestamp.fromDate(scheduledTime))
                .limit(1)
                .get();

            MedicineRecord record;
            if (existingRecords.docs.isNotEmpty) {
              // Use existing record (with taken/missed status)
              record = MedicineRecord.fromFirestore(existingRecords.docs.first);
            } else {
              // Create new record for display and save to database
              record = MedicineRecord(
                id: recordId,
                medicineBoxId: box.id,
                medicineName: box.name,
                boxNumber: box.boxNumber,
                medicineType: box.medicineType,
                deviceId: box.deviceId,
                reminderTimeId: reminder.id,
                reminderHour: reminder.hour,
                reminderMinute: reminder.minute,
                scheduledTime: scheduledTime,
              );
              
              // Save to database for tracking
              await addMedicineRecord(record);
            }

            todayRecords.add(record);
          }
        }
      }

      // Sort by scheduled time
      todayRecords.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      return todayRecords;
    });
  }

  Stream<List<MedicineRecord>> getRecordsInRange(DateTime start, DateTime end) {
    return _db
        .collection('medicineRecords')
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MedicineRecord.fromFirestore(doc)).toList());
  }

  // Generate medicine records for a reminder
  Future<void> generateRecordsForReminder(
    MedicineBox box,
    ReminderTime reminder,
    {int daysAhead = 30}
  ) async {
    DateTime now = DateTime.now();
    DateTime endDate = now.add(Duration(days: daysAhead));

    for (DateTime date = now;
        date.isBefore(endDate);
        date = date.add(Duration(days: 1))) {
      
      // Check if this day of week is enabled for this reminder
      int dayOfWeek = date.weekday % 7; // Convert to 0-6 (Sunday=0)
      
      if (reminder.daysOfWeek.contains(dayOfWeek)) {
        final scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          reminder.hour,
          reminder.minute,
        );

        if (scheduledTime.isAfter(now)) {
          final recordId = 'record_${box.id}_${reminder.id}_${scheduledTime.millisecondsSinceEpoch}';
          
          final record = MedicineRecord(
            id: recordId,
            medicineBoxId: box.id,
            medicineName: box.name,
            boxNumber: box.boxNumber,
            medicineType: box.medicineType,
            deviceId: box.deviceId,
            reminderTimeId: reminder.id,
            reminderHour: reminder.hour,
            reminderMinute: reminder.minute,
            scheduledTime: scheduledTime,
          );
          
          await addMedicineRecord(record);
        }
      }
    }
  }

  // Generate records for all reminders in a box
  Future<void> generateRecordsForBox(MedicineBox box, {int daysAhead = 30}) async {
    for (var reminder in box.reminders) {
      if (reminder.isEnabled) {
        await generateRecordsForReminder(box, reminder, daysAhead: daysAhead);
      }
    }
  }

  // Delete future records for a specific reminder (when reminder is deleted/edited)
  Future<void> deleteFutureRecordsForReminder(String boxId, String reminderId) async {
    final now = DateTime.now();
    
    // Simplified query - fetch all records for this reminder and filter in memory
    final snapshot = await _db
        .collection('medicineRecords')
        .where('medicineBoxId', isEqualTo: boxId)
        .where('reminderTimeId', isEqualTo: reminderId)
        .get();

    // Filter and delete only future untaken records
    for (var doc in snapshot.docs) {
      final record = MedicineRecord.fromFirestore(doc);
      if (record.scheduledTime.isAfter(now) && !record.isTaken) {
        await doc.reference.delete();
      }
    }
  }

  // Calculate adherence statistics
  Future<Map<String, dynamic>> getAdherenceStats(DateTime start, DateTime end) async {
    final now = DateTime.now();
    
    final snapshot = await _db
        .collection('medicineRecords')
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .get();

    int total = 0;
    int taken = 0;
    int missed = 0;
    int overdue = 0;

    for (var doc in snapshot.docs) {
      final record = MedicineRecord.fromFirestore(doc);
      
      // Only count records that have already occurred (not future ones)
      if (record.scheduledTime.isBefore(now) || record.scheduledTime.day == now.day) {
        total++;
        
        switch (record.status) {
          case 'completed':
            taken++;
            break;
          case 'missed':
            missed++;
            break;
          case 'upcoming':
          default:
            // Count as overdue if time has passed but not marked
            if (DateTime.now().isAfter(record.scheduledTime)) {
              overdue++;
            }
            break;
        }
      }
    }

    double adherenceRate = total > 0 ? (taken / total) * 100 : 0;

    return {
      'total': total,
      'taken': taken,
      'missed': missed,
      'skipped': overdue, // Use skipped for overdue to maintain compatibility
      'adherenceRate': adherenceRate,
    };
  }
  
  /// Save discovered device to Firestore devices collection
  /// Called from device_scanner_page when device is discovered
  Future<void> saveDeviceToFirestore(String deviceId, String ip, String name) async {
    try {
      await _db.collection('devices').doc(deviceId).set({
        'ip': ip,
        'name': name,
        'connectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('Saved device $deviceId ($ip) to Firestore devices collection');
    } catch (e) {
      print('Error saving device to Firestore: $e');
      rethrow;
    }
  }

  /// Auto-complete medicine record from IoT device (MQTT)
  /// Called when ESP32 reports medicine taken via MQTT
  Future<void> autoCompleteRecordFromIoT(String medicineBoxId, int boxNumber) async {
    try {
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║   🔍 AUTO-COMPLETE RECORD FROM IOT STARTED                ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('📦 Medicine Box ID: $medicineBoxId');
      print('📦 Box Number: $boxNumber');
      print('⏰ Current Time: ${DateTime.now()}');
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      print('\n📅 Searching for records between:');
      print('   Start: $todayStart');
      print('   End: $todayEnd');
      
      // Simplified query to avoid complex composite index
      // Get all records for this medicine box today, filter in code
      print('\n🔍 Querying Firestore...');
      final snapshot = await _db
          .collection('medicineRecords')
          .where('medicineBoxId', isEqualTo: medicineBoxId)
          .where('scheduledTime', isGreaterThanOrEqualTo: todayStart)
          .where('scheduledTime', isLessThanOrEqualTo: todayEnd)
          .get();
      
      print('✅ Query complete! Found ${snapshot.docs.length} total records today');
      
      // Debug: Print all records found
      if (snapshot.docs.isEmpty) {
        print('\n⚠️ WARNING: No records found for this medicineBoxId today!');
        print('   Check if:');
        print('   1. medicineBoxId matches: $medicineBoxId');
        print('   2. Records exist in Firestore for today');
        print('   3. scheduledTime is within today\'s range');
        return;
      }
      
      print('\n📋 All records found today:');
      for (var doc in snapshot.docs) {
        final record = MedicineRecord.fromFirestore(doc);
        print('   - ID: ${record.id}');
        print('     Box#: ${record.boxNumber}, Medicine: ${record.medicineName}');
        print('     Scheduled: ${record.scheduledTime}');
        print('     Status: ${record.status}, Taken: ${record.isTaken}, Missed: ${record.isMissed}');
      }
      
      // Filter in code to find the right record
      print('\n🔍 Filtering for valid records (boxNumber=$boxNumber, not taken, not missed)...');
      final validRecords = snapshot.docs.where((doc) {
        final record = MedicineRecord.fromFirestore(doc);
        final isValid = record.boxNumber == boxNumber && 
               !record.isTaken && 
               !record.isMissed;
        if (isValid) {
          print('   ✅ Valid: ${record.id} (${record.medicineName})');
        } else {
          print('   ❌ Skipped: ${record.id} - boxNumber=${record.boxNumber}, taken=${record.isTaken}, missed=${record.isMissed}');
        }
        return isValid;
      }).toList();
      
      print('\n📊 Found ${validRecords.length} valid records to process');
      
      // Sort by scheduled time and get first
      validRecords.sort((a, b) {
        final recordA = MedicineRecord.fromFirestore(a);
        final recordB = MedicineRecord.fromFirestore(b);
        return recordA.scheduledTime.compareTo(recordB.scheduledTime);
      });
      
      if (validRecords.isEmpty) {
        print('\n⚠️ No pending record found for box $boxNumber');
        print('   Possible reasons:');
        print('   1. All records already marked as taken or missed');
        print('   2. No records scheduled for box $boxNumber today');
        print('   3. boxNumber mismatch (Arduino sent $boxNumber)');
        print('════════════════════════════════════════════════════════════\n');
        return;
      }
      
      final recordDoc = validRecords.first;
      final recordId = recordDoc.id;
      final record = MedicineRecord.fromFirestore(recordDoc);
      
      print('\n✅ Found record to complete!');
      print('   Record ID: $recordId');
      print('   Medicine: ${record.medicineName}');
      print('   Box Number: ${record.boxNumber}');
      print('   Scheduled: ${record.scheduledTime}');
      print('   Current Status: ${record.status}');
      
      // Mark as taken
      print('\n📝 Marking record as taken...');
      await markRecordAsTaken(recordId);
      print('✅ Record marked as taken in Firestore!');
      
      // Update reminder statuses to reflect the change
      print('\n🔄 Updating reminder statuses...');
      await updateAllReminderStatuses();
      print('✅ Reminder statuses updated!');
      
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║   ✅ RECORD AUTO-COMPLETED SUCCESSFULLY! ✅               ║');
      print('╚════════════════════════════════════════════════════════════╝\n');
    } catch (e, stackTrace) {
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║   ❌ ERROR AUTO-COMPLETING RECORD! ❌                     ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('Error: $e');
      print('Stack Trace:');
      print(stackTrace);
      print('════════════════════════════════════════════════════════════\n');
    }
  }
}

