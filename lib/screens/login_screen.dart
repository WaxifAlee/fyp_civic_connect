// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../widgets/back_button.dart';
import '../widgets/login_form.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(String email, String password) async {
    try {
      UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      print("Userd signed in: ${credential.user?.phoneNumber}");
    } catch (e) {
      print("Sign-in Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppTheme.themeWhite,
          leading: CustomBackButton(backTo: "/home")),
      backgroundColor: AppTheme.themeWhite,
      body: Padding(
        padding: EdgeInsets.only(
            left: AppTheme.borderPadding, right: AppTheme.borderPadding),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Sign In to Your Account",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.themeGray),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 12),
                  child: Image(
                    image: AssetImage('assets/images/login.png'),
                    height: screenHeight * 0.3,
                    width: screenWidth * 0.9,
                  ),
                ),
                LoginForm(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    formKey: _formKey,
                    onSubmit: _handleLogin),

                SizedBox(height: 24),

                // Divider
                const Row(
                  children: [
                    Expanded(
                      child: Divider(
                        thickness: 0.7, // You can adjust the thickness
                        color: AppTheme
                            .themePlaceHolderText, // Change the color if needed
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.0), // Add some space around the text
                      child: Text(
                        "OR", // Your text in between
                        style: TextStyle(
                          color:
                              AppTheme.themePlaceHolderText, // Style as needed
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        thickness: 0.7,
                        color: AppTheme.themePlaceHolderText,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: TextButton(
                    onPressed: () {},
                    // Googe Auth API from here

                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(AppTheme.themeSecondaryGray),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Google icon on the left
                        Image.asset(
                          'assets/images/google_logo.png',
                          height: 30, // Set the size of the Google icon
                          width: 30,
                        ),
                        SizedBox(width: 8), // Space between the icon and text
                        Expanded(
                          child: Text(
                            "Sign In with Google",
                            textAlign: TextAlign
                                .center, // Center the text within the remaining space
                            style: TextStyle(
                              color: AppTheme.themePlaceHolderText,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New to CivicConnect?"),
                    TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, "/signUp");
                        },
                        child: Text(
                          "Register",
                          style: TextStyle(
                              color: AppTheme.themePurple,
                              fontWeight: FontWeight.bold),
                        ))
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
