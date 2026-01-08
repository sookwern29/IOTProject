import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mqtt_service.dart';
import '../services/firestore_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MqttTestPage extends StatefulWidget {
  @override
  _MqttTestPageState createState() => _MqttTestPageState();
}

class _MqttTestPageState extends State<MqttTestPage> {
  final MqttService _mqttService = MqttService();
  final FirestoreService _firestoreService = FirestoreService();
  
  List<String> _diagnosticLogs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _diagnosticLogs.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $message');
      if (_diagnosticLogs.length > 50) {
        _diagnosticLogs.removeLast();
      }
    });
  }

  Future<void> _runFullDiagnostic() async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
      _diagnosticLogs.clear();
    });

    _addLog('🔍 Starting MQTT Diagnostic...');
    _addLog('');

    // Step 1: Check Firestore Medicine Box
    _addLog('📋 STEP 1: Checking Firestore Medicine Box...');
    try {
      final boxes = await _firestoreService.getMedicineBoxes().first;
      if (boxes.isEmpty) {
        _addLog('❌ ERROR: No medicine boxes found in Firestore!');
        _addLog('   Solution: Add a medicine box in the app');
        setState(() => _isRunning = false);
        return;
      }

      final box = boxes.first;
      _addLog('✅ Found medicine box:');
      _addLog('   • Firestore ID: ${box.id}');
      _addLog('   • Device ID: ${box.deviceId}');
      _addLog('   • Box Name: ${box.boxName}');
      _addLog('');

      // Step 2: Check Device in Firestore
      _addLog('📋 STEP 2: Checking Device in Firestore...');
      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(box.deviceId)
          .get();

      if (!deviceDoc.exists) {
        _addLog('❌ ERROR: Device ${box.deviceId} not found!');
        setState(() => _isRunning = false);
        return;
      }

      final deviceData = deviceDoc.data();
      final deviceIp = deviceData?['ip'] as String?;
      _addLog('✅ Found device:');
      _addLog('   • Device ID: ${box.deviceId}');
      _addLog('   • IP Address: ${deviceIp ?? "NOT SET"}');
      _addLog('');

      if (deviceIp == null || deviceIp.isEmpty) {
        _addLog('❌ ERROR: Device has no IP address!');
        _addLog('   Solution: Make sure ESP32 is connected and registered');
        setState(() => _isRunning = false);
        return;
      }

      // Step 3: Check ESP32 Status
      _addLog('📋 STEP 3: Checking ESP32 Device...');
      try {
        final statusResponse = await http.get(
          Uri.parse('http://$deviceIp/status'),
        ).timeout(Duration(seconds: 5));

        if (statusResponse.statusCode == 200) {
          final statusData = jsonDecode(statusResponse.body);
          _addLog('✅ ESP32 is reachable:');
          _addLog('   • WiFi Connected: ${statusData['wifiConnected']}');
          _addLog('   • WiFi RSSI: ${statusData['rssi']} dBm');
          _addLog('   • Box ID: ${statusData['boxId']}');
          _addLog('   • Medicine Box ID: ${statusData['medicineBoxId']}');
          _addLog('   • MQTT Connected: ${statusData['mqttConnected']}');
          _addLog('');

          final esp32MedicineBoxId = statusData['medicineBoxId'] as String?;
          final firestoreMedicineBoxId = box.id;

          // Step 4: Compare IDs
          _addLog('📋 STEP 4: Comparing Medicine Box IDs...');
          _addLog('   • ESP32 medicineBoxId: "$esp32MedicineBoxId"');
          _addLog('   • Firestore Medicine Box ID: "$firestoreMedicineBoxId"');
          
          if (esp32MedicineBoxId == null || esp32MedicineBoxId.isEmpty) {
            _addLog('❌ ERROR: ESP32 medicineBoxId is not set!');
            _addLog('   Solution: Click "Fix ESP32 ID" button below');
            _addLog('');
          } else if (esp32MedicineBoxId != firestoreMedicineBoxId) {
            _addLog('❌ ERROR: Medicine Box IDs DO NOT MATCH!');
            _addLog('   This is why Flutter is not receiving messages!');
            _addLog('   ESP32 publishes to: medicinebox/$esp32MedicineBoxId/status');
            _addLog('   Flutter subscribes to: medicinebox/$firestoreMedicineBoxId/status');
            _addLog('   Solution: Click "Fix ESP32 ID" button below');
            _addLog('');
          } else {
            _addLog('✅ Medicine Box IDs MATCH! Connection should work.');
            _addLog('');
          }

          // Step 5: Check MQTT Topics
          _addLog('📋 STEP 5: Checking MQTT Topics...');
          _addLog('   • ESP32 publishes to: medicinebox/${esp32MedicineBoxId ?? "NULL"}/status');
          _addLog('   • Flutter subscribes to: medicinebox/$firestoreMedicineBoxId/status');
          _addLog('');

          // Step 6: Check MQTT Connection Status
          _addLog('📋 STEP 6: Checking MQTT Connections...');
          _addLog('   • ESP32 MQTT Status: ${statusData['mqttConnected'] == true ? "✅ Connected" : "❌ Disconnected"}');
          _addLog('   • Flutter MQTT Status: ${_mqttService.isConnected ? "✅ Connected" : "❌ Disconnected"}');
          _addLog('');

          if (!_mqttService.isConnected) {
            _addLog('❌ WARNING: Flutter is not connected to MQTT broker!');
            _addLog('   Solution: Restart the app or check broker connectivity');
            _addLog('');
          }

          if (statusData['mqttConnected'] != true) {
            _addLog('❌ WARNING: ESP32 is not connected to MQTT broker!');
            _addLog('   Solution: Check ESP32 Serial Monitor for errors');
            _addLog('');
          }

          // Step 7: Summary
          _addLog('📋 SUMMARY:');
          if (esp32MedicineBoxId == firestoreMedicineBoxId && 
              _mqttService.isConnected && 
              statusData['mqttConnected'] == true) {
            _addLog('✅ ALL CHECKS PASSED!');
            _addLog('   If messages still don\'t appear:');
            _addLog('   1. Press ESP32 button');
            _addLog('   2. Check ESP32 Serial Monitor for "MQTT published" message');
            _addLog('   3. Check MQTT Debug tab for received messages');
          } else {
            _addLog('❌ ISSUES FOUND - Fix them first!');
          }

        } else {
          _addLog('❌ ERROR: ESP32 returned status ${statusResponse.statusCode}');
        }
      } catch (e) {
        _addLog('❌ ERROR: Cannot reach ESP32 at $deviceIp');
        _addLog('   Error: $e');
        _addLog('   Solution: Check if ESP32 is powered on and WiFi is connected');
      }

    } catch (e) {
      _addLog('❌ ERROR: $e');
    }

    setState(() => _isRunning = false);
    _addLog('');
    _addLog('🏁 Diagnostic Complete!');
  }

  Future<void> _fixESP32Id() async {
    try {
      final boxes = await _firestoreService.getMedicineBoxes().first;
      if (boxes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No medicine boxes found')),
        );
        return;
      }

      final box = boxes.first;
      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(box.deviceId)
          .get();

      if (!deviceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device not found')),
        );
        return;
      }

      final ip = deviceDoc.data()?['ip'] as String?;
      if (ip == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device IP not found')),
        );
        return;
      }

      _addLog('🔧 Setting ESP32 medicineBoxId to: ${box.id}');

      final response = await http.get(
        Uri.parse('http://$ip/setmedicineboxid?id=${box.id}'),
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        _addLog('✅ SUCCESS: ESP32 medicineBoxId updated!');
        _addLog('   Response: ${response.body}');
        _addLog('');
        _addLog('⚠️  IMPORTANT: Wait 5 seconds, then:');
        _addLog('   1. Press ESP32 button to trigger MQTT publish');
        _addLog('   2. Check MQTT Debug tab for messages');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ESP32 ID fixed! Press ESP32 button to test.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        _addLog('❌ ERROR: HTTP ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      _addLog('❌ ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MQTT Full Diagnostic'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Action Buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runFullDiagnostic,
                    icon: _isRunning 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.play_arrow),
                    label: Text(_isRunning ? 'Running Diagnostic...' : 'Run Full Diagnostic'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _fixESP32Id,
                    icon: Icon(Icons.build),
                    label: Text('Fix ESP32 Medicine Box ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(),

          // Log Output
          Expanded(
            child: _diagnosticLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Press "Run Full Diagnostic" to start',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _diagnosticLogs.length,
                    itemBuilder: (context, index) {
                      final log = _diagnosticLogs[index];
                      Color textColor = Colors.black87;
                      
                      if (log.contains('✅')) textColor = Colors.green[700]!;
                      else if (log.contains('❌')) textColor = Colors.red[700]!;
                      else if (log.contains('⚠️')) textColor = Colors.orange[700]!;
                      else if (log.contains('📋')) textColor = Colors.blue[700]!;
                      else if (log.contains('🔍') || log.contains('🏁')) {
                        textColor = Colors.purple[700]!;
                      }

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: textColor,
                            fontWeight: log.contains('ERROR') || log.contains('STEP') 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
