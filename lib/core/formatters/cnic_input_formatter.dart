import 'package:flutter/services.dart';

/// Formats 13 CNIC digits without moving the caret away from an edit.
class CnicInputFormatter extends TextInputFormatter {
  const CnicInputFormatter();

  static final _nonDigits = RegExp(r'[^0-9]');

  static String _digits(String text) => text.replaceAll(_nonDigits, '');

  static int _digitsBefore(String text, int offset) =>
      _digits(text.substring(0, offset.clamp(0, text.length).toInt())).length;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;

    var digits = _digits(newValue.text);
    var base = _digitsBefore(newValue.text, newValue.selection.baseOffset);
    var extent = _digitsBefore(newValue.text, newValue.selection.extentOffset);

    // Treat deleting an inserted separator as deleting the adjacent digit.
    // Otherwise the formatter would put the dash straight back.
    final cursor = newValue.selection.baseOffset;
    if (oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        oldValue.text.length == newValue.text.length + 1 &&
        _digits(oldValue.text) == digits &&
        cursor >= 0 &&
        cursor < oldValue.text.length &&
        oldValue.text[cursor] == '-') {
      final backspace = oldValue.selection.baseOffset == cursor + 1;
      final forwardDelete = oldValue.selection.baseOffset == cursor;
      final index = backspace ? base - 1 : base;
      if ((backspace || forwardDelete) && index >= 0 && index < digits.length) {
        digits = digits.replaceRange(index, index + 1, '');
        if (backspace) {
          base--;
          extent--;
        }
      }
    }

    if (digits.length > 13) digits = digits.substring(0, 13);
    final text = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 5 || i == 12) text.write('-');
      text.write(digits[i]);
    }

    int formattedOffset(int offset) {
      final count = offset.clamp(0, digits.length).toInt();
      return count + (count > 5 ? 1 : 0) + (count > 12 ? 1 : 0);
    }

    return newValue.copyWith(
        text: text.toString(),
        selection: newValue.selection.isValid
            ? TextSelection(
                baseOffset: formattedOffset(base),
                extentOffset: formattedOffset(extent),
                affinity: newValue.selection.affinity,
                isDirectional: newValue.selection.isDirectional)
            : TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty);
  }
}
