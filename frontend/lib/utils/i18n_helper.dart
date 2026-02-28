import 'dart:convert';
// ============================================================================
// [kIsWeb 미사용으로 인한 패키지 비활성화]
// 원래 웹(kIsWeb) 여부를 체크하기 위해 사용했던 foundation 패키지임.
// 현재는 다국어 로드 시 웹과 모바일 모두 동일한 경로('assets/i18n/...')를
// 사용하도록 통합했기 때문에, 더 이상 분기 처리가 필요 없어 주석 처리함.
// ============================================================================
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 다국어 지원 Helper
/// assets/i18n/{lang}.json 파일을 로드하여 텍스트 제공
class I18nHelper {
  final Locale locale;
  Map<String, String> _localizedStrings = {};

  I18nHelper(this.locale);

  /// JSON 파일 로드
  /// Flutter 웹에서는 rootBundle이 경로 앞에 assets/를 한 번 더 붙여
  /// assets/assets/i18n/... 가 되므로, 웹일 때는 'i18n/...'만 전달.
  Future<bool> load() async {
    try {
      // ============================================================================
      // [웹 빌드 다국어(app_name) 노출 트러블슈팅 기록]
      // 기존 코드는 웹(kIsWeb)일 때 경로 앞의 'assets/'를 빼도록 작성되어 있었음.
      // 하지만 현재 플루터의 rootBundle은 물리적 폴더 구조가 아닌,
      // pubspec.yaml에 등록된 이름 그대로를 고유 키(Key)값으로 사용하여 파일을 찾음.
      // 따라서 웹/앱 구분 없이 무조건 'assets/i18n/...' 형태로 동일하게 호출해야 함.
      // (이 꼼수 코드 때문에 웹 빌드 후 Nginx 서버에서 파일을 찾지 못하고 app_name이 출력됨)
      // ============================================================================
      /* ❌ 기존 오류 코드 (주석 처리)
      final path = kIsWeb
          ? 'i18n/${locale.languageCode}.json'
          : 'assets/i18n/${locale.languageCode}.json';
      String jsonString = await rootBundle.loadString(path);
      */
      final path = 'assets/i18n/${locale.languageCode}.json';
      String jsonString = await rootBundle.loadString(path);

      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 키에 해당하는 번역 텍스트 반환
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  /// 짧은 형태로 사용 가능
  String t(String key) => translate(key);

  /// BuildContext에서 쉽게 접근하기 위한 Helper
  /// 로컬이 아직 로드되지 않았을 수 있으므로 null이면 미로드 헬퍼 반환(키 그대로 표시).
  static I18nHelper of(BuildContext context) {
    final helper = Localizations.of<I18nHelper>(context, I18nHelper);
    if (helper != null) return helper;
    try {
      final locale = Localizations.localeOf(context);
      return I18nHelper(locale);
    } catch (_) {
      return I18nHelper(const Locale('ko', 'KR'));
    }
  }
}

/// 다국어 Delegate
class I18nDelegate extends LocalizationsDelegate<I18nHelper> {
  const I18nDelegate();

  @override
  bool isSupported(Locale locale) {
    // 지원하는 언어 코드
    return ['ko', 'en', 'vi'].contains(locale.languageCode);
  }

  @override
  Future<I18nHelper> load(Locale locale) async {
    I18nHelper helper = I18nHelper(locale);
    await helper.load();
    return helper;
  }

  @override
  bool shouldReload(I18nDelegate old) => false;
}
