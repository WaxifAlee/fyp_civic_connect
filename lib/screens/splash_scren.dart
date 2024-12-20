import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/main.dart';
import 'package:fyp_civic_connect/screens/profile.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
// Your dashboard or next screen
import 'login_screen.dart'; // Optional, for unauthenticated users
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String randomFact = '';

  @override
  void initState() {
    super.initState();
    randomFact = _getRandomFact();
    _navigateToNextScreen();
  }

  // Generate a random fact from a predefined list
  String _getRandomFact() {
    final List<String> facts = [
      "Effective community involvement can resolve issues faster. 🚀",
      "Local governments rely on community feedback for better services. 🏛️",
      "Community reporting systems save time and resources. ⏱️",
      "Reporting potholes can reduce accidents by 30%. 🛞",
      "Clean streets improve public health and well-being. 🧹",
      "Lighting up dark streets can reduce crime rates by 20%. 💡",
      "Engaging in community cleanups fosters unity. 🤝",
      "Smart reporting apps simplify local issue resolution. 📱",
      "Graffiti removal boosts community morale. 🎨",
      "Proper waste disposal prevents water contamination. 🚮",
      "Road safety issues can be identified through citizen reports. 🚧",
      "Better drainage systems reduce flooding during rains. 🌧️",
      "Tree planting drives enhance air quality in communities. 🌳",
      "Volunteering increases social cohesion. ❤️",
      "Early reporting of leaks saves water resources. 💧",
      "Community watchdogs help curb vandalism. 👀",
      "Local participation strengthens governance. ✊",
      "Efficient waste management keeps neighborhoods clean. 🗑️",
      "Safe parks encourage family outings. 🛝",
      "Noise pollution monitoring improves urban living. 🔇",
      "Timely streetlight repair enhances public safety. 🌙",
      "Open drains are a breeding ground for diseases. ⚠️",
      "Transparent local policies build citizen trust. 📝",
      "Punctual issue reporting keeps cities vibrant. 📌",
      "Digital tools empower citizens to take action. 🌐",
    ];

    return facts[Random().nextInt(facts.length)];
  }

  Future<void> _navigateToNextScreen() async {
    try {
      // Simulate a delay (e.g., for splash screen or initialization)
      await Future.delayed(Duration(seconds: 1));

      // Check authentication status
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        try {
          // Fetch user data
          await fetchAndSetCitizenUser(currentUser.uid);

          // Navigate to DashboardPage if authenticated and user data is fetched
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => Profile(),
            ),
          );
        } catch (fetchError) {
          // Handle errors during user data fetching
          print('Error fetching user data: $fetchError');
          _showErrorDialog('Failed to load user data. Please try again.');
          await FirebaseAuth.instance.signOut();
        }
      } else {
        // Navigate to LoginScreen if the user is not authenticated
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => WelcomeScreen()),
        );
      }
    } catch (e) {
      // Handle any other errors (e.g., Firebase issues, unexpected crashes)
      print('Error during navigation: $e');
      _showErrorDialog('An unexpected error occurred. Please restart the app.');
    }
  }

  // Helper function to show an error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Select a random fact to display

    return Scaffold(
      backgroundColor: AppTheme.softPurple, // Adjust background color if needed
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Centered content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Image.asset(
                  'assets/images/Logo.png', // Path to your logo in the assets folder
                  height: 250.0, // Adjust the size of the logo
                  width: 250.0,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 20), // Space between logo and loader

                // Loader
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white), // Loader color
                  strokeWidth: 3.0, // Adjust thickness
                ),
                SizedBox(height: 20),

                // Optional: Loading text
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.themeWhite, // Text color
                  ),
                ),
              ],
            ),
          ),

          // Spacer ensures the fact is at the bottom
          Padding(
              padding: const EdgeInsets.only(
                  right: 16.0,
                  left: 16,
                  bottom: 0), // Add some margin from edges
              child: Column(
                children: [
                  Text(
                    "💡 Did You Know? ",
                    style: GoogleFonts.poppins(color: AppTheme.themeWhite),
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Text(
                    randomFact,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.themeWhite,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )),
        ],
      ),
    );
  }
}
