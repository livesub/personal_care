import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../models/admin_member_user.dart';
import '../providers/admin_members_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../utils/i18n_helper.dart';

/// 룰: 회원 관리 콘텐츠. Breadcrumbs, 탭(회원 목록|지원 요청|지원 제공|활동 로그), 인트로 카드, 4통계 카드, TabBarView.
class MemberDashboardScreen extends ConsumerStatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  ConsumerState<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends ConsumerState<MemberDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final i18n = I18nHelper.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(24 * fontScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs: Home / 회원관리
          Row(
            children: [
              Text(i18n.t('admin_breadcrumb_home'), style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary)),
              Icon(Icons.chevron_right, size: 18 * fontScale, color: AppColors.textSecondary),
              Text(i18n.t('admin_members_nav_members'), style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 16 * fontScale),
          // 페이지 제목
          Row(
            children: [
              Icon(Icons.people, color: AppColors.adminActive, size: 28 * fontScale),
              SizedBox(width: 12 * fontScale),
              Text(i18n.t('admin_members_title'), style: TextStyle(fontSize: 24 * fontScale, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          SizedBox(height: 24 * fontScale),
          // 탭 메뉴
          TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            indicator: BoxDecoration(color: AppColors.adminActive, borderRadius: BorderRadius.circular(8)),
            tabs: [
              Tab(text: i18n.t('admin_members_tab_list')),
              Tab(text: i18n.t('admin_members_tab_requests')),
              Tab(text: i18n.t('admin_members_tab_provided')),
              Tab(text: i18n.t('admin_members_tab_activity')),
            ],
          ),
          SizedBox(height: 24 * fontScale),
          // 인트로 패널 카드
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.adminSidebar)),
            child: Padding(
              padding: EdgeInsets.all(24 * fontScale),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i18n.t('admin_members_title'), style: TextStyle(fontSize: 20 * fontScale, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        SizedBox(height: 8 * fontScale),
                        Text(i18n.t('admin_members_intro_desc'), style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary)),
                        SizedBox(height: 20 * fontScale),
                        FilledButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.add, size: 20 * fontScale),
                          label: Text(i18n.t('admin_members_add_btn'), style: TextStyle(fontSize: 14 * fontScale)),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.adminActive, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width > 500)
                    SizedBox(
                      width: 160,
                      height: 120,
                      child: Icon(Icons.volunteer_activism, size: 80, color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24 * fontScale),
          // 통계 카드 4개
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.8,
                children: [
                  _StatCard(icon: Icons.people, value: '1,240', label: i18n.t('admin_stat_total_members'), fontScale: fontScale),
                  _StatCard(icon: Icons.home_work_outlined, value: '320', label: i18n.t('admin_stat_requests'), fontScale: fontScale),
                  _StatCard(icon: Icons.favorite_border, value: '285', label: i18n.t('admin_stat_provided'), fontScale: fontScale),
                  _StatCard(icon: Icons.assignment_outlined, value: '451', label: i18n.t('admin_stat_activity_log'), fontScale: fontScale),
                ],
              );
            },
          ),
          SizedBox(height: 24 * fontScale),
          // 탭 콘텐츠
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _MembersListTab(fontScale: fontScale),
                Center(child: Text(i18n.t('admin_coming_soon'), style: TextStyle(color: AppColors.textSecondary, fontSize: 16 * fontScale))),
                Center(child: Text(i18n.t('admin_coming_soon'), style: TextStyle(color: AppColors.textSecondary, fontSize: 16 * fontScale))),
                Center(child: Text(i18n.t('admin_coming_soon'), style: TextStyle(color: AppColors.textSecondary, fontSize: 16 * fontScale))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, required this.fontScale});

  final IconData icon;
  final String value;
  final String label;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.adminSidebar)),
      child: Padding(
        padding: EdgeInsets.all(20 * fontScale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32 * fontScale, color: AppColors.adminActive),
            SizedBox(height: 12 * fontScale),
            Text(value, style: TextStyle(fontSize: 28 * fontScale, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(label, style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _MembersListTab extends ConsumerWidget {
  const _MembersListTab({required this.fontScale});

  final double fontScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = I18nHelper.of(context);
    final async = ref.watch(adminMembersProvider);

    return async.when(
      data: (List<AdminMemberUser> users) {
        if (users.isEmpty) {
          return Center(child: Text(i18n.t('admin_members_empty'), style: TextStyle(fontSize: 16 * fontScale, color: AppColors.textSecondary)));
        }
        Future<void> onUnlock(int userId) async {
          try {
            await ref.read(apiServiceProvider).postAdminUserUnlock(userId);
            ref.invalidate(adminMembersProvider);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.t('admin_unlock_success'))));
          } on DioException catch (_) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.t('admin_unlock_failed'))));
          }
        }
        final isWide = MediaQuery.sizeOf(context).width >= 600;
        if (isWide) {
          return SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.adminSidebar),
              columns: [
                DataColumn(label: Text(i18n.t('admin_members_col_name'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                DataColumn(label: Text(i18n.t('admin_members_col_login_id'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                DataColumn(label: Text(i18n.t('admin_members_col_email'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                DataColumn(label: Text(i18n.t('admin_members_col_status'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontScale))),
                const DataColumn(label: SizedBox.shrink()),
              ],
              rows: users.map((u) => _dataRow(u, fontScale, i18n, onUnlock)).toList(),
            ),
          );
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final u = users[index];
            final bgColor = u.hasDuplicateMatching ? AppColors.duplicateRow : Colors.white;
            final statusText = u.isSuspended ? i18n.t('admin_members_status_suspended') : i18n.t('admin_members_status_active');
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              color: bgColor,
              child: ListTile(
                leading: u.isSuspended ? Icon(Icons.lock, color: AppColors.error) : CircleAvatar(backgroundColor: AppColors.adminActive.withValues(alpha: 0.2), child: Icon(Icons.person, color: AppColors.adminActive)),
                title: Text(u.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * fontScale)),
                subtitle: Text('${u.loginIdMasked} · $statusText', style: TextStyle(fontSize: 12 * fontScale)),
                trailing: u.isSuspended ? TextButton(onPressed: () => onUnlock(u.userId), child: Text(i18n.t('admin_unlock_btn'))) : null,
              ),
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
      error: (err, _) => Center(child: Text(i18n.t('admin_members_load_error'), style: TextStyle(color: AppColors.textSecondary, fontSize: 14 * fontScale))),
    );
  }

  DataRow _dataRow(AdminMemberUser u, double fontScale, I18nHelper i18n, Future<void> Function(int) onUnlock) {
    final bgColor = u.hasDuplicateMatching ? AppColors.duplicateRow : null;
    final statusText = u.isSuspended ? i18n.t('admin_members_status_suspended') : i18n.t('admin_members_status_active');
    return DataRow(
      color: WidgetStateProperty.all(bgColor),
      cells: [
        DataCell(Text(u.name, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(u.loginIdMasked, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(u.email, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(Text(statusText, style: TextStyle(fontSize: 14 * fontScale))),
        DataCell(u.isSuspended ? TextButton(onPressed: () => onUnlock(u.userId), child: Text(i18n.t('admin_unlock_btn'))) : const SizedBox.shrink()),
      ],
    );
  }
}
