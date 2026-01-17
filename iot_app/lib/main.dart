import 'package:flutter/material.dart';
import 'dart:async';
import 'pages/today_doses_page.dart';
import 'pages/medicine_management_page.dart';
import 'pages/device_scanner_page.dart';
import 'pages/adherence_report_page.dart';
import 'pages/auth_page.dart';
import 'services/mongodb_service.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  try {
    await NotificationService().initialize();
    print('✅ Notification service initialized');
  } catch (e) {
    print('Error initializing notifications: $e');
  }

  runApp(MedicineReminderApp());
}

class MedicineReminderApp extends StatefulWidget {
  @override
  _MedicineReminderAppState createState() => _MedicineReminderAppState();
}

class _MedicineReminderAppState extends State<MedicineReminderApp> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(Duration(milliseconds: 100)); // Small delay to ensure initialization
    if (mounted) {
      setState(() {
        _isAuthenticated = _authService.isAuthenticated;
        _isLoading = false;
      });
    }
  }

  void _onAuthChanged() {
    print('🔄 Auth state changed. isAuthenticated: ${_authService.isAuthenticated}');
    if (mounted) {
      setState(() {
        _isAuthenticated = _authService.isAuthenticated;
      });
    }
  }

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
      home: _isLoading
          ? Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isAuthenticated
              ? HomePage()
              : AuthPage(onAuthSuccess: _onAuthChanged),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final MongoDBService _mongoDBService = MongoDBService();
  Timer? _statusUpdateTimer;

  final List<Widget> _pages = [
    TodayDosesPage(),
    MedicineManagementPage(),
    DeviceScannerPage(),
    AdherenceReportPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Update statuses immediately when app starts
    _updateReminderStatuses();

    // Set up periodic updates every 5 minutes
    _statusUpdateTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _updateReminderStatuses();
    });
  }

  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateReminderStatuses() async {
    try {
      await _mongoDBService.updateAllReminderStatuses();
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
        ],
      ),
    );
  }
}
