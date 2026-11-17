import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.autofillHints,
    this.password = false,
    this.helperText,
    this.hintText,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool password;
  final String? helperText;
  final String? hintText;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        obscureText: widget.password && !_visible,
        autocorrect: !widget.password &&
            widget.keyboardType != TextInputType.emailAddress,
        enableSuggestions: !widget.password,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        inputFormatters: widget.inputFormatters,
        scrollPadding: const EdgeInsets.all(32),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
          helperMaxLines: 4,
          hintText: widget.hintText,
          errorMaxLines: 4,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          prefixIcon: ExcludeSemantics(child: Icon(widget.icon)),
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: _visible ? 'Hide password' : 'Show password',
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  onPressed: widget.enabled
                      ? () => setState(() => _visible = !_visible)
                      : null,
                  icon: Icon(
                    _visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class AuthMessage extends StatelessWidget {
  const AuthMessage({super.key, required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        isError ? colors.onErrorContainer : colors.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: foreground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: foreground, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps every auth action usable at the Material minimum touch size.
ButtonStyle authTextButtonStyle() => TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

String? requiredAuthValue(String? value, String label) =>
    value == null || value.trim().isEmpty ? 'Enter your $label.' : null;

String? validateAuthEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
    return 'Enter a valid email address.';
  }
  return null;
}
