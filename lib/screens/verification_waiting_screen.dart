import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_civic_connect/screens/dashboard.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'dart:async';

class VerificationWaitingScreen extends StatefulWidget {
  const VerificationWaitingScreen({super.key});

  @override
  _VerificationWaitingScreenState createState() =>
      _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState extends State<VerificationWaitingScreen> {
  bool _isButtonDisabled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendVerificationLink() async {
    setState(() {
      _isButtonDisabled = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Error sending verification email. Please try again later.'),
          ),
        );
      }
    }

    await Future.delayed(Duration(minutes: 2));
    if (mounted) {
      setState(() {
        _isButtonDisabled = false;
      });
    }
  }

  void _startVerificationCheck() {
    // Check every 5 seconds
    _timer = Timer.periodic(Duration(seconds: 5), (timer) async {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser; // Get fresh user data
        if (user!.emailVerified) {
          _timer?.cancel();
          await _completeRegistration(user);
        }
      }
    });
  }

  Future<void> _completeRegistration(User user) async {
    try {
      // Get the pending user data
      final pendingDoc = await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(user.uid)
          .get();

      if (pendingDoc.exists) {
        final userData = pendingDoc.data()!;
        userData['email_verified'] = true;

        // Move data to active users collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(userData);

        // Delete from pending collection
        await FirebaseFirestore.instance
            .collection('pending_users')
            .doc(user.uid)
            .delete();

        // Update global user state
        await fetchAndSetCitizenUser(user.uid);

        // Navigate to dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => DashboardPage()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error completing registration. Please try again.'),
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Sign Out?'),
            content: Text('Do you want to sign out and return to login?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                },
                child: Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading:
              IconButton(onPressed: _onWillPop, icon: Icon(Icons.arrow_back)),
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
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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
      ),
    );
  }
}
