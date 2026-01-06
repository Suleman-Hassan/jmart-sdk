import 'package:flutter/services.dart';

class CNICInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length > 13) {
      digitsOnly = digitsOnly.substring(0, 13);
    }

    StringBuffer formatted = StringBuffer();

    for (int i = 0; i < digitsOnly.length; i++) {
      formatted.write(digitsOnly[i]);
      if (i == 4 || i == 11) {
        if (i != digitsOnly.length - 1) {
          formatted.write('-');
        }
      }
    }

    return TextEditingValue(
      text: formatted.toString(),
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
