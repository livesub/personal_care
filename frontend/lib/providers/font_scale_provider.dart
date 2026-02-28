import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 글자 크기 조절 Provider
/// 접근성(Accessibility) 기능: 고령층 사용자를 위한 폰트 크기 조절
/// 
/// 사용법:
/// - 버튼 클릭 시 1.0배 -> 1.2배 -> 1.5배로 순환
/// - 앱 전체에 적용됨
class FontScaleNotifier extends StateNotifier<double> {
  FontScaleNotifier() : super(1.0); // 초기값: 기본 크기

  /// 폰트 크기를 다음 단계로 변경
  /// 1.0배 -> 1.2배 -> 1.5배 -> 1.0배 (순환)
  void toggleScale() {
    if (state == 1.0) {
      state = 1.2; // 20% 증가
    } else if (state == 1.2) {
      state = 1.5; // 50% 증가
    } else {
      state = 1.0; // 기본으로 복귀
    }
  }

  /// 특정 크기로 직접 설정
  void setScale(double scale) {
    state = scale;
  }
}

/// 글자 크기 Provider 인스턴스
/// 전역에서 접근 가능
final fontScaleProvider = StateNotifierProvider<FontScaleNotifier, double>((ref) {
  return FontScaleNotifier();
});
