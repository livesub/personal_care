import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../providers/admin_menus_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../providers/login_form_provider.dart';
import '../utils/i18n_helper.dart';

/// 로그인된 모든 페이지의 AppBar에 넣을 로그아웃 아이콘 버튼.
/// 로그아웃 시 관련 Provider 전부 invalidate 후 로그인 화면으로 이동.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontScaleProvider);
    final i18n = I18nHelper.of(context);
    return IconButton(
      icon: Icon(Icons.logout, color: AppColors.textSecondary, size: 24 * fontScale),
      tooltip: i18n.t('logout'),
      onPressed: () async {
        await ref.read(authProvider.notifier).logout();
        ref.invalidate(authProvider);
        ref.invalidate(selectedCenterIdProvider);
        ref.invalidate(adminMenusProvider);
        ref.invalidate(centersProvider);
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) context.go('/login');
      },
    );
  }
}
