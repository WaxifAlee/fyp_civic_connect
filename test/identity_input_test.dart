import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_civic_connect/core/formatters/cnic_input_formatter.dart';
import 'package:fyp_civic_connect/utils/validators.dart';

TextEditingValue edit(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length));

void main() {
  test('both Pakistani mobile formats validate and normalize consistently', () {
    for (final phone in ['03091234567', '+923091234567', ' 03091234567 ']) {
      expect(Validators.validatePhone(phone), isNull);
      expect(Validators.normalizePhone(phone), '+923091234567');
    }
    for (final phone in [
      '',
      '0309123456',
      '030912345678',
      '+9203091234567',
      '+92309123456',
      '04212345678',
      '923091234567',
      '0309abc4567'
    ]) {
      expect(Validators.validatePhone(phone), isNotNull);
    }
  });

  const formatter = CnicInputFormatter();

  test('typing digits inserts CNIC separators and keeps the caret at the end',
      () {
    var current = edit('');
    for (final digit in '1234512345671'.split('')) {
      current = formatter.formatEditUpdate(current, edit(current.text + digit));
      expect(current.selection.baseOffset, current.text.length);
    }
    expect(current.text, '12345-1234567-1');
    expect(Validators.validateCNIC(current.text), isNull);
  });

  test('CNIC paste accepts plain or formatted digits and limits their length',
      () {
    for (final input in [
      '1234512345671',
      '12345-1234567-1',
      '12345 1234567 1'
    ]) {
      expect(formatter.formatEditUpdate(edit(''), edit(input)).text,
          '12345-1234567-1');
    }
    expect(formatter.formatEditUpdate(edit(''), edit('123451234567199')).text,
        '12345-1234567-1');
  });

  test('backspace across a separator deletes the preceding digit', () {
    final result = formatter.formatEditUpdate(
        edit('12345-1234567-1', 6), edit('123451234567-1', 5));
    expect(result.text, '12341-2345671');
    expect(result.selection.baseOffset, 4);
  });

  test('forward delete across a separator deletes the following digit', () {
    final result = formatter.formatEditUpdate(
        edit('12345-1234567-1', 5), edit('123451234567-1', 5));
    expect(result.text, '12345-2345671');
    expect(result.selection.baseOffset, 5);
  });

  test('deleting a block removes its unused separator', () {
    final result = formatter.formatEditUpdate(edit('12345-1'), edit('12345-'));
    expect(result.text, '12345');
    expect(result.selection.baseOffset, 5);
    expect(formatter.formatEditUpdate(result, edit('')).text, isEmpty);
  });

  test(
      'editing the middle preserves the cursor instead of moving it to the end',
      () {
    final result = formatter.formatEditUpdate(
        edit('12345-1234567-1', 7), edit('12345-9234567-1', 7));
    expect(result.text, '12345-9234567-1');
    expect(result.selection.baseOffset, 7);
  });

  test('an active composing range is left alone until text is committed', () {
    const composing = TextEditingValue(
        text: '123451',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 5, end: 6));
    expect(formatter.formatEditUpdate(edit('12345'), composing), composing);
    expect(
        formatter.formatEditUpdate(composing, edit('123451')).text, '12345-1');
  });
}
