import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../models/admin_member_user.dart';
import '../../providers/admin_members_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/i18n_helper.dart';
import '../admin_member_register_dialogs.dart';

/// 보호사 관리 전용 화면. 등록·목록·검색·페이징·삭제. 센터 격리.
class HelperManagementScreen extends ConsumerWidget {
  const HelperManagementScreen({super.key});

  static const double _breakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontScaleProvider);
    final locale = ref.watch(localeProvider);
    final i18n = I18nHelper.of(context);

    return Container(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _breakpoint;
          final contentPadding = isWide ? 24.0 : 16.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context, ref, fontScale, locale, i18n, contentPadding),
              Expanded(
                child: _buildBody(context, ref, fontScale, i18n, isWide, contentPadding),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    Locale locale,
    I18nHelper i18n,
    double contentPadding,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(contentPadding * fontScale, 12 * fontScale, contentPadding * fontScale, 8 * fontScale),
      child: Row(
        children: [
          Icon(Icons.person, color: AppColors.adminActive, size: 22 * fontScale),
          SizedBox(width: 8 * fontScale),
          Text(
            i18n.t('admin_nav_helpers'),
            style: TextStyle(
              fontSize: 18 * fontScale,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _helperSearchFieldDropdown(BuildContext context, WidgetRef ref, double fontScale, I18nHelper i18n) {
    final locale = ref.watch(localeProvider);
    final searchField = ref.watch(helperSearchFieldProvider);
    String label(String value) {
      switch (value) {
        case 'name': return locale.languageCode == 'ko' ? '이름' : (locale.languageCode == 'vi' ? 'Tên' : 'Name');
        case 'phone': return locale.languageCode == 'ko' ? '전화번호' : (locale.languageCode == 'vi' ? 'SĐT' : 'Phone');
        case 'email': return locale.languageCode == 'ko' ? '이메일' : (locale.languageCode == 'vi' ? 'Email' : 'Email');
        default: return '이름';
      }
    }
    return SizedBox(
      width: 120 * fontScale,
      child: DropdownButtonFormField<String>(
        value: searchField,
        decoration: InputDecoration(border: OutlineInputBorder(), isDense: true),
        isExpanded: true,
        items: ['name', 'phone', 'email'].map((v) => DropdownMenuItem(value: v, child: Text(label(v), style: TextStyle(fontSize: 14 * fontScale)))).toList(),
        onChanged: (v) {
          if (v != null) {
            ref.read(helperSearchFieldProvider.notifier).state = v;
            ref.read(helperPageProvider.notifier).state = 1;
            ref.invalidate(adminHelpersListProvider);
          }
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    I18nHelper i18n,
    bool isWide,
    double contentPadding,
  ) {
    final searchQuery = ref.watch(helperSearchQueryProvider);
    final async = ref.watch(adminHelpersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _helperSearchFieldDropdown(context, ref, fontScale, i18n),
                    SizedBox(width: 8 * fontScale),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('helper_search'),
                        initialValue: searchQuery,
                        onChanged: (v) {
                          ref.read(helperSearchQueryProvider.notifier).state = v;
                          ref.read(helperPageProvider.notifier).state = 1;
                        },
                        decoration: InputDecoration(
                          hintText: i18n.t('admin_header_search'),
                          prefixIcon: Icon(Icons.search, size: 20 * fontScale),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 14 * fontScale),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12 * fontScale),
              FilledButton.icon(
                icon: Icon(Icons.person_add, size: 20 * fontScale),
                label: Text(i18n.t('admin_register_new_member'), style: TextStyle(fontSize: 14 * fontScale)),
                onPressed: () => AdminMemberRegisterDialogs.showHelperRegisterDialog(context, ref, fontScale, i18n)
                    .then((_) => ref.invalidate(adminHelpersListProvider)),
              ),
            ],
          ),
        ),
        SizedBox(height: 12 * fontScale),
        Expanded(
          child: async.when(
            data: (data) {
              final users = data['users'] as List<AdminMemberUser>;
              final total = data['total'] as int;
              final currentPage = data['current_page'] as int;
              final lastPage = data['last_page'] as int;

              Future<void> onUnlock(int userId) async {
                try {
                  await ref.read(apiServiceProvider).postAdminUserUnlock(userId);
                  ref.invalidate(adminHelpersListProvider);
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
                final confirmed = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: Text(i18n.t('admin_delete_btn')),
                    content: Text(i18n.t('admin_delete_confirm_message')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(i18n.t('cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                        child: Text(i18n.t('admin_delete_confirm_btn')),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                try {
                  await ref.read(apiServiceProvider).deleteAdminUser(userId);
                  ref.invalidate(adminHelpersListProvider);
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: isWide
                        ? _buildTable(context, users, fontScale, i18n, contentPadding, onUnlock, onDelete)
                        : _buildListView(context, users, fontScale, i18n, contentPadding, onUnlock, onDelete),
                  ),
                  _buildPaging(context, ref, fontScale, i18n, total, currentPage, lastPage),
                ],
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
            error: (err, _) => Center(
              child: Padding(
                padding: EdgeInsets.all(contentPadding * fontScale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    SizedBox(height: 16),
                    Text(
                      i18n.t('admin_members_load_error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14 * fontScale),
                    ),
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
    double contentPadding,
    Future<void> Function(int) onUnlock,
    Future<void> Function(int) onDelete,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 700),
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
    );
  }

  DataRow _dataRow(
    AdminMemberUser u,
    double fontScale,
    I18nHelper i18n,
    Future<void> Function(int) onUnlock,
    Future<void> Function(int) onDelete,
  ) {
    final bgColor = u.hasDuplicateMatching ? AppColors.duplicateRow : null;
    final statusText = u.isSuspended ? i18n.t('admin_members_status_suspended') : i18n.t('admin_members_status_active');
    return DataRow(
      color: WidgetStateProperty.all(bgColor),
      cells: [
        DataCell(Text(u.name, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(u.loginId, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(u.email, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(statusText, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(
          u.isSuspended
              ? Tooltip(message: i18n.t('admin_members_locked_hint'), child: Icon(Icons.lock, size: 20 * fontScale, color: AppColors.error))
              : u.hasDuplicateMatching
                  ? Tooltip(message: i18n.t('admin_members_duplicate_hint'), child: Icon(Icons.warning_amber_rounded, size: 20 * fontScale, color: Colors.orange))
                  : const SizedBox(width: 20, height: 20),
        ),
        DataCell(
          u.isSuspended
              ? TextButton(onPressed: () => onUnlock(u.userId), child: Text(i18n.t('admin_unlock_btn'), style: TextStyle(fontSize: 13 * fontScale)))
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
    double contentPadding,
    Future<void> Function(int) onUnlock,
    Future<void> Function(int) onDelete,
  ) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final statusText = u.isSuspended ? i18n.t('admin_members_status_suspended') : i18n.t('admin_members_status_active');
        return Card(
          key: ValueKey(u.userId),
          margin: EdgeInsets.only(bottom: 12 * fontScale),
          color: u.hasDuplicateMatching ? AppColors.duplicateRow : Colors.white,
          child: ListTile(
            leading: u.isSuspended ? Icon(Icons.lock, color: AppColors.error, size: 28 * fontScale) : CircleAvatar(backgroundColor: AppColors.adminActive.withValues(alpha: 0.2), child: Icon(Icons.person, color: AppColors.adminActive)),
            title: Text(u.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16 * fontScale)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i18n.t('admin_members_col_login_id')}: ${u.loginId}', style: TextStyle(fontSize: 13 * fontScale)),
                Text('${i18n.t('admin_members_col_status')}: $statusText', style: TextStyle(fontSize: 13 * fontScale)),
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

  Widget _buildPaging(BuildContext context, WidgetRef ref, double fontScale, I18nHelper i18n, int total, int currentPage, int lastPage) {
    return Padding(
      padding: EdgeInsets.all(16 * fontScale),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            '${i18n.t('admin_paging_total')} $total ${i18n.t('admin_paging_items')} · $currentPage / $lastPage',
            style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
          ),
          if (currentPage > 1)
            TextButton(
              onPressed: () => ref.read(helperPageProvider.notifier).state = currentPage - 1,
              child: Text(i18n.t('admin_paging_prev')),
            ),
          if (currentPage < lastPage)
            TextButton(
              onPressed: () => ref.read(helperPageProvider.notifier).state = currentPage + 1,
              child: Text(i18n.t('admin_paging_next')),
            ),
        ],
      ),
    );
  }
}
