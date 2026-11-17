import 'package:flutter/material.dart';

/// Validates once and guides the citizen to the first field needing attention.
bool validateAndReveal(FormState? form) {
  if (form == null) return false;
  final invalid = form.validateGranularly();
  if (invalid.isEmpty) return true;
  final first = invalid.first;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!first.mounted) return;
    EditableText? editable;
    void findEditable(Element element) {
      if (editable != null) return;
      if (element.widget case final EditableText field) {
        editable = field;
      } else {
        element.visitChildElements(findEditable);
      }
    }

    (first.context as Element).visitChildElements(findEditable);
    editable?.focusNode.requestFocus();
    Scrollable.ensureVisible(first.context,
        alignment: .15,
        duration: MediaQuery.disableAnimationsOf(first.context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic);
  });
  return false;
}
