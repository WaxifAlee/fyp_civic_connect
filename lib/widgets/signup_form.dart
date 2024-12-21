// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import '../themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SignupForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController usernameController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController cnicController;
  final TextEditingController genderController;
  final TextEditingController profilePictureController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;
  final Function(XFile?) onImagePicked;

  const SignupForm(
      {super.key,
      required this.emailController,
      required this.passwordController,
      required this.confirmPasswordController,
      required this.usernameController,
      required this.formKey,
      required this.onSubmit,
      required this.addressController,
      required this.phoneController,
      required this.cnicController,
      required this.genderController,
      required this.profilePictureController,
      required this.onImagePicked});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  bool isPasswordVisible = false;
  XFile? _profileImage;
  bool _isCreatingAccount = false; // Add this state variable

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _profileImage = image;
    });
    widget.onImagePicked(_profileImage);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(children: [
        SizedBox(height: 6),

        // Profile Picture Picker Row with Icon
        Row(
          children: [
            Icon(Icons.image, color: AppTheme.themePlaceHolderText),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.themePlaceHolderText),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _profileImage == null
                      ? Center(
                          child: Text(
                            "Tap to select profile picture",
                            style: TextStyle(
                              color: AppTheme.themePlaceHolderText,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Image.file(
                          File(_profileImage!.path),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            )
          ],
        ),
        Row(
          children: [
            Icon(
              Icons.alternate_email,
              color: AppTheme.themePlaceHolderText,
            ),
            SizedBox(width: 12),
            Expanded(
                child: TextFormField(
              controller: widget.emailController,
              decoration: InputDecoration(
                  labelText: ' Email Address',
                  labelStyle: TextStyle(
                    color: AppTheme.themePlaceHolderText,
                    fontSize: 14,
                  )),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }

                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ))
          ],
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.person,
              color: AppTheme.themePlaceHolderText,
            ),
            SizedBox(width: 12),
            Expanded(
                child: TextFormField(
              controller: widget.usernameController,
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please Enter Your Full Name';
                }
                return null;
              },
              decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(
                    color: AppTheme.themePlaceHolderText,
                    fontSize: 14,
                  )),
            ))
          ],
        ),
        SizedBox(height: 6),

        // Password Field Row with Icon
        Row(
          children: [
            Icon(Icons.lock, color: AppTheme.themePlaceHolderText),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                  controller: widget.passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                      labelText: " Password",
                      labelStyle: TextStyle(
                        color: AppTheme.themePlaceHolderText,
                        fontSize: 14,
                      ),
                      suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppTheme.themePlaceHolderText,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          })),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  }),
            )
          ],
        ),
        SizedBox(height: 6),

        // Password Field Row with Icon
        Row(
          children: [
            Icon(Icons.lock, color: AppTheme.themePlaceHolderText),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                  controller: widget.confirmPasswordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: " Confirm Password",
                    labelStyle: TextStyle(
                      color: AppTheme.themePlaceHolderText,
                      fontSize: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    return null;
                  }),
            )
          ],
        ),
        SizedBox(height: 6),

        // Password Field Row with Icon
        Row(
          children: [
            Icon(Icons.location_city, color: AppTheme.themePlaceHolderText),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                  controller: widget.addressController,
                  keyboardType: TextInputType.streetAddress,
                  decoration: InputDecoration(
                    labelText: " Location/Address",
                    labelStyle: TextStyle(
                      color: AppTheme.themePlaceHolderText,
                      fontSize: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'House/Apt, Street, City';
                    }
                    return null;
                  }),
            )
          ],
        ),
        SizedBox(height: 6),

        // Password Field Row with Icon
        Row(
          children: [
            Icon(Icons.phone_outlined, color: AppTheme.themePlaceHolderText),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                  controller: widget.phoneController,
                  decoration: InputDecoration(
                    labelText: " Phone Number",
                    labelStyle: TextStyle(
                      color: AppTheme.themePlaceHolderText,
                      fontSize: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  }),
            )
          ],
        ),
        SizedBox(height: 6),

        // CNIC Field Row with Icon
        Row(
          children: [
            Icon(Icons.credit_card, color: AppTheme.themePlaceHolderText),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                  controller: widget.cnicController,
                  decoration: InputDecoration(
                    labelText: " CNIC (XXXXX-XXXXXXX-X)",
                    labelStyle: TextStyle(
                      color: AppTheme.themePlaceHolderText,
                      fontSize: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your CNIC';
                    }
                    if (value.length != 15) {
                      return 'CNIC must be 15 characters long';
                    }
                    return null;
                  }),
            )
          ],
        ),
        SizedBox(height: 6),

        // Gender Dropdown Row with Icon
        Row(
          children: [
            Icon(Icons.person_outline, color: AppTheme.themePlaceHolderText),
            SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: null,
                items: ['Male', 'Female', 'Other']
                    .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    widget.genderController.text = value!;
                  });
                },
                decoration: InputDecoration(
                  labelText: " Gender",
                  labelStyle: TextStyle(
                    color: AppTheme.themePlaceHolderText,
                    fontSize: 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your gender';
                  }
                  return null;
                },
              ),
            )
          ],
        ),

        SizedBox(height: 6),

        SizedBox(height: 16),

        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 0, // Horizontal spacing
          runSpacing: 0, // Vertical spacing
          children: [
            const Text(
              "By signing up, you will agree to our ",
              style: TextStyle(fontSize: 12),
            ),
            GestureDetector(
              onTap: () {},
              child: Text(
                "Terms & Conditions",
                style: TextStyle(
                  color: AppTheme.themePurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Text(" and "),
            GestureDetector(
              onTap: () {},
              child: Text(
                "Privacy Policy",
                style: TextStyle(
                  color: AppTheme.themePurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 42,
          child: TextButton(
            onPressed: () {
              if (widget.formKey.currentState!.validate()) {
                setState(() {
                  _isCreatingAccount =
                      true; // Set to true when button is pressed
                });
                widget.onSubmit();
              } else {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text("Validation Error"),
                      content: Text(
                        "Please fill out all required fields and ensure the password meets the required criteria.",
                        style: TextStyle(fontSize: 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("OK"),
                        )
                      ],
                    );
                  },
                );
              }
            },
            style: ButtonStyle(
                backgroundColor:
                    const WidgetStatePropertyAll(AppTheme.themePurple),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ))),
            child: Text(
              _isCreatingAccount
                  ? "Creating Account"
                  : "Sign Up", // Change text based on state
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),
        ),
      ]),
    );
  }
}
