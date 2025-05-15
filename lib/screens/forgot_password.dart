// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});

  @override
  State<ForgotScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<ForgotScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void onSubmit() async {
    try {
      // Check if email exists and is verified
      var methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(_emailController.text);
      if (methods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("This email is not registered with us."),
          duration: Duration(seconds: 3),
        ));
        return;
      }

      // Get the user record from Firestore to check verification status
      var users = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text)
          .get();

      if (users.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("This email is not registered with us."),
          duration: Duration(seconds: 3),
        ));
        return;
      }

      // Send password reset email
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text);
      setState(() {
        _emailController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Password reset email sent"),
        duration: Duration(seconds: 3),
      ));
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      String message = "Failed to send reset email. Please try again.";
      if (e.code == 'user-not-found') {
        message = "This email is not registered with us.";
      } else if (e.code == 'invalid-email') {
        message = "Please enter a valid email address.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("An unexpected error occurred. Please try again."),
        duration: Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.themeWhite,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
      ),
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
                  "Forgot Password?",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.themeGray),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 12),
                  child: Image(
                    image: AssetImage('assets/images/ForgotPasswordImage.png'),
                    height: screenHeight * 0.5,
                    width: screenWidth * 1.5,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Text(
                      "Don't worry! It happens and we got you covered 😊 Please enter the email address associated with you account below."),
                ),
                SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.alternate_email,
                            color: AppTheme.themePlaceHolderText,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                                labelText: ' johnsmith@example.com',
                                labelStyle: TextStyle(
                                  color: AppTheme.themePlaceHolderText,
                                  fontSize: 14,
                                )),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }

                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ))
                        ],
                      ),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: TextButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              onSubmit();
                            }
                          },
                          style: ButtonStyle(
                              backgroundColor: const WidgetStatePropertyAll(
                                  AppTheme.themePurple),
                              shape:
                                  WidgetStatePropertyAll(RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ))),
                          child: const Text(
                            "Submit",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
