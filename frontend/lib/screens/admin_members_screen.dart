import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../models/admin_member_user.dart';
import '../providers/admin_members_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/i18n_helper.dart';
import '../widgets/logout_button.dart';
import 'admin_member_register_dialogs.dart';

/// 관리자 회원 관리 화면. LayoutBuilder 반응형(Web: 사이드바+테이블 / App: Drawer+카드).
/// [inShell] true면 Shell 레이아웃 안에서 본문(회원 목록)만 표시.
class AdminMembersScreen extends ConsumerWidget {
  const AdminMembersScreen({super.key, this.inShell = false});

  static const double _breakpoint = 600;

  final bool inShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= _breakpoint;
    final fontScale = ref.watch(fontScaleProvider);
    final locale = ref.watch(localeProvider);
    final i18n = I18nHelper.of(context);

    if (inShell) {
      return Container(
        color: AppColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _breakpoint;
            return _buildContent(context, ref, fontScale, i18n, wide);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: isWide
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin/dashboard'),
              )
            : null,
        title: Row(
          children: [
            Icon(Icons.people, color: AppColors.adminActive, size: 24 * fontScale),
            SizedBox(width: 8 * fontScale),
            Text(
              i18n.t('admin_members_title'),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20 * fontScale,
              ),
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: i18n.t('font_size'),
            child: IconButton(
              icon: Icon(Icons.text_fields, color: AppColors.textSecondary, size: 24 * fontScale),
              onPressed: () => ref.read(fontScaleProvider.notifier).toggleScale(),
            ),
          ),
          SizedBox(
            width: 120,
            child: DropdownButton<String>(
              value: locale.languageCode,
              underline: const SizedBox(),
              isExpanded: true,
              items: [
                DropdownMenuItem(value: 'ko', child: Text(i18n.t('language_ko'))),
                DropdownMenuItem(value: 'en', child: Text(i18n.t('language_en'))),
                DropdownMenuItem(value: 'vi', child: Text(i18n.t('language_vi'))),
              ],
              onChanged: (v) {
                if (v != null) ref.read(localeProvider.notifier).changeLocale(v);
              },
            ),
          ),
          const LogoutButton(),
        ],
      ),
      drawer: isWide ? null : _buildDrawer(context, ref, fontScale, i18n),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _breakpoint;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide) _buildSidebar(context, ref, fontScale, i18n),
              Expanded(child: _buildContent(context, ref, fontScale, i18n, wide)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref, double fontScale, I18nHelper i18n) {
    final currentPath = GoRouterState.of(context).uri.path;
    return Container(
      width: 200,
      color: AppColors.adminSidebar,
      child: ListView(
        padding: EdgeInsets.only(top: 16 * fontScale),
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16 * fontScale, top: 8, bottom: 4),
            child: Text(
              i18n.t('admin_members_nav_members'),
              style: TextStyle(
                fontSize: 13 * fontScale,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _navTile(context, i18n.t('admin_nav_helpers'), Icons.person, currentPath == '/admin/members/helpers' || currentPath.startsWith('/admin/members/helpers/'), '/admin/members/helpers', fontScale),
          _navTile(context, i18n.t('admin_nav_clients'), Icons.accessible, currentPath == '/admin/members/clients' || currentPath.startsWith('/admin/members/clients/'), '/admin/members/clients', fontScale),
          _navTile(context, i18n.t('admin_members_nav_matchings'), Icons.event_note, currentPath.startsWith('/admin/matchings'), '/admin/matchings', fontScale),
          _navTile(context, i18n.t('admin_members_nav_monitoring'), Icons.monitor, currentPath.startsWith('/admin/monitoring'), '/admin/monitoring', fontScale),
          _navTile(context, i18n.t('admin_members_nav_settings'), Icons.settings, currentPath.startsWith('/admin/settings'), '/admin/settings', fontScale),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, double fontScale, I18nHelper i18n) {
    final currentPath = GoRouterState.of(context).uri.path;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.only(top: 24 * fontScale),
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16 * fontScale, top: 8, bottom: 4),
            child: Text(
              i18n.t('admin_members_nav_members'),
              style: TextStyle(
                fontSize: 13 * fontScale,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _navTile(context, i18n.t('admin_nav_helpers'), Icons.person, currentPath == '/admin/members/helpers' || currentPath.startsWith('/admin/members/helpers/'), '/admin/members/helpers', fontScale),
          _navTile(context, i18n.t('admin_nav_clients'), Icons.accessible, currentPath == '/admin/members/clients' || currentPath.startsWith('/admin/members/clients/'), '/admin/members/clients', fontScale),
          _navTile(context, i18n.t('admin_members_nav_matchings'), Icons.event_note, currentPath.startsWith('/admin/matchings'), '/admin/matchings', fontScale),
          _navTile(context, i18n.t('admin_members_nav_monitoring'), Icons.monitor, currentPath.startsWith('/admin/monitoring'), '/admin/monitoring', fontScale),
          _navTile(context, i18n.t('admin_members_nav_settings'), Icons.settings, currentPath.startsWith('/admin/settings'), '/admin/settings', fontScale),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, String label, IconData icon, bool active, String path, double fontScale) {
    return ListTile(
      leading: Icon(icon, color: active ? AppColors.adminActive : AppColors.textSecondary, size: 22 * fontScale),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? AppColors.adminActive : AppColors.textPrimary,
          fontSize: 15 * fontScale,
        ),
      ),
      selected: active,
      onTap: () {
        Navigator.of(context).pop();
        if (!active) context.go(path);
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, double fontScale, I18nHelper i18n, bool isWide) {
    final async = ref.watch(adminMembersProvider);
    final contentPadding = isWide ? 24.0 : 16.0;

    final registerButton = Padding(
      padding: EdgeInsets.fromLTRB(contentPadding * fontScale, 16 * fontScale, contentPadding * fontScale, 8 * fontScale),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            icon: Icon(Icons.person_add, size: 20 * fontScale),
            label: Text(i18n.t('admin_register_new_member'), style: TextStyle(fontSize: 14 * fontScale)),
            onPressed: () => AdminMemberRegisterDialogs.showRegisterTypeChoice(context, ref, fontScale, i18n),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        registerButton,
        Expanded(
          child: async.when(
            data: (List<AdminMemberUser> users) {
              Future<void> onUnlock(int userId) async {
                try {
                  await ref.read(apiServiceProvider).postAdminUserUnlock(userId);
                  ref.invalidate(adminMembersProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('admin_unlock_success'))),
                    );
                  }
                } on DioException catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('admin_unlock_failed'))),
                    );
                  }
                }
              }
              Future<void> onDelete(int userId) async {
                try {
                  await ref.read(apiServiceProvider).deleteAdminUser(userId);
                  ref.invalidate(adminMembersProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('admin_delete_success'))),
                    );
                  }
                } on DioException catch (e) {
                  if (context.mounted) {
                    final msg = e.response?.data is Map && (e.response!.data as Map).containsKey('message')
                        ? (e.response!.data as Map)['message']?.toString() ?? i18n.t('admin_delete_failed')
                        : i18n.t('admin_delete_failed');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }
                }
              }
              if (users.isEmpty) {
                return Center(
                  child: Text(
                    i18n.t('admin_members_empty'),
                    style: TextStyle(fontSize: 16 * fontScale, color: AppColors.textSecondary),
                  ),
                );
              }
              return isWide
                  ? _buildTable(context, users, fontScale, i18n, onUnlock, onDelete, contentPadding)
                  : _buildListView(context, users, fontScale, i18n, onUnlock, onDelete, contentPadding);
            },
            loading: () => Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    SizedBox(height: 16),
                    Text(i18n.t('admin_members_load_error'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<AdminMemberUser> users,
    double fontScale,
    I18nHelper i18n,
    Future<void> Function(int userId) onUnlock,
    Future<void> Function(int userId) onDelete,
    double contentPadding,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(contentPadding * fontScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8 * fontScale),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: 800),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.adminSidebar),
                columns: [
                  DataColumn(label: Text(i18n.t('admin_members_col_name'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                  DataColumn(label: Text(i18n.t('admin_members_col_login_id'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                  DataColumn(label: Text(i18n.t('admin_members_col_email'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                  DataColumn(label: Text(i18n.t('admin_members_col_status'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                  const DataColumn(label: SizedBox(width: 40)),
                  DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                  DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                ],
                rows: users.map((u) => _dataRow(u, fontScale, i18n, onUnlock, onDelete)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _dataRow(
    AdminMemberUser u,
    double fontScale,
    I18nHelper i18n,
    Future<void> Function(int userId) onUnlock,
    Future<void> Function(int userId) onDelete,
  ) {
    final bgColor = u.hasDuplicateMatching ? AppColors.duplicateRow : null;
    final statusText = u.isSuspended ? i18n.t('admin_members_status_suspended') : i18n.t('admin_members_status_active');
    return DataRow(
      color: WidgetStateProperty.all(bgColor),
      cells: [
        DataCell(Text(u.name, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(u.loginIdMasked, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(u.email, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(statusText, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(
          u.isSuspended
              ? Tooltip(
                  message: i18n.t('admin_members_locked_hint'),
                  child: Icon(Icons.lock, size: 20 * fontScale, color: AppColors.error),
                )
              : u.hasDuplicateMatching
                  ? Tooltip(
                      message: i18n.t('admin_members_duplicate_hint'),
                      child: Icon(Icons.warning_amber_rounded, size: 20 * fontScale, color: Colors.orange),
                    )
                  : const SizedBox(width: 20, height: 20),
        ),
        DataCell(
          u.isSuspended
              ? TextButton(
                  onPressed: () => onUnlock(u.userId),
                  child: Text(i18n.t('admin_unlock_btn'), style: TextStyle(fontSize: 13 * fontScale)),
                )
              : const SizedBox.shrink(),
        ),
        DataCell(
          TextButton(
            onPressed: () => onDelete(u.userId),
            child: Text(i18n.t('admin_delete_btn'), style: TextStyle(fontSize: 13 * fontScale, color: AppColors.error)),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<AdminMemberUser> users,
    double fontScale,
    I18nHelper i18n,
    Future<void> Function(int userId) onUnlock,
    Future<void> Function(int userId) onDelete,
    double contentPadding,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(contentPadding * fontScale),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final bgColor = u.hasDuplicateMatching ? AppColors.duplicateRow : Colors.white;
        final statusText = u.isSuspended ? i18n.t('admin_members_status_suspended') : i18n.t('admin_members_status_active');
        return Card(
          key: ValueKey(u.userId),
          margin: EdgeInsets.only(bottom: 12 * fontScale),
          color: bgColor,
          child: ListTile(
            leading: u.isSuspended
                ? Icon(Icons.lock, color: AppColors.error, size: 28 * fontScale)
                : CircleAvatar(backgroundColor: AppColors.adminActive.withValues(alpha: 0.2), child: Icon(Icons.person, color: AppColors.adminActive)),
            title: Text(u.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16 * fontScale)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('${i18n.t('admin_members_col_login_id')}: ${u.loginIdMasked}', style: TextStyle(fontSize: 13 * fontScale)),
                Text('${i18n.t('admin_members_col_email')}: ${u.email}', style: TextStyle(fontSize: 13 * fontScale)),
                Text('${i18n.t('admin_members_col_status')}: $statusText', style: TextStyle(fontSize: 13 * fontScale)),
                if (u.hasDuplicateMatching)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(i18n.t('admin_members_duplicate_hint'), style: TextStyle(fontSize: 12 * fontScale, color: Colors.orange.shade800)),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      if (u.isSuspended)
                        TextButton.icon(
                          onPressed: () => onUnlock(u.userId),
                          icon: Icon(Icons.lock_open, size: 18 * fontScale),
                          label: Text(i18n.t('admin_unlock_btn'), style: TextStyle(fontSize: 14 * fontScale)),
                        ),
                      if (u.isSuspended) SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => onDelete(u.userId),
                        icon: Icon(Icons.person_remove, size: 18 * fontScale, color: AppColors.error),
                        label: Text(i18n.t('admin_delete_btn'), style: TextStyle(fontSize: 14 * fontScale, color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
