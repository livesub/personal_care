import 'package:flutter/services.dart';

/// 아이디/비밀번호 입력 시 대문자 → 소문자 강제 변환 (문서 요구사항)
class LowercaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}

/// 휴대폰 번호 마스크: 010-1234-5678 (숫자만 입력, 하이픈 자동 삽입)
class PhoneMaskInputFormatter extends TextInputFormatter {
  static const int _maxDigits = 11; // 010xxxxxxxx

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > _maxDigits) {
      return oldValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 7) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    final offset = formatted.length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// 비밀번호 허용 문자: 영문 소문자, 숫자, 지정 특수문자만.
const String _passwordAllowedSpecials = "!@#\$%^&*()_+-=[]{}|;':\",./<>?`~";

bool passwordTextAllowed(String text) {
  for (final c in text.runes) {
    final ch = String.fromCharCode(c);
    if (_isLowerAlpha(ch) || _isDigit(ch) || _passwordAllowedSpecials.contains(ch)) continue;
    return false;
  }
  return true;
}

bool _isLowerAlpha(String c) => c.length == 1 && c.compareTo('a') >= 0 && c.compareTo('z') <= 0;
bool _isDigit(String c) => c.length == 1 && c.compareTo('0') >= 0 && c.compareTo('9') <= 0;

/// 비밀번호 검증: 10자 이상
bool passwordMeetsLength(String value) => value.length >= 10;

/// 비밀번호 검증: 영문 + 숫자 + 특수문자 각각 1개 이상
bool passwordMeetsComplexity(String value) {
  if (value.isEmpty) return false;
  bool hasLetter = false;
  bool hasDigit = false;
  bool hasSpecial = false;
  for (final c in value.runes) {
    final ch = String.fromCharCode(c);
    if (_isLowerAlpha(ch)) hasLetter = true;
    if (_isDigit(ch)) hasDigit = true;
    if (_passwordAllowedSpecials.contains(ch)) hasSpecial = true;
  }
  return hasLetter && hasDigit && hasSpecial;
}
