import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to communicate with IoT Medicine Box via HTTP
class DeviceService {
  // Cache device IPs to avoid repeated lookups
  static final Map<String, String> _deviceIpCache = {};
  
  // Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Keys for SharedPreferences
  static const String _lastDiscoveredIpKey = 'last_discovered_ip';
  
  /// Get device IP from Firestore devices collection
  /// Retrieves IP address for a specific deviceId from the database
  Future<String?> getDeviceIp(String deviceId) async {
    try {
      // Check cache first
      if (_deviceIpCache.containsKey(deviceId)) {
        return _deviceIpCache[deviceId];
      }
      
      // Query Firestore devices collection
      final deviceDoc = await _db.collection('devices').doc(deviceId).get();
      
      if (deviceDoc.exists) {
        final data = deviceDoc.data();
        final ip = data?['ip'] as String?;
        
        if (ip != null) {
          // Cache the IP for future use
          _deviceIpCache[deviceId] = ip;
          return ip;
        }
      }
      
      print('Device IP not found in Firestore for deviceId: $deviceId');
      return null;
    } catch (e) {
      print('Error getting device IP from Firestore: $e');
      return null;
    }
  }
  
  /// Manually set device IP (useful for testing or manual configuration)
  void setDeviceIp(String deviceId, String ipAddress) {
    _deviceIpCache[deviceId] = ipAddress;
    _saveDeviceIpToDisk(deviceId, ipAddress);
  }
  
  /// Save device IP to persistent storage
  Future<void> _saveDeviceIpToDisk(String deviceId, String ipAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save individual device mapping
      await prefs.setString('device_ip_$deviceId', ipAddress);
      
      // Also save as last discovered IP for auto-population
      await prefs.setString(_lastDiscoveredIpKey, ipAddress);
      
      print('Saved IP $ipAddress for device $deviceId');
    } catch (e) {
      print('Error saving device IP: $e');
    }
  }
  
  /// Get the last discovered IP address
  Future<String?> getLastDiscoveredIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastDiscoveredIpKey);
    } catch (e) {
      print('Error getting last discovered IP: $e');
      return null;
    }
  }
  
  /// Load device IP from persistent storage
  Future<String?> loadDeviceIpFromDisk(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString('device_ip_$deviceId');
      
      if (ip != null) {
        _deviceIpCache[deviceId] = ip;
      }
      
      return ip;
    } catch (e) {
      print('Error loading device IP: $e');
      return null;
    }
  }
  
  /// Get all saved device IPs
  Future<Map<String, String>> getAllSavedDeviceIps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, String> deviceIps = {};
      
      for (final key in keys) {
        if (key.startsWith('device_ip_')) {
          final deviceId = key.replaceFirst('device_ip_', '');
          final ip = prefs.getString(key);
          if (ip != null) {
            deviceIps[deviceId] = ip;
          }
        }
      }
      
      return deviceIps;
    } catch (e) {
      print('Error getting all device IPs: $e');
      return {};
    }
  }
  
  /// Blink LED for specific box compartment
  /// boxNumber: 1-7 for the seven compartments
  /// times: number of blinks (default 10 = 10 seconds of blinking)
  Future<bool> blinkBoxLED(String deviceId, int boxNumber, {int times = 10}) async {
    final ip = await getDeviceIp(deviceId);
    if (ip == null) {
      throw Exception('Device IP not found for deviceId: $deviceId');
    }
    
    if (boxNumber < 1 || boxNumber > 7) {
      throw Exception('Invalid box number: $boxNumber. Must be 1-7');
    }
    
    try {
      final url = Uri.parse('http://$ip/blink?box=$boxNumber&times=$times');
      final response = await http.get(url).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      print('Error blinking LED: $e');
      rethrow;
    }
  }
  
  /// Turn LED on/off for specific box compartment
  Future<bool> setBoxLED(String deviceId, int boxNumber, bool state) async {
    final ip = await getDeviceIp(deviceId);
    if (ip == null) {
      throw Exception('Device IP not found for deviceId: $deviceId');
    }
    
    if (boxNumber < 1 || boxNumber > 7) {
      throw Exception('Invalid box number: $boxNumber. Must be 1-7');
    }
    
    try {
      final stateStr = state ? 'on' : 'off';
      final url = Uri.parse('http://$ip/led?box=$boxNumber&state=$stateStr');
      final response = await http.get(url).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      print('Error controlling LED: $e');
      rethrow;
    }
  }
  
  /// Get device status
  Future<Map<String, dynamic>?> getDeviceStatus(String deviceId) async {
    final ip = await getDeviceIp(deviceId);
    if (ip == null) {
      throw Exception('Device IP not found for deviceId: $deviceId');
    }
    
    try {
      final url = Uri.parse('http://$ip/status');
      final response = await http.get(url).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return null;
    } catch (e) {
      print('Error getting device status: $e');
      rethrow;
    }
  }
  
  /// Discover devices on network by IP scanning
  /// Returns a list of discovered devices with their IP and name
  Future<List<Map<String, dynamic>>> discoverDevice(String subnetPrefix) async {
    final discoveredDevices = <Map<String, dynamic>>[];
    
    // Example: subnetPrefix = "192.168.32" will scan 192.168.32.1-254
    for (int i = 1; i < 255; i++) {
      try {
        final ip = '$subnetPrefix.$i';
        final url = Uri.parse('http://$ip/discover');
        final response = await http.get(url).timeout(Duration(milliseconds: 500));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['device'] == 'Smart Medicine Box') {
            // Cache this IP
            final deviceId = data['boxId'] ?? data['medicineBoxId'] ?? 'device_$ip';
            _deviceIpCache[deviceId] = ip;
            
            // Save to Firestore devices collection
            await _saveDeviceToFirestore(deviceId, ip, data['device'] ?? 'Smart Medicine Box');
            
            // Add to discovered devices list
            discoveredDevices.add({
              'ip': ip,
              'name': data['device'] ?? 'Smart Medicine Box',
              'deviceId': deviceId,
            });
          }
        }
      } catch (e) {
        // Timeout or connection refused - move to next IP
        continue;
      }
    }
    
    return discoveredDevices;
  }
  
  /// Save discovered device to Firestore devices collection
  Future<void> _saveDeviceToFirestore(String deviceId, String ip, String name) async {
    try {
      await _db.collection('devices').doc(deviceId).set({
        'ip': ip,
        'name': name,
        'connectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('Saved device $deviceId ($ip) to Firestore');
    } catch (e) {
      print('Error saving device to Firestore: $e');
    }
  }
}
