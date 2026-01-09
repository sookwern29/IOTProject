import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
import '../models/medicine_box.dart';

class DeviceScannerPage extends StatefulWidget {
  @override
  _DeviceScannerPageState createState() => _DeviceScannerPageState();
}

class _DeviceScannerPageState extends State<DeviceScannerPage>
    with SingleTickerProviderStateMixin {
  // WiFi/IP Scanner
  final DeviceService _deviceService = DeviceService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isIPScanning = false;
  List<Map<String, dynamic>> _discoveredDevices = [];
  double _scanProgress = 0;
  int _scannedCount = 0;
  int _totalToScan = 0;
  String _scanStatus = 'Ready to scan';

  // Manual IP Entry
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();

  // Tab Controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadSavedDevices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _checkBluetoothPermissions() async {
    // Bluetooth permissions removed - WiFi only
  }

  Future<void> _startScan() async {
    // Bluetooth scan removed
  }

  Future<void> _stopScan() async {
    // Bluetooth scan removed
  }

  Future<void> _connectToDevice(dynamic device) async {
    // Bluetooth connection removed
  }

  Future<void> _disconnectDevice() async {
    // Bluetooth disconnection removed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Device Scanner')),
      body: _buildWiFiScanner(),
    );
  }

  // WiFi/IP Scanner
  Widget _buildWiFiScanner() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Automatic Network Scan
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, color: Color(0xFF1976D2)),
                      SizedBox(width: 8),
                      Text(
                        'Auto-Discover Devices',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    _scanStatus,
                    style: TextStyle(
                      color: _isIPScanning ? Colors.blue : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isIPScanning ? null : _scanNetwork,
                    icon: _isIPScanning
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.wifi_find),
                    label: Text(
                      _isIPScanning
                          ? 'Scanning Network...'
                          : 'Start Network Scan',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                  if (_isIPScanning) ...[
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          LinearProgressIndicator(value: _scanProgress),
                          SizedBox(height: 8),
                          Text(
                            'Scanned $_scannedCount / $_totalToScan IPs (Found: ${_discoveredDevices.length})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Discovered Devices
          if (_discoveredDevices.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discovered Devices (${_discoveredDevices.length})',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _clearSavedDevices,
                  icon: Icon(Icons.delete_outline, size: 18),
                  label: Text('Clear All'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._discoveredDevices.map((device) => _buildDeviceCard(device)),
          ],

          SizedBox(height: 20),

          // Manual IP Entry
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, color: Color(0xFF26A69A)),
                      SizedBox(width: 8),
                      Text(
                        'Manual Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: 'Device IP Address',
                      hintText: '192.168.32.100',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.router),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _deviceIdController,
                    decoration: InputDecoration(
                      labelText: 'Device ID (optional)',
                      hintText: 'Will be auto-detected',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _testConnection,
                          icon: Icon(Icons.wifi_tethering),
                          label: Text('Test Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF26A69A),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveManualDevice,
                          icon: Icon(Icons.save),
                          label: Text('Save Device'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF66BB6A),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Instructions
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF1976D2)),
                      SizedBox(width: 8),
                      Text(
                        'How to Connect',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Make sure ESP32 is powered on\n'
                    '2. Connect to same WiFi network\n'
                    '3. Use Auto-Discover or enter IP manually\n'
                    '4. Test connection before saving\n'
                    '5. Save device to link with medicine boxes',
                    style: TextStyle(color: Colors.blue[900]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bluetooth Scanner Tab (existing)
  Widget _buildBluetoothScanner() {
    return Center(child: Text('Bluetooth scanner removed'));
  }

  // WiFi Scanner Methods
  Future<void> _scanNetwork() async {
    setState(() {
      _isIPScanning = true;
      _discoveredDevices.clear();
      _scanProgress = 0;
      _scannedCount = 0;
      _scanStatus = 'Getting network info...';
    });

    try {
      // Get local IP to determine network range
      String? localIp;
      List<String> allLocalIps = [];

      try {
        final interfaces = await NetworkInterface.list();
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              allLocalIps.add(addr.address);
              // Prefer 192.168.x.x addresses
              if (addr.address.startsWith('192.168') && localIp == null) {
                localIp = addr.address;
              }
            }
          }
        }
      } catch (e) {
        print('Error getting network interfaces: $e');
      }

      // If no 192.168.x.x found, use first available local IP
      if (localIp == null && allLocalIps.isNotEmpty) {
        localIp = allLocalIps.first;
      }

      if (localIp == null) {
        setState(() {
          _scanStatus = 'Could not find local IP. Please enter IP manually.';
          _isIPScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not detect network. Use manual entry below.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get network prefix (e.g., 192.168.32)
      final parts = localIp.split('.');
      final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';

      setState(() {
        _totalToScan = 254;
        _scanStatus = 'Scanning $networkPrefix.1 - $networkPrefix.254...';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanning $networkPrefix.0/24 network...')),
      );

      // Scan in batches for better performance
      const batchSize = 20;
      for (int start = 1; start <= 254 && _isIPScanning; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, 254);
        final futures = <Future>[];

        for (int i = start; i <= end && _isIPScanning; i++) {
          final ip = '$networkPrefix.$i';
          futures.add(_checkDevice(ip));
        }

        await Future.wait(futures);

        setState(() {
          _scannedCount = end;
          _scanProgress = end / 254;
          _scanStatus =
              'Scanned $end/254 IPs... (Found: ${_discoveredDevices.length})';
        });

        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() {
        _isIPScanning = false;
        _scanProgress = 1;
        if (_discoveredDevices.isEmpty) {
          _scanStatus = 'Scan complete. No devices found.';
        } else {
          _scanStatus = 'Found ${_discoveredDevices.length} device(s)!';
        }
      });

      if (_discoveredDevices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No ESP32 devices found. Check if:\n• ESP32 is powered on\n• ESP32 is on same WiFi\n• Check Serial Monitor for IP',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${_discoveredDevices.length} device(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isIPScanning = false;
        _scanStatus = 'Scan error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _checkDevice(String ip) async {
    if (!_isIPScanning) return;

    try {
      // Try /discover endpoint first
      final response = await http
          .get(Uri.parse('http://$ip/discover'))
          .timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['device'] == 'Smart Medicine Box') {
            final deviceId =
                data['boxId'] ?? data['medicineBoxId'] ?? 'device_$ip';
            final deviceData = {
              'ip': ip,
              'name': data['device'] ?? 'Smart Medicine Box',
              'version': data['version'] ?? '1.0',
              'lastSeen': DateTime.now().toIso8601String(),
              'deviceId': deviceId,
            };
            setState(() {
              // Avoid duplicates
              if (!_discoveredDevices.any((d) => d['ip'] == ip)) {
                _discoveredDevices.add(deviceData);
              }
            });
            _saveDevicesToDisk();
            // Save to Firestore devices collection
            await _saveDeviceToFirestore(
              deviceId,
              ip,
              data['device'] ?? 'Smart Medicine Box',
            );
            // Automatically link to all medicine boxes
            await _autoLinkToAllBoxes(deviceId, ip);
            return;
          }
        } catch (e) {
          // Ignore parse errors
        }
      }

      // Also try /status endpoint as fallback
      final statusResponse = await http
          .get(Uri.parse('http://$ip/status'))
          .timeout(const Duration(milliseconds: 1500));

      if (statusResponse.statusCode == 200) {
        try {
          final data = json.decode(statusResponse.body);
          if (data.containsKey('device')) {
            final deviceId =
                data['boxId'] ?? data['medicineBoxId'] ?? 'device_$ip';
            final deviceData = {
              'ip': ip,
              'name': 'Smart Medicine Box',
              'version': '1.0',
              'lastSeen': DateTime.now().toIso8601String(),
              'deviceId': deviceId,
            };
            setState(() {
              if (!_discoveredDevices.any((d) => d['ip'] == ip)) {
                _discoveredDevices.add(deviceData);
              }
            });
            _saveDevicesToDisk();
            // Save to Firestore devices collection
            await _saveDeviceToFirestore(deviceId, ip, 'Smart Medicine Box');
            // Automatically link to all medicine boxes
            await _autoLinkToAllBoxes(deviceId, ip);
          }
        } catch (_) {}
      }
    } catch (e) {
      // Device not found or not responding - ignore
    }
  }

  /// Save discovered device to Firestore devices collection
  Future<void> _saveDeviceToFirestore(
    String deviceId,
    String ip,
    String name,
  ) async {
    try {
      await _firestoreService.saveDeviceToFirestore(deviceId, ip, name);
      print('Saved device $deviceId ($ip) to Firestore');
    } catch (e) {
      print('Error saving device to Firestore: $e');
    }
  }

  /// Automatically link discovered device to all medicine boxes
  Future<void> _autoLinkToAllBoxes(String deviceId, String ip) async {
    try {
      final boxes = await _firestoreService.getMedicineBoxes().first;

      for (var box in boxes) {
        // Update each box's deviceId
        final updatedBox = MedicineBox(
          id: box.id,
          name: box.name,
          boxNumber: box.boxNumber,
          deviceId: deviceId,
          medicineType: box.medicineType,
          isConnected: true,
          lastUpdated: DateTime.now(),
          reminders: box.reminders,
          compartments: box.compartments,
        );

        await _firestoreService.updateMedicineBox(updatedBox);
        _deviceService.setDeviceIp(deviceId, ip);
      }

      if (boxes.isNotEmpty) {
        print(
          'Auto-linked device $deviceId to ${boxes.length} medicine box(es)',
        );
      }
    } catch (e) {
      print('Error auto-linking device: $e');
    }
  }

  Future<void> _loadSavedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = prefs.getString('discovered_devices');

      if (devicesJson != null) {
        final List<dynamic> devicesList = json.decode(devicesJson);
        setState(() {
          _discoveredDevices = devicesList.cast<Map<String, dynamic>>();
          if (_discoveredDevices.isNotEmpty) {
            _scanStatus = 'Loaded ${_discoveredDevices.length} saved device(s)';
          }
        });
      }
    } catch (e) {
      print('Error loading saved devices: $e');
    }
  }

  Future<void> _saveDevicesToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = json.encode(_discoveredDevices);
      await prefs.setString('discovered_devices', devicesJson);
    } catch (e) {
      print('Error saving devices: $e');
    }
  }

  Future<void> _clearSavedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('discovered_devices');
      setState(() {
        _discoveredDevices.clear();
        _scanStatus = 'Cleared all saved devices';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleared all saved devices'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error clearing devices: $e');
    }
  }

  Future<void> _testConnection() async {
    if (_ipController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter an IP address')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Testing connection...')));

    try {
      // Create a temporary device ID for testing
      final tempId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      _deviceService.setDeviceIp(tempId, _ipController.text);

      final status = await _deviceService.getDeviceStatus(tempId);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Connection Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IP: ${_ipController.text}'),
              if (status != null && status.containsKey('device'))
                Text('Device: ${status['device']}'),
              if (status != null && status.containsKey('wifi'))
                Text('WiFi: ${status['wifi']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Connection Failed'),
            ],
          ),
          content: Text(
            'Could not connect to device at ${_ipController.text}\n\nError: $e',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveManualDevice() async {
    if (_ipController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter an IP address')));
      return;
    }

    try {
      String deviceId = _deviceIdController.text.trim();

      // If no device ID, auto-generate one
      if (deviceId.isEmpty) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }

      _deviceService.setDeviceIp(deviceId, _ipController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device saved! ID: $deviceId'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear fields
      _ipController.clear();
      _deviceIdController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save device: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final lastSeen = device['lastSeen'] != null
        ? DateTime.parse(device['lastSeen'])
        : null;
    final timeAgo = lastSeen != null
        ? _formatTimeAgo(DateTime.now().difference(lastSeen))
        : 'Just now';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.router, color: Colors.green[700], size: 28),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device['name'] ?? 'Smart Medicine Box',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.wifi, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              device['ip'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (lastSeen != null)
                        Text(
                          'Last seen: $timeAgo',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.green, size: 28),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-linked to all medicine boxes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _findDevice(device),
              icon: Icon(Icons.volume_up, size: 18),
              label: Text('Find Device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFA726),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(Duration duration) {
    if (duration.inSeconds < 60) {
      return 'Just now';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ago';
    } else {
      return '${duration.inDays}d ago';
    }
  }

  Future<void> _saveDiscoveredDevice(Map<String, dynamic> device) async {
    try {
      final deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      _deviceService.setDeviceIp(deviceId, device['ip']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device saved! ID: $deviceId'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _linkToBox(Map<String, dynamic> device) async {
    // Show dialog to select medicine box
    final boxesStream = _firestoreService.getMedicineBoxes();
    final boxes = await boxesStream.first;

    if (!mounted) return;

    if (boxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No medicine boxes found. Create one first.')),
      );
      return;
    }

    // Build the list of widgets
    final boxWidgets = boxes.map((box) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text('${box.boxNumber}'),
        ),
        title: Text(box.name),
        subtitle: Text('Box ${box.boxNumber}'),
        onTap: () {
          Navigator.pop(context);
          _saveLinkToBox(box, device);
        },
      );
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Link to Medicine Box'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: boxWidgets),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLinkToBox(
    MedicineBox box,
    Map<String, dynamic> device,
  ) async {
    try {
      // Get the deviceId from the discovered device (e.g., "D50FF8")
      final deviceId = device['deviceId'] ?? 'device_${device['ip']}';

      // Save IP mapping in SharedPreferences for quick access
      _deviceService.setDeviceIp(deviceId, device['ip']);

      // Update the medicine box's deviceId in Firestore to match the device
      final updatedBox = MedicineBox(
        id: box.id,
        name: box.name,
        boxNumber: box.boxNumber,
        deviceId: deviceId, // Update with the correct deviceId
        medicineType: box.medicineType,
        isConnected: true,
        lastUpdated: DateTime.now(),
        reminders: box.reminders,
        compartments: box.compartments,
      );

      await _firestoreService.updateMedicineBox(updatedBox);

      // Also ensure device is saved to Firestore devices collection
      await _saveDeviceToFirestore(
        deviceId,
        device['ip'],
        device['name'] ?? 'Smart Medicine Box',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device linked to ${box.name}! (ID: $deviceId)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Trigger buzzer on device to help locate it
  Future<void> _findDevice(Map<String, dynamic> device) async {
    try {
      final ip = device['ip'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔊 Activating buzzer on device...'),
          backgroundColor: Color(0xFFFFA726),
        ),
      );

      // Call /startalarm endpoint to trigger buzzer
      final response = await http
          .get(Uri.parse('http://$ip/startalarm'))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Show dialog with stop button
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.volume_up, color: Color(0xFFFFA726)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Device Buzzer Active',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_active,
                  size: 64,
                  color: Color(0xFFFFA726),
                ),
                SizedBox(height: 16),
                Text(
                  'The device at $ip is now beeping.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Press "Stop" to turn off the buzzer.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  try {
                    await http
                        .get(Uri.parse('http://$ip/stopbuzzer'))
                        .timeout(Duration(seconds: 3));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🔇 Buzzer stopped'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to stop buzzer: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: Icon(Icons.volume_off),
                label: Text('Stop Buzzer'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        );
      } else {
        throw Exception(
          'Failed to activate buzzer (HTTP ${response.statusCode})',
        );
      }
    } catch (e) {
      String errorMessage = 'Error: $e';

      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timed out')) {
        errorMessage =
            'Device not responding. Check if it\'s powered on and connected to WiFi.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }
}
