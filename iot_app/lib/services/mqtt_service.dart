import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'mongodb_service.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  final MongoDBService _mongoDBService = MongoDBService();
  
  // MQTT Configuration
  static const String _broker = '34.19.178.165';
  static const int _port = 1883;
  
  bool _isConnected = false;
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  bool get isConnected => _isConnected;

  /// Initialize and connect to MQTT broker
  Future<void> connect(String medicineBoxId) async {
    if (_isConnected && _client != null) {
      print('📡 MQTT already connected');
      return;
    }

    try {
      print('\n╔════════════════════════════════════════════╗');
      print('║   MQTT CONNECTION ATTEMPT                  ║');
      print('╚════════════════════════════════════════════╝');
      print('📡 Broker: $_broker:$_port');
      print('📦 Medicine Box ID: $medicineBoxId');
      
      // Create client with unique ID
      final clientId = 'flutter_app_${DateTime.now().millisecondsSinceEpoch}';
      print('🔑 Client ID: $clientId');
      
      _client = MqttServerClient.withPort(_broker, clientId, _port);
      
      _client!.logging(on: true);  // Enable detailed logging
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.pongCallback = _onPong;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      _client!.connectionMessage = connMessage;

      print('⏳ Connecting...');
      await _client!.connect();
      
      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        print('\n╔════════════════════════════════════════════╗');
        print('║   ✅ MQTT CONNECTED SUCCESSFULLY! ✅       ║');
        print('╚════════════════════════════════════════════╝\n');
        
        // Subscribe to medicine box status topic
        _subscribeToBox(medicineBoxId);
      } else {
        print('\n╔════════════════════════════════════════════╗');
        print('║   ❌ MQTT CONNECTION FAILED! ❌            ║');
        print('╚════════════════════════════════════════════╝');
        print('Status: ${_client!.connectionStatus}');
        print('State: ${_client!.connectionStatus!.state}');
        print('Return Code: ${_client!.connectionStatus!.returnCode}\n');
        _client = null;
      }
    } catch (e) {
      print('\n╔════════════════════════════════════════════╗');
      print('║   ❌ MQTT CONNECTION ERROR! ❌             ║');
      print('╚════════════════════════════════════════════╝');
      print('Error: $e');
      print('Check:');
      print('  1. MQTT broker is running on GCP VM');
      print('  2. Firewall allows port 1883');
      print('  3. Internet connection is working\n');
      _client = null;
      _isConnected = false;
    }
  }

  /// Subscribe to medicine box status updates
  void _subscribeToBox(String medicineBoxId) {
    if (_client == null || !_isConnected) {
      print('⚠️ Cannot subscribe - MQTT not connected');
      return;
    }

    final topic = 'medicinebox/$medicineBoxId/status';
    print('📬 Subscribing to topic: $topic');
    
    _client!.subscribe(topic, MqttQos.atLeastOnce);
    
    // Listen to messages
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final MqttPublishMessage recMess = message.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        
        print('\n╔════════════════════════════════════════════╗');
        print('║   📨 MQTT MESSAGE RECEIVED! 📨             ║');
        print('╚════════════════════════════════════════════╝');
        print('Topic: ${message.topic}');
        print('Payload: $payload');
        print('════════════════════════════════════════════\n');
        
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _handleStatusUpdate(data);
          _statusController.add(data);
        } catch (e) {
          print('❌ Error parsing MQTT message: $e');
        }
      }
    });
  }

  /// Handle status update from ESP32
  Future<void> _handleStatusUpdate(Map<String, dynamic> data) async {
    try {
      final medicineBoxId = data['medicineBoxId'] as String?;
      final boxNumber = data['boxNumber'] as int?;
      final taken = data['taken'] as bool?;
      final weight = data['weight'] as num?;

      print('🔄 Processing status update:');
      print('   Medicine Box ID: $medicineBoxId');
      print('   Box Number: $boxNumber');
      print('   Medicine Taken: $taken');
      print('   Weight: ${weight}g');

      if (medicineBoxId == null || boxNumber == null || taken == null) {
        print('⚠️ Invalid MQTT data - missing required fields');
        return;
      }

      if (taken) {
        // Medicine was taken - find and update the corresponding record
        print('✅ Medicine taken detected - updating record...');
        await _mongoDBService.autoCompleteRecordFromDevice(
          medicineBoxId,
          boxNumber,
        );
        print('✅ Record marked as completed!');
      } else {
        print('ℹ️ No medicine taken - keeping record as overdue');
      }
    } catch (e) {
      print('❌ Error handling status update: $e');
    }
  }

  /// Callback when connected
  void _onConnected() {
    print('✅ MQTT: Connected to broker');
    _isConnected = true;
  }

  /// Callback when disconnected
  void _onDisconnected() {
    print('⚠️ MQTT: Disconnected from broker');
    _isConnected = false;
  }

  /// Callback when subscribed to a topic
  void _onSubscribed(String topic) {
    print('✅ MQTT: Subscribed to $topic');
  }

  /// Callback for pong
  void _onPong() {
    // Keep alive pong received
  }

  /// Disconnect from MQTT broker
  void disconnect() {
    if (_client != null) {
      print('📡 Disconnecting from MQTT broker...');
      _client!.disconnect();
      _client = null;
      _isConnected = false;
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _statusController.close();
  }
}

