import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../utils/i18n_helper.dart';

/// 관리자 대시보드 메인 화면. 설계서: 상단 4개 현황 카드 + 오늘 일정 리스트 + 최신 공지 퀵뷰.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getAdminDashboard();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _data = null;
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final i18n = I18nHelper.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 600;
    final padding = (isNarrow ? 16.0 : 24.0) * fontScale;

    if (_loading) {
      return Container(
        color: AppColors.background,
        child: const Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
      );
    }
    if (_error != null) {
      return Container(
        color: AppColors.background,
        padding: EdgeInsets.all(padding),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48 * fontScale, color: AppColors.error),
              SizedBox(height: 16 * fontScale),
              Text(
                i18n.t('menu_load_error'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
              ),
              SizedBox(height: 16 * fontScale),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: AppColors.adminActive),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _data?['stats'] as Map<String, dynamic>? ?? {};
    final totalHelpers = stats['total_helpers'] as int? ?? 0;
    final totalClients = stats['total_clients'] as int? ?? 0;
    final todaySchedules = stats['today_schedules'] as int? ?? 0;
    final inProgressCount = stats['in_progress_count'] as int? ?? 0;
    final todayMatchings = _data?['today_matchings'] as List<dynamic>? ?? [];
    final notices = _data?['notices'] as List<dynamic>? ?? [];

    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.adminActive,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCards(fontScale, i18n, isNarrow, totalHelpers, totalClients, todaySchedules, inProgressCount),
              SizedBox(height: 24 * fontScale),
              _buildTodayList(fontScale, i18n, todayMatchings),
              SizedBox(height: 24 * fontScale),
              _buildNoticesSection(fontScale, i18n, notices),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCards(
    double fontScale,
    I18nHelper i18n,
    bool isNarrow,
    int totalHelpers,
    int totalClients,
    int todaySchedules,
    int inProgressCount,
  ) {
    final cards = [
      _StatCard(
        label: i18n.t('admin_dashboard_total_helpers'),
        value: totalHelpers.toString(),
        icon: Icons.people,
        color: AppColors.adminActive,
      ),
      _StatCard(
        label: i18n.t('admin_dashboard_total_clients'),
        value: totalClients.toString(),
        icon: Icons.accessible,
        color: AppColors.primary,
      ),
      _StatCard(
        label: i18n.t('admin_dashboard_today_schedules'),
        value: todaySchedules.toString(),
        icon: Icons.event_note,
        color: AppColors.textSecondary,
      ),
      _StatCard(
        label: i18n.t('admin_dashboard_in_progress'),
        value: inProgressCount.toString(),
        icon: Icons.play_circle_filled,
        color: inProgressCount > 0 ? AppColors.primary : AppColors.textSecondary,
      ),
    ];
    if (isNarrow) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12 * fontScale,
        crossAxisSpacing: 12 * fontScale,
        childAspectRatio: 1.4,
        children: cards.map((c) => c.build(fontScale)).toList(),
      );
    }
    return Row(
      children: [
        for (int i = 0; i < cards.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < cards.length - 1 ? 12 * fontScale : 0),
              child: cards[i].build(fontScale),
            ),
          ),
      ],
    );
  }

  Widget _buildTodayList(double fontScale, I18nHelper i18n, List<dynamic> todayMatchings) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16 * fontScale),
            child: Text(
              i18n.t('admin_dashboard_today_title'),
              style: TextStyle(
                fontSize: 16 * fontScale,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (todayMatchings.isEmpty)
            Padding(
              padding: EdgeInsets.all(24 * fontScale),
              child: Text(
                i18n.t('admin_monitor_today_empty'),
                style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 8 * fontScale),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('이용자명', style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('담당 보호사', style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      Expanded(child: Text('예정 시간', style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      Expanded(child: Text('실제 시작', style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      SizedBox(width: 72 * fontScale),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todayMatchings.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                final m = todayMatchings[index] as Map<String, dynamic>;
                final status = m['status'] as String? ?? 'waiting';
                final clientName = m['client_name']?.toString() ?? '';
                final userName = m['user_name']?.toString() ?? '';
                final startAt = m['start_at']?.toString() ?? '';
                final actualStart = m['actual_start_time']?.toString() ?? '—';
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 12 * fontScale),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          clientName,
                          style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          userName,
                          style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatTime(startAt),
                          style: TextStyle(fontSize: 13 * fontScale, color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          actualStart != '—' ? _formatTime(actualStart) : '—',
                          style: TextStyle(fontSize: 13 * fontScale, color: AppColors.textSecondary),
                        ),
                      ),
                      _statusBadge(fontScale, i18n, status),
                    ],
                  ),
                );
              },
            ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTime(String s) {
    if (s.length >= 16) return s.substring(11, 16);
    return s;
  }

  Widget _statusBadge(double fontScale, I18nHelper i18n, String status) {
    String label;
    Color color;
    switch (status) {
      case 'in_progress':
        label = i18n.t('home_schedule_status_in_progress');
        color = AppColors.primary;
        break;
      case 'complete':
        label = i18n.t('home_schedule_status_complete');
        color = AppColors.adminActive;
        break;
      default:
        label = i18n.t('home_schedule_status_waiting');
        color = AppColors.textSecondary;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * fontScale, vertical: 4 * fontScale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildNoticesSection(double fontScale, I18nHelper i18n, List<dynamic> notices) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16 * fontScale),
            child: Text(
              i18n.t('admin_dashboard_notices_title'),
              style: TextStyle(
                fontSize: 16 * fontScale,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (notices.isEmpty)
            Padding(
              padding: EdgeInsets.all(24 * fontScale),
              child: Text(
                '등록된 공지가 없습니다.',
                style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notices.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final n = notices[index] as Map<String, dynamic>;
                final title = n['title']?.toString() ?? '';
                final createdAt = n['created_at']?.toString() ?? '';
                final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 10 * fontScale),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 12 * fontScale, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatCard({required this.label, required this.value, required this.icon, required this.color});

  Widget build(double fontScale) {
    return Container(
      padding: EdgeInsets.all(16 * fontScale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 24 * fontScale, color: color),
              SizedBox(width: 8 * fontScale),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13 * fontScale, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * fontScale),
          Text(
            value,
            style: TextStyle(
              fontSize: 22 * fontScale,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
