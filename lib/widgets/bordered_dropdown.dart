import 'package:flutter/material.dart';

class BorderedDropdown extends StatelessWidget {
  final String? value; // Currently selected value
  final String hintText; // Hint for the dropdown
  final List<String> items; // List of dropdown items
  final ValueChanged<String?> onChanged; // Callback for when the value changes

  const BorderedDropdown({
    Key? key,
    required this.value,
    required this.hintText,
    required this.items,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hintText),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.blue, width: 2.0),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
