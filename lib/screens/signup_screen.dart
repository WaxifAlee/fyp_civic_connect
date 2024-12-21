// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:fyp_civic_connect/widgets/back_button.dart';
import 'package:fyp_civic_connect/widgets/signup_form.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmpasswordController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  XFile? _profileImage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _uploadImage(XFile image) async {
    final client = Supabase.instance.client;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
    final response = await client.storage
        .from('profile-pictures')
        .upload(fileName, File(image.path));
    if (response.isNotEmpty) {
      return response;
    } else {
      return null;
    }
  }

  void _handleSignUp() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text, password: _passwordController.text);

      String? imageUrl;
      if (_profileImage != null) {
        imageUrl = await _uploadImage(_profileImage!);
      }

      final userData = {
        'full_name': _usernameController.text,
        'locations': _addressController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'password': _passwordController.text,
        'confirm_password': _confirmpasswordController.text,
        'role': 'citizen',
        'profile_picture': imageUrl,
        'created_at': DateTime.now(),
        'updated_at': DateTime.now(),
        'cnic': _cnicController.text,
        'gender': _genderController.text,
      };

      if (credential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user?.uid)
            .set(userData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User registered successfully! 🎉'),
          ),
        );
        FirebaseAuth.instance.currentUser!.sendEmailVerification();
        Navigator.pushNamed(context, '/verificationWaiting');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password is too weak'),
          ),
        );
      } else if (e.code == 'auth/email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email is already in use'),
          ),
        );
      } else if (e.code == 'auth/invalid-email') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing up: ${e.message}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.themeWhite,
        leading: const CustomBackButton(backTo: "/login"),
        title: Text(
          "Register an Account",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      backgroundColor: AppTheme.themeWhite,
      body: Padding(
        padding: const EdgeInsets.only(
            left: AppTheme.borderPadding + 8,
            right: AppTheme.borderPadding + 8),
        child: Center(
          child: SingleChildScrollView(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 25,
              ),
              Padding(
                padding: const EdgeInsets.all(0),
                child: Image(
                  image: const AssetImage('assets/images/signup.png'),
                  height: screenHeight * 0.3,
                  width: screenWidth * 0.9,
                ),
              ),
              SignupForm(
                  emailController: _emailController,
                  passwordController: _passwordController,
                  usernameController: _usernameController,
                  addressController: _addressController,
                  phoneController: _phoneController,
                  confirmPasswordController: _confirmpasswordController,
                  cnicController: _cnicController,
                  genderController: _genderController,
                  profilePictureController: TextEditingController(),
                  formKey: _formKey,
                  onSubmit: _handleSignUp,
                  onImagePicked: (image) {
                    setState(() {
                      _profileImage = image;
                    });
                  }),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Joined us before?",
                    style: TextStyle(color: AppTheme.themeGray),
                  ),
                  TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, "/login");
                      },
                      child: const Text(
                        "Login",
                        style: TextStyle(
                            color: AppTheme.themePurple,
                            fontWeight: FontWeight.bold),
                      ))
                ],
              )
            ],
          )),
        ),
      ),
    );
  }
}
