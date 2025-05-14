import '../themes/app_theme.dart';
import 'package:flutter/material.dart';

class CustomBackButton extends StatelessWidget {
  final String backTo;
  final bool replaceRoute;

  const CustomBackButton(
      {super.key, required this.backTo, this.replaceRoute = true});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: const ButtonStyle(iconSize: WidgetStatePropertyAll(24)),
      icon: const Icon(Icons.arrow_back,
          color: AppTheme.themeGray, size: 32, weight: 600),
      onPressed: () {
        if (replaceRoute) {
          Navigator.pushReplacementNamed(context, backTo);
        } else {
          Navigator.pushNamed(context, backTo);
        }
      },
    );
  }
}
