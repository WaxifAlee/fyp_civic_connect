import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_civic_connect/screens/login_screen.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;

  /// Function to verify current password and update to new password
  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Fluttertoast.showToast(msg: "No user is currently signed in.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Re-authenticate the user with the current password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Update to the new password
      await user.updatePassword(_newPasswordController.text);

      Fluttertoast.showToast(
        msg: "Password updated successfully!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.mintGreen,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // Clear the text fields after success
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      FirebaseAuth.instance.signOut();
      globalCitizenUser = null;

      // Navigate back to the login screen
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => LoginScreen()));
    } on FirebaseAuthException catch (e) {
      String errorMsg = "An error occurred";
      if (e.code == 'wrong-password') {
        errorMsg = "The current password is incorrect.";
      } else if (e.code == 'weak-password') {
        errorMsg = "The new password is too weak.";
      } else {
        errorMsg = e.message ?? "An error occurred";
      }
      Fluttertoast.showToast(msg: errorMsg, backgroundColor: AppTheme.themeRed);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Change Password',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: Color(0xff5A55CA),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                // Icon or Illustration
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Color(0xffB2AFEF),
                  child: Icon(Icons.lock_reset, size: 70, color: Colors.white),
                ),
                SizedBox(height: 30),
                Text(
                  "Change Your Password",
                  style: GoogleFonts.poppins(
                    color: Color(0xff333333),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Ensure your account is protected with a strong password.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 30),
                // Current Password Field
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Current Password",
                    filled: true,
                    fillColor: Color(0xffF5F5F5),
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter your current password";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                // New Password Field
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "New Password",
                    filled: true,
                    fillColor: Color(0xffF5F5F5),
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter a new password";
                    } else if (value.length < 6) {
                      return "Password must be at least 6 characters";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Confirm New Password",
                    filled: true,
                    fillColor: Color(0xffF5F5F5),
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Confirm your new password";
                    } else if (value != _newPasswordController.text) {
                      return "Passwords do not match";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 40),
                // Update Password Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff5A55CA),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "Update Password",
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
