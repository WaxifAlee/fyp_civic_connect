// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import '../themes/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/back_button.dart';

class SignupForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController usernameController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const SignupForm(
      {super.key,
      required this.emailController,
      required this.passwordController,
      required this.confirmPasswordController,
      required this.usernameController,
      required this.formKey,
      required this.onSubmit,
      required this.addressController,
      required this.phoneController});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  bool isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(children: [
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
                  labelText: ' Email ID',
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
            Icon(Icons.phone_outlined, color: AppTheme.themePlaceHolderText),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                  controller: widget.phoneController,
                  decoration: InputDecoration(
                    labelText: " Phone",
                    labelStyle: TextStyle(
                      color: AppTheme.themePlaceHolderText,
                      fontSize: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  }),
            )
          ],
        ),

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
              onTap: () {
                Navigator.pushNamed(context, "/signUp");
              },
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
              onTap: () {
                Navigator.pushNamed(context, "/signUp");
              },
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
            child: const Text(
              "Sign Up",
              style: TextStyle(
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
