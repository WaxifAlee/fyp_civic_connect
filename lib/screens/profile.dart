import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fyp_civic_connect/screens/change_password_screen.dart';
import 'package:fyp_civic_connect/screens/dashboard.dart';
import 'package:fyp_civic_connect/screens/login_screen.dart';
import 'package:fyp_civic_connect/services/user_service.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  Future<void> signOutUser(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    globalCitizenUser = null; // Clear the global object
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Account Deletion"),
          content: Text(
              "Are you sure you want to delete your account? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirm
              child: Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    // If user cancels, stop here
    if (!confirmDelete) return;

    try {
      // Delete the user account from Firebase Authentication
      await user?.delete();

      // Optionally delete user data from Firestore/Realtime DB
      // Example (if using Firestore):
      // await FirebaseFirestore.instance.collection('users').doc(user?.uid).delete();

      // Show success toast
      Fluttertoast.showToast(
        msg: "Account deleted successfully!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // Navigate user to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      // If there's an error (e.g., recent sign-in required)
      if (e.code == 'requires-recent-login') {
        Fluttertoast.showToast(
          msg: "Please re-authenticate to delete your account.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Failed to delete account: ${e.message}",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "An unexpected error occurred.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    bool confirmSignOut = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Sign Out"),
          content: Text("Are you sure you want to sign out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirm
              child: Text(
                "Sign Out",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmSignOut) {
      await signOutUser(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? userName = globalCitizenUser!.fullName ?? "User Name";
    String? userEmail = globalCitizenUser!.email ?? "user@example.com";
    final displayPicture = globalCitizenUser!.displayPicture;
    return Scaffold(
      bottomNavigationBar: CustomNavBarCurved(),
      appBar: AppBar(
        title: Text('Profile'),
        leading: IconButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardPage(),
              ),
            );
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),

              // Profile Picture, Name, and Email
              CircleAvatar(
                radius: 70,
                backgroundColor: Color(0xffB2AFEF),
                child: CircleAvatar(
                  radius: 66,
                  backgroundImage: NetworkImage(
                      "https://vlkfmraxbpwctukymsyt.supabase.co/storage/v1/object/public/$displayPicture"),
                ),
              ),
              SizedBox(height: 12),
              Text(
                userName,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                userEmail,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.themeGray,
                ),
              ),
              SizedBox(height: 20),

              // Edit Profile and Sign Out Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // ElevatedButton(
                  //   onPressed: () {
                  //     // Edit Profile Logic
                  //   },
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: AppTheme.themeGray,
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //     padding:
                  //         EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  //   ),
                  //   child: Text(
                  //     'Edit Profile',
                  //     style: GoogleFonts.poppins(
                  //       color: AppTheme.themeWhite,
                  //       fontWeight: FontWeight.normal,
                  //       fontSize: 14,
                  //     ),
                  //   ),
                  // ),
                  // SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () =>
                        _confirmSignOut(context), // Use the new method
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.themePink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 42, vertical: 20),
                    ),
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30),

              // User Information Section
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 32.0),
                  child: Text(
                    'User Information',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF545454),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // User Information Card
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Color(0xFFEAEEF1),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                      color: Colors.grey, width: 1), // Add stroke border
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    buildUserInfoRow(Icons.person, userName),
                    Divider(),
                    buildUserInfoRow(Icons.email, userEmail),
                    Divider(),
                    buildUserInfoRow(
                        Icons.phone, globalCitizenUser!.phone ?? "N/A"),
                    Divider(),
                    buildUserInfoRow(Icons.location_on,
                        globalCitizenUser!.location ?? "No Address Provided"),
                    Divider(),
                    buildUserInfoRow(Icons.credit_card,
                        globalCitizenUser!.cnic ?? "N/A"), // CNIC
                    Divider(),
                    buildUserInfoRow(Icons.person_outline,
                        globalCitizenUser!.gender ?? "N/A"), // Gender
                    Divider(),
                    buildUserInfoRow(Icons.calendar_today,
                        globalCitizenUser!.joinDate ?? "N/A"), // Joining Date
                  ],
                ),
              ),

              SizedBox(height: 20),

              // User Actions Section
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 32.0),
                  child: Text(
                    'User Actions',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF545454),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // User Actions Card
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Color(0xFFEAEEF1),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                      color: Colors.grey, width: 1), // Add stroke border
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    buildUserActionRow(
                      Icons.lock_outline,
                      'Change Password',
                      Colors.black87,
                      () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ChangePasswordScreen()));
                      },
                    ),
                    Divider(),
                    buildUserActionRow(
                      Icons.delete_outline,
                      'Delete Account',
                      Colors.redAccent,
                      () => _deleteAccount(context),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build user information rows
  Widget buildUserInfoRow(IconData icon, String text) {
    return Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ));
  }

  // Helper to build user action rows
  Widget buildUserActionRow(
      IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(top: 6, bottom: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xff838ea1),
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
