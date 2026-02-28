import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/font_scale_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/login_form_provider.dart';
import 'services/api_service.dart';
import 'utils/i18n_helper.dart';

/// Personal Care 앱 시작점
/// .cursorrules 규칙 적용:
/// - Riverpod 상태 관리
/// - GoRouter 라우팅
/// - Material 3 디자인
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PersonalCareApp(),
    ),
  );
}

class PersonalCareApp extends ConsumerWidget {
  const PersonalCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 401 시 admin 세션 찌꺼기 제거 후 라우터가 로그인으로 강제 리다이렉트
    ApiService.on401Callback = () => ref.read(authProvider.notifier).clearSession();

    final currentLocale = ref.watch(localeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => I18nHelper.of(context).t('app_name'),
      debugShowCheckedModeBanner: false,
      
      // Material 3 테마 적용 + 글자 크기 반영 (null fontSize 시 assertion 방지)
      theme: AppTheme.lightTheme.copyWith(
        textTheme: AppTheme.textThemeWithScale(AppTheme.lightTheme.textTheme, fontScale),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        textTheme: AppTheme.textThemeWithScale(AppTheme.darkTheme.textTheme, fontScale),
      ),
      themeMode: ThemeMode.system,
      
      // GoRouter 설정
      routerConfig: AppRouter.router,
      
      // 다국어 지원 설정
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        I18nDelegate(), // 커스텀 다국어 Delegate
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
        Locale('vi', 'VN'), // 베트남어
      ],
      locale: currentLocale, // Riverpod로 관리되는 언어 설정
    );
  }
}
