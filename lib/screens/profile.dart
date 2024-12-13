import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/widgets/curved_bottomnavbar_widget.dart';

class Profile extends StatelessWidget {
  final User? user;
  const Profile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CustomNavBarCurved(),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
        title: Text('Profile'),
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User profile image
              CircleAvatar(
                radius: 90,
                backgroundColor: Color(0xffB2AFEF),
                child: CircleAvatar(
                  radius: 84,
                  backgroundImage: NetworkImage(
                      "https://avatar.iran.liara.run/username?username=Wasif+Ali"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
