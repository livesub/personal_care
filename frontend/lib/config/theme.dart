import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Material 3 테마 설정
/// .cursorrules: Material 3 디자인 시스템 적용
/// 디자인 참고: docs/design/ (색상 톤 참고)
class AppTheme {
  /// TextTheme.apply(fontSizeFactor)는 모든 스타일에 fontSize가 있어야 함.
  /// null이 있으면 assertion 발생하므로, 기본값을 채운 뒤 scale 적용.
  static TextTheme textThemeWithScale(TextTheme base, double fontSizeFactor) {
    if (fontSizeFactor == 1.0) return base;
    const dL = 57.0, dM = 45.0, dS = 36.0;
    const hL = 32.0, hM = 28.0, hS = 24.0;
    const tL = 22.0, tM = 16.0, tS = 14.0;
    const bL = 16.0, bM = 14.0, bS = 12.0;
    const lL = 14.0, lM = 12.0, lS = 11.0;
    final safe = TextTheme(
      displayLarge: (base.displayLarge ?? const TextStyle()).copyWith(fontSize: base.displayLarge?.fontSize ?? dL),
      displayMedium: (base.displayMedium ?? const TextStyle()).copyWith(fontSize: base.displayMedium?.fontSize ?? dM),
      displaySmall: (base.displaySmall ?? const TextStyle()).copyWith(fontSize: base.displaySmall?.fontSize ?? dS),
      headlineLarge: (base.headlineLarge ?? const TextStyle()).copyWith(fontSize: base.headlineLarge?.fontSize ?? hL),
      headlineMedium: (base.headlineMedium ?? const TextStyle()).copyWith(fontSize: base.headlineMedium?.fontSize ?? hM),
      headlineSmall: (base.headlineSmall ?? const TextStyle()).copyWith(fontSize: base.headlineSmall?.fontSize ?? hS),
      titleLarge: (base.titleLarge ?? const TextStyle()).copyWith(fontSize: base.titleLarge?.fontSize ?? tL),
      titleMedium: (base.titleMedium ?? const TextStyle()).copyWith(fontSize: base.titleMedium?.fontSize ?? tM),
      titleSmall: (base.titleSmall ?? const TextStyle()).copyWith(fontSize: base.titleSmall?.fontSize ?? tS),
      bodyLarge: (base.bodyLarge ?? const TextStyle()).copyWith(fontSize: base.bodyLarge?.fontSize ?? bL),
      bodyMedium: (base.bodyMedium ?? const TextStyle()).copyWith(fontSize: base.bodyMedium?.fontSize ?? bM),
      bodySmall: (base.bodySmall ?? const TextStyle()).copyWith(fontSize: base.bodySmall?.fontSize ?? bS),
      labelLarge: (base.labelLarge ?? const TextStyle()).copyWith(fontSize: base.labelLarge?.fontSize ?? lL),
      labelMedium: (base.labelMedium ?? const TextStyle()).copyWith(fontSize: base.labelMedium?.fontSize ?? lM),
      labelSmall: (base.labelSmall ?? const TextStyle()).copyWith(fontSize: base.labelSmall?.fontSize ?? lS),
    );
    return safe.apply(fontSizeFactor: fontSizeFactor);
  }

  /// 라이트 테마 (Personal Care 디자인)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true, // Material 3 활성화
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.mintGreen,
        error: AppColors.error,
        surface: AppColors.cardBackground,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  /// 다크 테마
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
