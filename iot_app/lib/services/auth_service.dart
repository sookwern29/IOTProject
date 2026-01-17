import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _baseUrl =
      'https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app';

  String? _currentUserId;
  String? _currentUserEmail;
  String? _currentUserName;
  String? _authToken;

  // Get current user ID
  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserName => _currentUserName;
  String? get authToken => _authToken;
  bool get isAuthenticated => _authToken != null;

  /// Initialize auth - restore from SharedPreferences if available
  Future<bool> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      _currentUserId = prefs.getString('user_id');
      _currentUserEmail = prefs.getString('user_email');
      _currentUserName = prefs.getString('user_name');

      if (isAuthenticated) {
        print('✅ Auth restored from storage');
        print('👤 User: $_currentUserEmail ($_currentUserId)');
        return true;
      }
      return false;
    } catch (e) {
      print('Error initializing auth: $e');
      return false;
    }
  }

  /// Save auth to SharedPreferences
  Future<void> _saveAuthToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _authToken ?? '');
      await prefs.setString('user_id', _currentUserId ?? '');
      await prefs.setString('user_email', _currentUserEmail ?? '');
      await prefs.setString('user_name', _currentUserName ?? '');
      print('💾 Auth saved to storage');
    } catch (e) {
      print('Error saving auth: $e');
    }
  }

  /// Clear auth from SharedPreferences
  Future<void> _clearAuthFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      print('🗑️ Auth cleared from storage');
    } catch (e) {
      print('Error clearing auth: $e');
    }
  }

  /// Register a new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email.trim(),
          'password': password,
          'fullName': fullName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('📦 Full registration response: $data');

        _currentUserId =
            data['userId'] ?? data['uid'] ?? data['_id'] ?? data['id'];
        _currentUserEmail = email.trim();
        _currentUserName = fullName;
        _authToken = data['token'] ?? data['authToken'] ?? 'registered';

        print('✅ User registered successfully: $email');
        print('🔑 Auth token stored: ${_authToken != null}');
        print('👤 User ID: $_currentUserId');

        // Save to persistent storage
        await _saveAuthToStorage();

        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email.trim(), 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Full login response: $data');

        _currentUserId =
            data['userId'] ?? data['uid'] ?? data['_id'] ?? data['id'];
        _currentUserEmail = email.trim();
        _currentUserName = data['fullName'] ?? data['name'];
        _authToken = data['token'] ?? data['authToken'] ?? 'logged_in';

        print('✅ User logged in: $email');
        print('🔑 Auth token stored: ${_authToken != null}');
        print('👤 User ID: $_currentUserId');

        // Save to persistent storage
        await _saveAuthToStorage();

        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      if (_authToken != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          },
        );
      }

      _currentUserId = null;
      _currentUserEmail = null;
      _currentUserName = null;
      _authToken = null;

      // Clear from persistent storage
      await _clearAuthFromStorage();

      print('✅ User logged out');
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/resetPassword'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email.trim()}),
      );

      if (response.statusCode == 200) {
        print('✅ Password reset email sent to: $email');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Password reset failed');
      }
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  /// Get user profile from MongoDB
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$uid'),
        headers: {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}
