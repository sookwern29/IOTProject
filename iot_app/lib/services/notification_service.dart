import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';
import '../models/dose_record.dart';
import '../models/medicine_box.dart';
import 'device_service.dart';
import 'mongodb_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final DeviceService _deviceService = DeviceService();
  final MongoDBService _mongoDBService = MongoDBService();
  
  Timer? _notificationCheckTimer;
  final Map<String, DateTime> _lastNotificationTime = {};
  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone
    tz.initializeTimeZones();
    
    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Request permissions
    await _requestPermissions();
    
    _isInitialized = true;
    
    // Start periodic check for overdue doses (every minute)
    startNotificationMonitoring();
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
    
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // You can navigate to specific page when notification is tapped
    print('Notification tapped: ${response.payload}');
  }

  /// Start monitoring for overdue doses
  void startNotificationMonitoring() {
    // Cancel existing timer if any
    _notificationCheckTimer?.cancel();
    
    // Check every minute for overdue doses
    _notificationCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkAndSendNotifications().catchError((e) {
        print('Error in notification check: $e');
      });
    });
    
    // Also check after 5 seconds (give app time to initialize)
    Future.delayed(Duration(seconds: 5), () {
      _checkAndSendNotifications().catchError((e) {
        print('Error in initial notification check: $e');
      });
    });
  }

  /// Stop monitoring
  void stopNotificationMonitoring() {
    _notificationCheckTimer?.cancel();
  }

  /// Check and send notifications for overdue doses
  /// Always reads from medicineBox (source of truth), so updated reminders are automatically used
  Future<void> _checkAndSendNotifications() async {
    try {
      final now = DateTime.now();
      final currentWeekday = now.weekday % 7; // Convert to 0=Sunday, 1=Monday, etc.
      
      // Get all active medicine boxes from MongoDB
      final boxes = await _mongoDBService.getMedicineBoxesList();
      
      print('Checking ${boxes.length} medicine boxes for notifications');
      
      // Group doses by scheduled time for combined notifications
      final Map<String, List<_DoseInfo>> dosesByTime = {};
      
      for (var box in boxes) {
        for (var reminder in box.reminders) {
          // Skip disabled reminders
          if (!reminder.isEnabled) continue;
          
          // Check if reminder is scheduled for today
          if (!reminder.daysOfWeek.contains(currentWeekday)) continue;
          
          // Create scheduled time for today
          final scheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            reminder.hour,
            reminder.minute,
          );
          
          // Skip future doses
          if (scheduledTime.isAfter(now)) continue;
          
          // Create a unique key for this reminder (box + time)
          final reminderKey = '${box.id}_${reminder.id}';
          
          // Skip if reminder status is already completed
          if (reminder.status?.toLowerCase() == 'completed') {
            // Clear notification tracking for completed reminders
            _lastNotificationTime.remove(reminderKey);
            continue;
          }
          
          // Check if dose is already taken/missed in MongoDB
          final records = await _mongoDBService.getRecords(deviceId: box.deviceId);
          final matchingRecord = records.where((r) => 
            r.medicineBoxId == box.id &&
            r.scheduledTime.year == scheduledTime.year &&
            r.scheduledTime.month == scheduledTime.month &&
            r.scheduledTime.day == scheduledTime.day &&
            r.scheduledTime.hour == scheduledTime.hour &&
            r.scheduledTime.minute == scheduledTime.minute
          ).firstOrNull;
          
          // If record exists and is completed/missed, skip notification
          if (matchingRecord != null && 
              (matchingRecord.status == 'completed' || matchingRecord.status == 'missed')) {
            // Clear notification tracking for completed/missed doses
            _lastNotificationTime.remove(reminderKey);
            continue;
          }
          
          // Check if dose is overdue and should notify
          final timeSinceScheduled = now.difference(scheduledTime);
          final isPrescription = box.medicineType.toLowerCase() == 'prescription';
          final recordEndOfDay = DateTime(scheduledTime.year, scheduledTime.month, scheduledTime.day, 23, 59, 59);
          
          bool shouldNotify = false;
          
          // Check notification timing rules
          if (isPrescription) {
            // Prescription: notify for 1 hour (60 minutes)
            if (timeSinceScheduled.inMinutes <= 60) {
              shouldNotify = _shouldSendNotification(reminderKey, scheduledTime, timeSinceScheduled);
            }
          } else {
            // Supplement: notify until end of day
            if (now.isBefore(recordEndOfDay)) {
              shouldNotify = _shouldSendNotification(reminderKey, scheduledTime, timeSinceScheduled);
            }
          }
          
          if (shouldNotify) {
            final timeKey = '${scheduledTime.hour}:${scheduledTime.minute}';
            final doseInfo = _DoseInfo(
              boxId: box.id,
              boxNumber: box.boxNumber,
              medicineName: box.name,
              medicineType: box.medicineType,
              scheduledTime: scheduledTime,
              reminderKey: reminderKey,
            );
            
            dosesByTime.putIfAbsent(timeKey, () => []).add(doseInfo);
            print('Added reminder for ${box.name} (Box ${box.boxNumber}) at $timeKey');
          }
        }
      }
      
      // Send combined notifications
      for (var entry in dosesByTime.entries) {
        print('Sending notification for ${entry.value.length} dose(s) at ${entry.key}');
        await _sendCombinedNotification(entry.value);
      }
      
    } catch (e) {
      print('Error checking notifications: $e');
    }
  }

  /// Check if notification should be sent (at scheduled time, then every 10 minutes)
  bool _shouldSendNotification(String reminderKey, DateTime scheduledTime, Duration timeSince) {
    final now = DateTime.now();
    
    // Send at scheduled time (within 1 minute window)
    if (timeSince.inMinutes == 0) {
      _lastNotificationTime[reminderKey] = now;
      return true;
    }
    
    // Check if 10 minutes passed since last notification
    final lastSent = _lastNotificationTime[reminderKey];
    if (lastSent == null) {
      // First notification (if we missed the scheduled time)
      _lastNotificationTime[reminderKey] = now;
      return true;
    }
    
    final timeSinceLastNotification = now.difference(lastSent);
    if (timeSinceLastNotification.inMinutes >= 10) {
      _lastNotificationTime[reminderKey] = now;
      return true;
    }
    
    return false;
  }

  /// Send combined notification for multiple doses
  Future<void> _sendCombinedNotification(List<_DoseInfo> doses) async {
    if (doses.isEmpty) return;
    
    String title;
    String body;
    
    if (doses.length == 1) {
      final dose = doses.first;
      title = '💊 Time to take your medicine!';
      body = '${dose.medicineName} (Box ${dose.boxNumber}) - ${dose.medicineType}';
    } else {
      title = '💊 Time to take ${doses.length} medicines!';
      body = doses.map((d) => '${d.medicineName} (Box ${d.boxNumber})').join(', ');
    }
    
    const androidDetails = AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine doses',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Use time-based notification ID (so combined notifications replace each other)
    final notificationId = doses.first.scheduledTime.millisecondsSinceEpoch ~/ 60000;
    
    await _notifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: doses.map((d) => d.reminderKey).join(','),
    );
    
    // 💡 Light up LED for each medicine box when notification is sent
    print('💡 Lighting up LEDs for ${doses.length} reminder(s)');
    for (var dose in doses) {
      try {
        // Get medicine box to find deviceId
        final box = await _mongoDBService.getMedicineBox(dose.boxId);
        if (box != null) {
          print('💡 Blinking LED for Box ${dose.boxNumber} (Device: ${box.deviceId})');
          // Blink LED for 7 minutes (420 blinks = 420 seconds) when reminder notification is sent
          await _deviceService.blinkBoxLED(box.deviceId, dose.boxNumber, times: 420);
        }
      } catch (e) {
        print('❌ Error lighting up box ${dose.boxNumber}: $e');
        // Don't fail notification if LED fails
      }
    }
  }

  /// Cancel notification for a specific dose (when marked as taken/missed)
  Future<void> cancelNotification(String recordId) async {
    _lastNotificationTime.remove(recordId);
    final notificationId = recordId.hashCode;
    await _notifications.cancel(notificationId);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    _lastNotificationTime.clear();
    await _notifications.cancelAll();
  }

  /// Schedule a one-time notification for a specific dose
  Future<void> scheduleNotification(MedicineRecord record) async {
    if (record.scheduledTime.isBefore(DateTime.now())) {
      return; // Don't schedule past notifications
    }
    
    final scheduledDate = tz.TZDateTime.from(record.scheduledTime, tz.local);
    
    const androidDetails = AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine doses',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.zonedSchedule(
      record.id.hashCode,
      '💊 Time to take your medicine!',
      '${record.medicineName} (Box ${record.boxNumber})',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Dispose resources
  void dispose() {
    stopNotificationMonitoring();
  }
}

/// Helper class to hold dose information from medicineBox
class _DoseInfo {
  final String boxId;
  final int boxNumber;
  final String medicineName;
  final String medicineType;
  final DateTime scheduledTime;
  final String reminderKey;

  _DoseInfo({
    required this.boxId,
    required this.boxNumber,
    required this.medicineName,
    required this.medicineType,
    required this.scheduledTime,
    required this.reminderKey,
  });
}
