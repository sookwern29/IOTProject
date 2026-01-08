import 'package:flutter/material.dart';
import '../services/device_service.dart';

/// Helper page to configure IoT device IP addresses
/// Use this to manually set or discover your medicine box IP
class DeviceSetupHelper extends StatefulWidget {
  @override
  _DeviceSetupHelperState createState() => _DeviceSetupHelperState();
}

class _DeviceSetupHelperState extends State<DeviceSetupHelper> {
  final DeviceService _deviceService = DeviceService();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  bool _isDiscovering = false;
  List<Map<String, dynamic>> _discoveredDevices = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IoT Device Setup'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure Medicine Box IP',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            // Manual IP Configuration
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Configuration',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _deviceIdController,
                      decoration: InputDecoration(
                        labelText: 'Device ID (from medicine box)',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., A1B2C3D4E5F6',
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        labelText: 'IP Address',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 192.168.32.100',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saveDeviceIp,
                      child: Text('Save Configuration'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Auto Discovery
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto Discovery',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Scan your local network to find medicine box devices.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isDiscovering ? null : _discoverDevice,
                      icon: _isDiscovering 
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.search),
                      label: Text(_isDiscovering ? 'Scanning...' : 'Scan Network'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                      ),
                    ),
                    if (_discoveredDevices.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Found ${_discoveredDevices.length} device(s):',
                                  style: TextStyle(
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            ..._discoveredDevices.map((device) => Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '• ${device['name'] ?? 'Smart Medicine Box'} at ${device['ip']}',
                                style: TextStyle(color: Colors.green[900]),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
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
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Setup Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Power on your medicine box\n'
                      '2. Connect it to WiFi\n'
                      '3. Find the IP address (check Serial Monitor or router)\n'
                      '4. Enter Device ID and IP above\n'
                      '5. Or use Auto Discovery to scan',
                      style: TextStyle(color: Colors.blue[900]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveDeviceIp() {
    final deviceId = _deviceIdController.text.trim();
    final ip = _ipController.text.trim();
    
    if (deviceId.isEmpty || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter both Device ID and IP address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    _deviceService.setDeviceIp(deviceId, ip);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Device configured successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    
    _deviceIdController.clear();
    _ipController.clear();
  }

  Future<void> _discoverDevice() async {
    setState(() {
      _isDiscovering = true;
      _discoveredDevices = [];
    });
    
    try {
      // Get user's subnet (you might want to make this configurable)
      final devices = await _deviceService.discoverDevice('192.168.32');
      
      setState(() {
        _discoveredDevices = devices;
        _isDiscovering = false;
      });
      
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No device found. Try a different subnet or manual setup.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Auto-fill IP if only one device found
        if (devices.length == 1) {
          _ipController.text = devices.first['ip'];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${devices.length} device(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during discovery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _ipController.dispose();
    super.dispose();
  }
}
