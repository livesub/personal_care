import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 언어 설정 Provider
/// 다국어 지원: ko(한국어), en(영어), vi(베트남어)
/// 
/// 사용법:
/// - Dropdown에서 언어 선택 시 앱 전체 언어 변경
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ko', 'KR')); // 초기값: 한국어

  /// 언어 변경
  void changeLocale(String languageCode) {
    switch (languageCode) {
      case 'ko':
        state = const Locale('ko', 'KR');
        break;
      case 'en':
        state = const Locale('en', 'US');
        break;
      case 'vi':
        state = const Locale('vi', 'VN');
        break;
      default:
        state = const Locale('ko', 'KR');
    }
  }
}

/// 언어 Provider 인스턴스
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
