import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mqtt_service.dart';
import '../services/firestore_service.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

class MqttDebugPage extends StatefulWidget {
  @override
  _MqttDebugPageState createState() => _MqttDebugPageState();
}

class _MqttDebugPageState extends State<MqttDebugPage> {
  final MqttService _mqttService = MqttService();
  final FirestoreService _firestoreService = FirestoreService();
  
  String _connectionStatus = 'Checking...';
  String _medicineBoxId = 'Loading...';
  List<String> _receivedMessages = [];

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _listenToMessages();
  }

  Future<void> _checkConnection() async {
    try {
      // Get medicine box ID from Firestore
      final boxes = await _firestoreService.getMedicineBoxes().first;
      if (boxes.isNotEmpty) {
        setState(() {
          _medicineBoxId = boxes.first.id;
        });
        
        print('\n╔════════════════════════════════════════════╗');
        print('║   MQTT DIAGNOSTIC INFORMATION              ║');
        print('╚════════════════════════════════════════════╝');
        print('📦 Firestore Medicine Box ID: ${boxes.first.id}');
        print('📦 Device ID: ${boxes.first.deviceId}');
        print('📡 Expected MQTT Topic: medicinebox/${boxes.first.id}/status');
        print('⚠️  ESP32 must publish to this EXACT topic!');
        print('════════════════════════════════════════════\n');
      } else {
        setState(() {
          _medicineBoxId = 'No medicine box found!';
          _connectionStatus = '❌ No medicine boxes in Firestore';
        });
        return;
      }

      // Check MQTT connection
      if (_mqttService.isConnected) {
        setState(() {
          _connectionStatus = '✅ Connected to MQTT broker';
        });
      } else {
        setState(() {
          _connectionStatus = '❌ Not connected - Reconnecting...';
        });
        
        // Try to connect
        if (boxes.isNotEmpty) {
          await _mqttService.connect(boxes.first.id);
          
          await Future.delayed(Duration(seconds: 2));
          
          setState(() {
            _connectionStatus = _mqttService.isConnected 
                ? '✅ Connected to MQTT broker' 
                : '❌ Connection failed - Check broker';
          });
        }
      }
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ Error: $e';
      });
      print('Error in _checkConnection: $e');
    }
  }

  void _listenToMessages() {
    _mqttService.statusStream.listen((data) {
      setState(() {
        final timestamp = DateTime.now().toString().substring(11, 19);
        _receivedMessages.insert(0, '[$timestamp] ${data.toString()}');
        
        // Keep only last 10 messages
        if (_receivedMessages.length > 10) {
          _receivedMessages.removeLast();
        }
      });
    });
  }

  Future<void> _testESP32Connection() async {
    try {
      final boxes = await _firestoreService.getMedicineBoxes().first;
      if (boxes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No medicine boxes found in Firestore')),
        );
        return;
      }

      final box = boxes.first;
      final deviceId = box.deviceId;
      
      if (deviceId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Medicine box has no device ID set')),
        );
        return;
      }

      // Get device IP
      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .get();
      
      if (!deviceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device not found in Firestore')),
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

      // Call ESP32 /setmedicineboxid endpoint
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setting medicineBoxId on ESP32...')),
      );

      final response = await http.get(
        Uri.parse('http://$ip/setmedicineboxid?id=${box.id}'),
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ESP32 medicineBoxId set to: ${box.id}'),
            backgroundColor: Colors.green,
          ),
        );
        
        print('✅ ESP32 response: ${response.body}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MQTT Debugging'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _checkConnection,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status Card
            Card(
              color: _connectionStatus.contains('✅') 
                  ? Colors.green[50] 
                  : Colors.red[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _connectionStatus,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Configuration Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MQTT Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildInfoRow('Broker', '34.19.178.165:1883'),
                    _buildInfoRow('Medicine Box ID', _medicineBoxId),
                    _buildInfoRow('Subscribed Topic', 'medicinebox/$_medicineBoxId/status'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Instructions Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Test Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Make sure ESP32 is connected to WiFi\n'
                      '2. ESP32 must have medicineBoxId = $_medicineBoxId\n'
                      '3. Press button to open/close box on ESP32\n'
                      '4. Watch for messages below\n'
                      '5. ESP32 should publish to: medicinebox/$_medicineBoxId/status',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _testESP32Connection,
                      icon: Icon(Icons.bug_report),
                      label: Text('Test ESP32 MedicineBoxId'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Received Messages
            Text(
              'Received Messages (${_receivedMessages.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            
            if (_receivedMessages.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.message, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No messages received yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Press the button on ESP32 to test',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._receivedMessages.map((msg) => Card(
                child: ListTile(
                  leading: Icon(Icons.message, color: Colors.green),
                  title: Text(
                    msg,
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
