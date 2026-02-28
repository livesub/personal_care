import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/login_form_provider.dart';
import '../utils/i18n_helper.dart';
import '../providers/admin_menus_provider.dart';

/// 관리자 상단 헤더 (룰: 로고/브랜드 - 검색 - 프로필)
/// 접근성: 글자 크기, 다국어 버튼 포함.
class AdminHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AdminHeader({super.key, this.onMenuTap});

  final VoidCallback? onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontScaleProvider);
    final auth = ref.watch(authProvider);
    final i18n = I18nHelper.of(context);
    final centerName = auth.user?.centerName?.isNotEmpty == true ? auth.user!.centerName! : '-';
    final roleLabel = auth.user?.isStaff == true ? i18n.t('admin_role_staff') : i18n.t('admin_role_admin');

    return AppBar(
      backgroundColor: AppColors.adminNav,
      elevation: 0,
      centerTitle: false,
      titleSpacing: onMenuTap == null ? 24 : 0,
      leading: onMenuTap != null
          ? IconButton(
              icon: Icon(Icons.menu, color: Colors.white, size: 24 * fontScale),
              onPressed: onMenuTap,
            )
          : null,
      title: InkWell(
        onTap: () => context.go('/admin/dashboard'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/care_img1.png',
                width: 28 * fontScale,
                height: 28 * fontScale,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.accessible, color: Colors.white, size: 28 * fontScale),
              ),
            ),
            SizedBox(width: 12 * fontScale),
            Text(i18n.t('app_name'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20 * fontScale)),
          ],
        ),
      ),
      actions: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: Icon(Icons.search, color: Colors.white, size: 24 * fontScale), onPressed: () {}, tooltip: i18n.t('admin_header_search')),
              Padding(
                padding: EdgeInsets.only(right: 8 * fontScale),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 16 * fontScale, backgroundColor: Colors.white.withValues(alpha: 0.3), child: Icon(Icons.person, color: Colors.white, size: 20 * fontScale)),
                  SizedBox(width: 8 * fontScale),
                  ConstrainedBox(constraints: BoxConstraints(maxWidth: 120), child: Text('$centerName · $roleLabel', style: TextStyle(color: Colors.white, fontSize: 14 * fontScale), overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 4 * fontScale),
                  Icon(Icons.arrow_drop_down, color: Colors.white, size: 24 * fontScale),
                ]),
              ),
              Tooltip(message: i18n.t('font_size'), child: IconButton(icon: Icon(Icons.text_fields, color: Colors.white70, size: 22 * fontScale), onPressed: () => ref.read(fontScaleProvider.notifier).toggleScale())),
              PopupMenuButton<String>(icon: Icon(Icons.language, color: Colors.white70, size: 22 * fontScale), tooltip: i18n.t('language'), onSelected: (v) => ref.read(localeProvider.notifier).changeLocale(v), itemBuilder: (context) => [PopupMenuItem(value: 'ko', child: Text(i18n.t('language_ko'))), PopupMenuItem(value: 'en', child: Text(i18n.t('language_en'))), PopupMenuItem(value: 'vi', child: Text(i18n.t('language_vi')))]),
              IconButton(icon: Icon(Icons.logout, color: Colors.white70, size: 24 * fontScale), tooltip: i18n.t('logout'), onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                ref.invalidate(authProvider);
                ref.invalidate(selectedCenterIdProvider);
                ref.invalidate(adminMenusProvider);
                ref.invalidate(centersProvider);
                await Future.delayed(const Duration(milliseconds: 100));
                if (context.mounted) context.go('/login');
              }),
            ],
          ),
        ),
      ],
    );
  }
}
