import 'dart:convert';
import 'package:http/http.dart' as http;

/// Quick test script to check MongoDB API endpoints
/// Run with: dart test_mongo_api.dart

const String API_BASE = 'https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app';

void main() async {
  print('🧪 Testing MongoDB API...\n');

  // Test 1: Check if API is reachable
  print('1️⃣ Testing API health...');
  try {
    final response = await http.get(Uri.parse('$API_BASE/'));
    print('   Status: ${response.statusCode}');
    print('   Response: ${response.body}\n');
  } catch (e) {
    print('   ❌ Error: $e\n');
  }

  // Test 2: Try to get all users (if endpoint exists)
  print('2️⃣ Testing /users endpoint...');
  try {
    final response = await http.get(Uri.parse('$API_BASE/users'));
    print('   Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   Users found: ${data is List ? data.length : 'N/A'}');
      if (data is List && data.isNotEmpty) {
        print('   Sample user: ${data[0]}');
      }
    } else {
      print('   Response: ${response.body}');
    }
    print('');
  } catch (e) {
    print('   ❌ Error: $e\n');
  }

  // Test 3: Test login with your credentials
  print('3️⃣ Testing login...');
  try {
    final response = await http.post(
      Uri.parse('$API_BASE/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': 'sookwern99@gmail.com',
        'password': 'YOUR_PASSWORD_HERE', // Replace with actual password
      }),
    );
    print('   Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   ✅ Login successful!');
      print('   User ID: ${data['userId'] ?? data['uid']}');
      print('   Token: ${data['token']?.substring(0, 20)}...');
    } else {
      print('   Response: ${response.body}');
    }
    print('');
  } catch (e) {
    print('   ❌ Error: $e\n');
  }

  // Test 4: Check available API routes
  print('4️⃣ Common API endpoints to try:');
  print('   GET  $API_BASE/');
  print('   POST $API_BASE/auth/login');
  print('   POST $API_BASE/auth/register');
  print('   GET  $API_BASE/users');
  print('   GET  $API_BASE/users/:userId');
  print('   POST $API_BASE/getRecords');
  print('   POST $API_BASE/markCompleted');
}
