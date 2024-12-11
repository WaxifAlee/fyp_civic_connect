import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/screens/dashboard.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import '../screens/login_screen.dart';

class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirebaseLoginStatus();
  }

  Future<void> _checkFirebaseLoginStatus() async {
    // Simulate a loading delay
    await Future.delayed(Duration(seconds: 4));

    // Get the current Firebase user
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is signed in, navigate to Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => DashboardPage(
                  user: user,
                )),
      );
    } else {
      // User is not signed in, navigate to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themePurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/Logo.png",
              width: 400,
              height: 250,
            ),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              "Hang on while we try to get you started...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
