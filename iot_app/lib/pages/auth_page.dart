import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const AuthPage({Key? key, this.onAuthSuccess}) : super(key: key);

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showLogin = true;

  void _toggleView() {
    setState(() {
      _showLogin = !_showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _showLogin
            ? LoginPage(
                onSwitchToRegister: _toggleView,
                onAuthSuccess: widget.onAuthSuccess,
              )
            : RegisterPage(
                onSwitchToLogin: _toggleView,
                onAuthSuccess: widget.onAuthSuccess,
              ),
      ),
    );
  }
}
