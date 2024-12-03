import 'package:fyp_civic_connect/screens/dashboard.dart';

import 'package:fyp_civic_connect/screens/forgot_password.dart';
import 'package:fyp_civic_connect/screens/report_issue_screen.dart';

import '../screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CivicConnectApp());
}

class CivicConnectApp extends StatelessWidget {
  const CivicConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CivicConnect',
      initialRoute: '/dashboard',
      theme: ThemeData(
        primaryColor: const Color(0XFF6C63FF),
      ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => WelcomeScreen(),
        '/signUp': (context) => SignupScreen(),
        '/reset_password': (context) => ForgotScreen(),
        '/report_issue': (context) => ReportIssueScreen(),
        '/dashboard': (context) => DashboardPage(),
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Fetch screen size to calculate dynamic heights and widths
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          // Top section with colorful background (35% of screen height)
          Expanded(
            flex: 30,
            child: Center(
              child: Image.asset(
                'assets/images/Logo.png',
                height: screenHeight * 0.2, // 20% of the screen height
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.05), // 5% vertical spacing
          Expanded(
            flex: 70, // Adjusted flex for the bottom section
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.only(
                      topLeft:
                          Radius.circular(screenWidth * 0.2), // 20% of width
                      topRight: Radius.circular(screenWidth * 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        spreadRadius: screenWidth * 0.02,
                        blurRadius: screenWidth * 0.05,
                        offset: const Offset(0, -15),
                      ),
                    ],
                  ),
                  child: CarouselSlider(
                    options: CarouselOptions(
                      height: double.infinity,
                      viewportFraction: 1.0,
                      enableInfiniteScroll: false,
                      autoPlay: false,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                    ),
                    items: [
                      buildCarouselItem(
                        context,
                        'assets/images/report_issues.png',
                        'Report Issues Easily',
                        'Snap a photo, add a description, and tag the location. Reporting local problems has never been simpler.',
                        screenHeight,
                        screenWidth,
                      ),
                      buildCarouselItem(
                        context,
                        'assets/images/stay_informed.png',
                        'Stay Informed',
                        'Track the progress of your report and receive updates from local authorities in real-time.',
                        screenHeight,
                        screenWidth,
                      ),
                      buildCarouselItem(
                        context,
                        'assets/images/improve_community.png',
                        'Improve Your Community',
                        'Join hands to create a safer, cleaner, and better community.',
                        screenHeight,
                        screenWidth,
                      ),
                    ],
                  ),
                ),
                if (_currentIndex != 2)
                  Positioned(
                    left: 0,
                    top: screenHeight * 0.58, // Dynamic position
                    right: 0,
                    bottom: 0,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        "Skip",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: screenHeight * 0.06,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Container(
                        width: _currentIndex == index
                            ? screenWidth * 0.04
                            : screenWidth * 0.02,
                        height: _currentIndex == index
                            ? screenWidth * 0.04
                            : screenWidth * 0.02,
                        margin: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.01,
                            horizontal: screenWidth * 0.01),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == index
                              ? const Color(0xFF6C63FF)
                              : Colors.grey,
                        ),
                      );
                    }),
                  ),
                ),
                if (_currentIndex == 2)
                  Positioned(
                    bottom: screenHeight * 0.06,
                    left: screenWidth * 0.05,
                    right: screenWidth * 0.05,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                        backgroundColor: const Color(0xFF6C63FF),
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCarouselItem(BuildContext context, String imagePath, String title,
      String subtitle, double screenHeight, double screenWidth) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: screenHeight * 0.07), // Dynamic spacing
        Image.asset(imagePath,
            height: screenHeight * 0.3), // Image height based on screen
        SizedBox(height: screenHeight * 0.03),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
          ),
        ),
        SizedBox(height: screenHeight * 0.03),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.12),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2F2E41),
                fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}
