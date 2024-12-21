import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class VerificationWaitingScreen extends StatefulWidget {
  @override
  _VerificationWaitingScreenState createState() =>
      _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState extends State<VerificationWaitingScreen> {
  bool _isButtonDisabled = false;

  void _resendVerificationLink() async {
    setState(() {
      _isButtonDisabled = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }

    await Future.delayed(Duration(minutes: 2));
    setState(() {
      _isButtonDisabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            icon: Icon(Icons.arrow_back)),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified,
              size: 80,
              color: AppTheme.themePurple,
            ),
            SizedBox(height: 20),
            Text(
              'Verify your account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'A Verification link has been sent to your email address. Please click it to activate your account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isButtonDisabled ? null : _resendVerificationLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.themePurple,
                iconColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 16),
              ),
              child: Text(
                _isButtonDisabled
                    ? 'Resend in 2 minutes'
                    : 'Resend Verification Link',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
