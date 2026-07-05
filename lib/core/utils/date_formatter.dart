import 'package:flutter/services.dart';

class DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the user deleted text, let them do it
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    // Strip out everything except numbers
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('.');
      }
      buffer.write(digitsOnly[i]);
    }

    // If the user manually typed a dot at a valid boundary (after 2 or 4 digits), ensure it is preserved.
    if (newValue.text.endsWith('.') && (digitsOnly.length == 2 || digitsOnly.length == 4)) {
      buffer.write('.');
    }

    var string = buffer.toString();
    if (string.length > 10) {
      string = string.substring(0, 10);
    }

    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

DateTime? parseFormattedDate(String text) {
  if (text.length != 10) return null;
  final parts = text.split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  if (year < 1900 || year > DateTime.now().year + 5) return null;
  try {
    final date = DateTime(year, month, day);
    if (date.year == year && date.month == month && date.day == day) {
      return date;
    }
  } catch (_) {}
  return null;
}
