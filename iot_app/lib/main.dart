import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'pages/today_doses_page.dart';
import 'pages/medicine_management_page.dart';
import 'pages/device_scanner_page.dart';
import 'pages/adherence_report_page.dart';
import 'pages/mqtt_debug_page.dart';
import 'pages/mqtt_test_page.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/mqtt_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize notification service
  try {
    await NotificationService().initialize();
  } catch (e) {
    print('Error initializing notifications: $e');
  }

  runApp(MedicineReminderApp());
}

class MedicineReminderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Medicine Box',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF1976D2), // Medical Blue
          brightness: Brightness.light,
          primary: Color(0xFF1976D2), // Medical Blue
          secondary: Color(0xFF26A69A), // Medical Teal
          tertiary: Color(0xFF66BB6A), // Medical Green
          error: Color(0xFFE53935), // Medical Red
        ),
        scaffoldBackgroundColor: Color(0xFFF5F7FA), // Light clinical background
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1976D2), // Medical Blue
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1976D2), // Medical Blue
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF1976D2), // Medical Blue
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  final MqttService _mqttService = MqttService();
  Timer? _statusUpdateTimer;

  final List<Widget> _pages = [
    TodayDosesPage(),
    MedicineManagementPage(),
    DeviceScannerPage(),
    AdherenceReportPage(),
    MqttDebugPage(),
    MqttTestPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Update statuses immediately when app starts
    _updateReminderStatuses();

    // Initialize MQTT connection
    _initializeMqtt();

    // Set up periodic updates every 5 minutes
    _statusUpdateTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _updateReminderStatuses();
    });
  }

  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    _mqttService.dispose();
    super.dispose();
  }

  Future<void> _initializeMqtt() async {
    try {
      // Get the first medicine box to use its ID for MQTT subscription
      final boxes = await _firestoreService.getMedicineBoxes().first;
      if (boxes.isNotEmpty) {
        final medicineBoxId = boxes.first.id;
        print('📡 Initializing MQTT with Medicine Box ID: $medicineBoxId');
        await _mqttService.connect(medicineBoxId);
      } else {
        print('⚠️ No medicine boxes found - MQTT not initialized');
      }
    } catch (e) {
      print('❌ Error initializing MQTT: $e');
    }
  }

  Future<void> _updateReminderStatuses() async {
    try {
      await _firestoreService.updateAllReminderStatuses();
      print('Reminder statuses updated at ${DateTime.now()}');
    } catch (e) {
      print('Error updating reminder statuses: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Medicines',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi_find),
            label: 'Devices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Reports',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bug_report), label: 'Debug'),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Test'),
        ],
      ),
    );
  }
}
