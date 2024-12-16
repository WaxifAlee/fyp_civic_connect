import '../themes/app_theme.dart';
import 'package:flutter/material.dart';

class LoginForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final void Function(String email, String password) onSubmit;
  bool isLoading;

  LoginForm(
      {super.key,
      required this.emailController,
      required this.passwordController,
      required this.formKey,
      required this.onSubmit,
      required this.isLoading});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Form(
        key: widget.formKey,
        child: Column(
          children: [
            // Email Field Row with Icon
            Row(
              children: [
                const Icon(
                  Icons.alternate_email,
                  color: AppTheme.themePlaceHolderText,
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                  controller: widget.emailController,
                  decoration: const InputDecoration(
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

            const SizedBox(height: 16),

            // Password Field Row with Icon
            Row(
              children: [
                const Icon(Icons.lock, color: AppTheme.themePlaceHolderText),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                      controller: widget.passwordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                          labelText: " Password",
                          labelStyle: const TextStyle(
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

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/reset_password');
                    }, // Go to Forgot Screen
                    child: const Text(
                      "Forgot Password?",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppTheme.themePurple,
                      ),
                    ))
              ],
            ),

            const SizedBox(height: 34),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: widget.isLoading
                    ? null
                    : () {
                        if (widget.formKey.currentState!.validate()) {
                          widget.onSubmit(
                            widget.emailController.text.trim(),
                            widget.passwordController.text.trim(),
                          );
                        }
                      },
                style: ButtonStyle(
                    backgroundColor:
                        const WidgetStatePropertyAll(AppTheme.themePurple),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ))),
                child: widget.isLoading
                    ? const Text(
                        "Signing in...",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      )
                    : const Text(
                        "Sign In",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
              ),
            ),
          ],
        ));
  }
}
