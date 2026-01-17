import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/dose_record.dart';
import '../services/mongodb_service.dart';
import '../services/device_service.dart';

class TodayDosesPage extends StatefulWidget {
  @override
  _TodayDosesPageState createState() => _TodayDosesPageState();
}

class _TodayDosesPageState extends State<TodayDosesPage> {
  final MongoDBService _mongoDBService = MongoDBService();
  final DeviceService _deviceService = DeviceService();

  @override
  void initState() {
    super.initState();
    // Update all reminder statuses when page loads
    _updateReminderStatuses();
  }

  Future<void> _updateReminderStatuses() async {
    try {
      await _mongoDBService.updateAllReminderStatuses();
    } catch (e) {
      print('Error updating reminder statuses: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Today\'s Doses'),
      ),
      body: StreamBuilder<List<MedicineRecord>>(
        stream: _mongoDBService.getTodayDosesFromBoxes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication, size: 100, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No doses scheduled for today',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final records = snapshot.data!;
          final now = DateTime.now();
          final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

          // Categorize doses with overdue logic
          final upcoming = <MedicineRecord>[];
          final overdue = <MedicineRecord>[];
          final completed = <MedicineRecord>[];
          final missed = <MedicineRecord>[];

          for (var record in records) {
            if (record.isTaken) {
              completed.add(record);
            } else if (record.isMissed) {
              missed.add(record);
            } else if (record.scheduledTime.isAfter(now)) {
              upcoming.add(record);
            } else {
              // Past scheduled time and not taken
              final timeSinceScheduled = now.difference(record.scheduledTime);
              final isPrescription = record.medicineType.toLowerCase() == 'prescription';
              
              if (isPrescription) {
                // Prescription: overdue within 1 hour, missed after 1 hour
                if (timeSinceScheduled.inMinutes <= 60) {
                  overdue.add(record);
                } else {
                  missed.add(record);
                }
              } else {
                // Supplement: overdue until end of day, missed after that
                if (now.isBefore(endOfDay)) {
                  overdue.add(record);
                } else {
                  missed.add(record);
                }
              }
            }
          }

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              _buildStatsCard(records, overdue.length),
              SizedBox(height: 20),
              if (overdue.isNotEmpty) ...[
                _buildSectionHeader('Overdue', Color(0xFFFF6F00)),
                ...overdue.map((record) => _buildDoseCard(record, isOverdue: true)),
                SizedBox(height: 20),
              ],
              if (upcoming.isNotEmpty) ...[
                _buildSectionHeader('Upcoming', Color(0xFF1976D2)),
                ...upcoming.map((record) => _buildDoseCard(record)),
                SizedBox(height: 20),
              ],
              if (completed.isNotEmpty) ...[
                _buildSectionHeader('Completed', Color(0xFF66BB6A)),
                ...completed.map((record) => _buildDoseCard(record, isCompleted: true)),
                SizedBox(height: 20),
              ],
              if (missed.isNotEmpty) ...[
                _buildSectionHeader('Missed', Color(0xFFE53935)),
                ...missed.map((record) => _buildDoseCard(record, isMissed: true)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(List<MedicineRecord> records, int overdueCount) {
    int total = records.length;
    int taken = records.where((r) => r.isTaken).length;
    int missed = records.where((r) => r.isMissed).length;

    double progress = total > 0 ? taken / total : 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Today\'s Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
              minHeight: 10,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', total.toString(), Theme.of(context).colorScheme.primary),
                _buildStatItem('Taken', taken.toString(), Theme.of(context).colorScheme.tertiary),
                _buildStatItem('Overdue', overdueCount.toString(), Color(0xFFFF6F00)),
                _buildStatItem('Missed', missed.toString(), Color(0xFFE53935)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            color: color,
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(MedicineRecord record, {bool isCompleted = false, bool isMissed = false, bool isOverdue = false}) {
    final timeFormat = DateFormat('hh:mm a');
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isCompleted
              ? Color(0xFF66BB6A)
              : isOverdue
                  ? Color(0xFFFF6F00)
                  : isMissed
                      ? Color(0xFFE53935)
                      : Color(0xFF1976D2),
          child: Icon(
            isCompleted ? Icons.check : (isMissed || isOverdue) ? Icons.lightbulb_outline : Icons.medication,
            color: Colors.white,
          ),
        ),
        title: Text(
          '${record.medicineName} (Box ${record.boxNumber})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            decoration: isCompleted || isMissed ? TextDecoration.lineThrough : null,
            color: isMissed ? Colors.grey : isOverdue ? Color(0xFFFF6F00) : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'Type: ${record.medicineType} • ${timeFormat.format(record.scheduledTime)}',
              style: TextStyle(fontSize: 13),
            ),
            if (record.takenTime != null)
              Text(
                'Taken: ${timeFormat.format(record.takenTime!)}',
                style: TextStyle(fontSize: 12, color: Color(0xFF66BB6A)),
              ),
          ],
        ),
        trailing: isOverdue
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.lightbulb, color: Color(0xFFFF6F00), size: 28),
                    onPressed: () => _lightUpBox(record.boxNumber),
                    tooltip: 'Light up box ${record.boxNumber}',
                  ),
                  IconButton(
                    icon: Icon(Icons.check_circle, color: Color(0xFF66BB6A)),
                    onPressed: () => _markAsTaken(record),
                  ),
                  // IconButton(
                  //   icon: Icon(Icons.cancel, color: Color(0xFFE53935)),
                  //   onPressed: () => _markAsMissed(record.id),
                  // ),
                ],
              )
            : !isCompleted && !isMissed
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check_circle, color: Color(0xFF66BB6A)),
                        onPressed: () => _markAsTaken(record),
                      ),
                      // IconButton(
                      //   icon: Icon(Icons.cancel, color: Color(0xFFE53935)),
                      //   onPressed: () => _markAsMissed(record.id),
                      // ),
                    ],
                  )
                : Icon(
                    isCompleted ? Icons.check_circle : Icons.close,
                    color: isCompleted ? Color(0xFF66BB6A) : Color(0xFFE53935),
                    size: 28,
                  ),
      ),
    );
  }

  Future<void> _markAsTaken(MedicineRecord record) async {
    try {
      await _mongoDBService.markRecordAsTaken(record.id);
      
      // Update reminder statuses after marking as taken
      await _updateReminderStatuses();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dose marked as taken!'), backgroundColor: Color(0xFF66BB6A)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Color(0xFFE53935)),
      );
    }
  }

  Future<void> _markAsMissed(MedicineRecord record) async {
    try {
      await _mongoDBService.markRecordAsMissed(record.id);
      
      // Update reminder statuses after marking as missed
      await _updateReminderStatuses();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dose marked as missed'), backgroundColor: Color(0xFFFF9800)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Color(0xFFE53935)),
      );
    }
  }

  Future<void> _lightUpBox(int boxNumber) async {
    try {
      // Get the medicine box to find deviceId
      final box = await _mongoDBService.getMedicineBoxByNumber(boxNumber);
      
      if (box == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not find medicine box $boxNumber'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
        return;
      }
      
      // Blink the LED 10 times (10 seconds)
      await _deviceService.blinkBoxLED(box.deviceId, boxNumber, times: 10);

    } catch (e) {
      String errorMessage = 'Error: $e';
      
      // Provide helpful error messages
      if (e.toString().contains('Device IP not found')) {
        errorMessage = 'Device not configured. Please set up your medicine box IP address.';
      } else if (e.toString().contains('TimeoutException') || 
                 e.toString().contains('timed out')) {
        errorMessage = 'Device not responding. Check if it\'s powered on and connected to WiFi.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Color(0xFFE53935),
        ),
      );
    }
  }
}
