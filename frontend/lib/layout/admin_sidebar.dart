import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../utils/i18n_helper.dart';

/// 룰: 좌측 사이드바. 메뉴 [회원관리, 매칭관리, 모니터링, 행정관리, 운영 관리].
/// 선택된 메뉴는 파란색 배경(Highlight). 로고/Administration 텍스트는 최상단.
/// [goRouter] Shell/Drawer 내부에서도 동일한 라우터로 이동하도록 상위에서 전달.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.currentPath,
    required this.fontScale,
    required this.goRouter,
  });

  final String currentPath;
  final double fontScale;
  final GoRouter goRouter;

  static const double width = 250;

  @override
  Widget build(BuildContext context) {
    final i18n = I18nHelper.of(context);

    return Container(
      width: width,
      color: AppColors.adminSidebar,
      child: ListView(
        padding: EdgeInsets.only(top: 16 * fontScale, left: 8, right: 8, bottom: 24),
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16 * fontScale, bottom: 16 * fontScale),
            child: Row(
              children: [
                Icon(Icons.menu, size: 20 * fontScale, color: AppColors.textSecondary),
                SizedBox(width: 8 * fontScale),
                Text(
                  i18n.t('admin_sidebar_title'),
                  style: TextStyle(
                    fontSize: 16 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _MembersExpansionTile(
            currentPath: currentPath,
            fontScale: fontScale,
            i18n: i18n,
          ),
          _NavTile(
            label: i18n.t('admin_members_nav_matchings'),
            icon: Icons.event_note,
            path: '/admin/matchings',
            currentPath: currentPath,
            fontScale: fontScale,
            goRouter: goRouter,
          ),
          _NavTile(
            label: i18n.t('admin_members_nav_monitoring'),
            icon: Icons.monitor,
            path: '/admin/monitoring',
            currentPath: currentPath,
            fontScale: fontScale,
            goRouter: goRouter,
          ),
          _NavTile(
            label: i18n.t('admin_nav_affairs'),
            icon: Icons.folder_outlined,
            path: '/admin/settlement',
            currentPath: currentPath,
            fontScale: fontScale,
            goRouter: goRouter,
          ),
          _NavTile(
            label: i18n.t('admin_nav_system'),
            icon: Icons.settings,
            path: '/admin/operations',
            currentPath: currentPath,
            fontScale: fontScale,
            goRouter: goRouter,
          ),
        ],
      ),
    );
  }
}

/// 연한 회색 활성 배경 (하위 메뉴 강조)
const Color _activeSubBg = Color(0xFFEEEEEE);

class _MembersExpansionTile extends StatelessWidget {
  const _MembersExpansionTile({
    required this.currentPath,
    required this.fontScale,
    required this.i18n,
  });

  final String currentPath;
  final double fontScale;
  final I18nHelper i18n;

  @override
  Widget build(BuildContext context) {
    final isMembersSection = currentPath == '/admin/members' || currentPath.startsWith('/admin/members/');

    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: ExpansionTile(
        initiallyExpanded: isMembersSection,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tilePadding: EdgeInsets.symmetric(vertical: 12 * fontScale, horizontal: 16 * fontScale),
        childrenPadding: EdgeInsets.only(left: 16 * fontScale, bottom: 8),
        leading: Icon(Icons.people, size: 22 * fontScale, color: AppColors.textSecondary),
        title: Text(
          i18n.t('admin_members_nav_members'),
          style: TextStyle(
            fontSize: 15 * fontScale,
            fontWeight: FontWeight.normal,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          _SubNavTile(
            label: i18n.t('admin_nav_helpers'),
            icon: Icons.person,
            path: '/admin/members/helpers',
            currentPath: currentPath,
            fontScale: fontScale,
          ),
          _SubNavTile(
            label: i18n.t('admin_nav_clients'),
            icon: Icons.accessible,
            path: '/admin/members/clients',
            currentPath: currentPath,
            fontScale: fontScale,
          ),
        ],
      ),
    );
  }
}

class _SubNavTile extends StatelessWidget {
  const _SubNavTile({
    required this.label,
    required this.icon,
    required this.path,
    required this.currentPath,
    required this.fontScale,
  });

  final String label;
  final IconData icon;
  final String path;
  final String currentPath;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final active = currentPath == path || currentPath.startsWith('$path/');

    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? _activeSubBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            GoRouter.of(context).go(path);
            if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.of(context).pop();
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12 * fontScale, horizontal: 16 * fontScale),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22 * fontScale,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 12 * fontScale),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15 * fontScale,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.path,
    required this.currentPath,
    required this.fontScale,
    required this.goRouter,
  });

  final String label;
  final IconData icon;
  final String path;
  final String currentPath;
  final double fontScale;
  final GoRouter goRouter;

  @override
  Widget build(BuildContext context) {
    final active = currentPath == path || currentPath.startsWith('$path/');
    return _buildTile(context, active);
  }

  Widget _buildTile(BuildContext context, bool active) {
    final fullPath = path.startsWith('/') ? path : '/admin/$path';
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? AppColors.adminActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            GoRouter.of(context).go(fullPath);
            if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.of(context).pop();
          },
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12 * fontScale, horizontal: 16 * fontScale),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22 * fontScale,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
                SizedBox(width: 12 * fontScale),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15 * fontScale,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
