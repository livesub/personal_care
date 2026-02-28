import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../models/admin_matching_list_item.dart';
import '../../providers/admin_members_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/i18n_helper.dart';
import 'matching_edit_dialog.dart';
import 'matching_register_dialog.dart';

/// 조기 종료(early_terminated) 건이 리스트 진입/갱신 시 즉시 관리자 화면에 팝업. 보호사명·이용자명·조기 종료 사유 표시.
class _EarlyStopPopupListener extends StatelessWidget {
  const _EarlyStopPopupListener({
    required this.ref,
    required this.matchings,
    required this.fontScale,
    required this.i18n,
    required this.child,
  });

  final WidgetRef ref;
  final List<AdminMatchingListItem> matchings;
  final double fontScale;
  final I18nHelper i18n;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final earlyStops = matchings.where((m) => m.isEarlyStop).toList();
      if (earlyStops.isEmpty) return;
      final shown = ref.read(adminEarlyStopShownIdsProvider);
      final newOnes = earlyStops.where((m) => !shown.contains(m.id)).toList();
      if (newOnes.isEmpty) return;
      ref.read(adminEarlyStopShownIdsProvider.notifier).state = Set<int>.from(shown)..addAll(earlyStops.map((e) => e.id));
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(i18n.t('admin_early_stop_popup_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in newOnes) ...[
                  if (newOnes.indexOf(item) > 0) SizedBox(height: 16 * fontScale),
                  Text(
                    '${i18n.t('admin_matching_col_helper')}: ${item.userName}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * fontScale),
                  ),
                  Text(
                    '${i18n.t('admin_matching_col_client')}: ${item.clientName}',
                    style: TextStyle(fontSize: 14 * fontScale),
                  ),
                  SizedBox(height: 4 * fontScale),
                  Text(
                    item.earlyStopReason?.trim().isNotEmpty == true
                        ? item.earlyStopReason!
                        : i18n.t('admin_matching_early_stop_reason_empty'),
                    style: TextStyle(fontSize: 13 * fontScale, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(i18n.t('close')),
            ),
          ],
        ),
      );
    });
    return child;
  }
}

/// 매칭 목록 및 실시간 모니터링. 필터 탭(전체/서비스 중/시작 전/조기 종료/완료), 카드 UI, 타이머.
class MatchingManagementScreen extends ConsumerWidget {
  const MatchingManagementScreen({super.key});

  static const double _breakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontScaleProvider);
    final locale = ref.watch(localeProvider);
    final i18n = I18nHelper.of(context);
    final isStaff = ref.watch(authProvider).user?.isStaff == true;

    return Container(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _breakpoint;
          final contentPadding = isWide ? 24.0 : 16.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context, ref, fontScale, locale, i18n, contentPadding, isStaff),
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
    bool isStaff,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(contentPadding * fontScale, 12 * fontScale, contentPadding * fontScale, 8 * fontScale),
      child: Row(
        children: [
          Icon(Icons.event_note, color: AppColors.adminActive, size: 22 * fontScale),
          SizedBox(width: 8 * fontScale),
          Text(
            i18n.t('admin_members_nav_matchings'),
            style: TextStyle(
              fontSize: 18 * fontScale,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            icon: Icon(Icons.add, size: 20 * fontScale),
            label: Text(i18n.t('admin_matching_register_btn'), style: TextStyle(fontSize: 14 * fontScale)),
            onPressed: isStaff ? null : () => MatchingRegisterDialog.show(context, ref, fontScale, i18n)
                .then((_) => ref.invalidate(adminMatchingsListProvider)),
          ),
        ],
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
    final async = ref.watch(adminMatchingsListProvider);
    final filter = ref.watch(matchingMonitorFilterProvider);

    return async.when(
      data: (data) {
        final matchings = data['matchings'] as List<AdminMatchingListItem>;
        final total = data['total'] as int;
        final currentPage = data['current_page'] as int;
        final lastPage = data['last_page'] as int;
        var filtered = _filterByStatus(matchings, filter);
        // 지각 알림: 예정 시작+10분 경과·미시작 카드를 최상단으로
        filtered = _sortLateToTop(filtered);

        void showEarlyStopReason(AdminMatchingListItem item) {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(i18n.t('admin_matching_early_stop_reason_title')),
              content: SingleChildScrollView(
                child: Text(
                  item.earlyStopReason?.trim().isNotEmpty == true
                      ? item.earlyStopReason!
                      : i18n.t('admin_matching_early_stop_reason_empty'),
                  style: TextStyle(fontSize: 14 * fontScale),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(i18n.t('close')),
                ),
              ],
            ),
          );
        }

        Future<void> onEdit(AdminMatchingListItem item) async {
          await MatchingEditDialog.show(context, ref, fontScale, i18n, item);
          ref.invalidate(adminMatchingsListProvider);
        }

        Future<void> onDelete(AdminMatchingListItem item) async {
          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(i18n.t('admin_delete_btn')),
              content: Text(i18n.t('admin_delete_confirm_message')),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(i18n.t('cancel'))),
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
            await ref.read(apiServiceProvider).deleteAdminMatching(item.id);
            ref.invalidate(adminMatchingsListProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(i18n.t('admin_matching_deleted'))),
              );
            }
          } on DioException catch (e) {
            if (context.mounted) {
              final msg = (e.response?.data is Map && (e.response!.data as Map).containsKey('message'))
                  ? (e.response!.data as Map)['message']?.toString() ?? i18n.t('admin_matching_delete_only_future')
                  : i18n.t('admin_matching_delete_only_future');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          }
        }

        if (matchings.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
            child: Center(
              child: Text(
                i18n.t('admin_matching_empty'),
                style: TextStyle(fontSize: 16 * fontScale, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final isStaff = ref.watch(authProvider).user?.isStaff == true;
        final canEditOrDelete = !isStaff;

        return _EarlyStopPopupListener(
          ref: ref,
          matchings: matchings,
          fontScale: fontScale,
          i18n: i18n,
          child: _AutoRefreshMatchings(
            ref: ref,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterTabs(context, ref, fontScale, i18n, filter),
              Expanded(
                child: filtered.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: contentPadding * fontScale),
                        child: Center(
                          child: Text(
                            i18n.t('admin_matching_empty'),
                            style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _MonitorCardList(
                        matchings: filtered,
                        fontScale: fontScale,
                        contentPadding: contentPadding,
                        i18n: i18n,
                        canEditOrDelete: canEditOrDelete,
                        onEarlyStopTap: showEarlyStopReason,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
              ),
              _buildPaging(context, ref, fontScale, i18n, total, currentPage, lastPage),
            ],
          ),
        ),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.adminActive)),
      error: (err, _) => Padding(
        padding: EdgeInsets.all(contentPadding * fontScale),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              SizedBox(height: 16),
              Text(
                i18n.t('admin_matchings_load_error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14 * fontScale),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AdminMatchingListItem> _filterByStatus(List<AdminMatchingListItem> matchings, MonitorFilterStatus filter) {
    switch (filter) {
      case MonitorFilterStatus.all:
        return matchings;
      case MonitorFilterStatus.inProgress:
        return matchings.where((m) => AdminMatchingListItem.monitorStatus(m) == MonitorFilterStatus.inProgress).toList();
      case MonitorFilterStatus.notStarted:
        return matchings.where((m) => AdminMatchingListItem.monitorStatus(m) == MonitorFilterStatus.notStarted).toList();
      case MonitorFilterStatus.earlyStop:
        return matchings.where((m) => m.isEarlyStop).toList();
      case MonitorFilterStatus.completed:
        return matchings.where((m) => AdminMatchingListItem.isEnded(m)).toList();
    }
  }

  /// 지각 알림: isLateStart인 카드를 리스트 최상단으로
  List<AdminMatchingListItem> _sortLateToTop(List<AdminMatchingListItem> list) {
    final sorted = List<AdminMatchingListItem>.from(list);
    sorted.sort((a, b) {
      final aLate = AdminMatchingListItem.isLateStart(a);
      final bLate = AdminMatchingListItem.isLateStart(b);
      if (aLate && !bLate) return -1;
      if (!aLate && bLate) return 1;
      return 0;
    });
    return sorted;
  }

  Widget _buildFilterTabs(
    BuildContext context,
    WidgetRef ref,
    double fontScale,
    I18nHelper i18n,
    MonitorFilterStatus current,
  ) {
    final tabs = [
      (MonitorFilterStatus.all, i18n.t('admin_monitor_filter_all')),
      (MonitorFilterStatus.inProgress, i18n.t('admin_monitor_filter_in_progress')),
      (MonitorFilterStatus.notStarted, i18n.t('admin_monitor_filter_not_started')),
      (MonitorFilterStatus.earlyStop, i18n.t('admin_monitor_filter_early_stop')),
      (MonitorFilterStatus.completed, i18n.t('admin_monitor_filter_completed')),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 8 * fontScale),
      child: Row(
        children: [
          for (final entry in tabs)
            Padding(
              padding: EdgeInsets.only(right: 8 * fontScale),
              child: FilterChip(
                label: Text(entry.$2, style: TextStyle(fontSize: 13 * fontScale)),
                selected: current == entry.$1,
                onSelected: (_) => ref.read(matchingMonitorFilterProvider.notifier).state = entry.$1,
                selectedColor: AppColors.adminActive.withValues(alpha: 0.25),
                checkmarkColor: AppColors.adminActive,
              ),
            ),
        ],
      ),
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
              onPressed: () => ref.read(matchingPageProvider.notifier).state = currentPage - 1,
              child: Text(i18n.t('admin_paging_prev')),
            ),
          if (currentPage < lastPage)
            TextButton(
              onPressed: () => ref.read(matchingPageProvider.notifier).state = currentPage + 1,
              child: Text(i18n.t('admin_paging_next')),
            ),
        ],
      ),
    );
  }
}

/// 카드 리스트 + 1초마다 리빌드하여 타이머 갱신. 모든 시간은 .toLocal() 기준 표시.
class _MonitorCardList extends StatefulWidget {
  const _MonitorCardList({
    required this.matchings,
    required this.fontScale,
    required this.contentPadding,
    required this.i18n,
    required this.canEditOrDelete,
    required this.onEarlyStopTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminMatchingListItem> matchings;
  final double fontScale;
  final double contentPadding;
  final I18nHelper i18n;
  final bool canEditOrDelete;
  final void Function(AdminMatchingListItem) onEarlyStopTap;
  final Future<void> Function(AdminMatchingListItem) onEdit;
  final Future<void> Function(AdminMatchingListItem) onDelete;

  @override
  State<_MonitorCardList> createState() => _MonitorCardListState();
}

class _MonitorCardListState extends State<_MonitorCardList> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: widget.contentPadding * widget.fontScale, vertical: 8 * widget.fontScale),
      itemCount: widget.matchings.length,
      itemBuilder: (context, index) {
        final m = widget.matchings[index];
        return _MonitorCard(
          item: m,
          fontScale: widget.fontScale,
          i18n: widget.i18n,
          canEditOrDelete: widget.canEditOrDelete,
          onEarlyStopTap: widget.onEarlyStopTap,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        );
      },
    );
  }
}

/// 둥근 모서리·그림자 카드. 이용자/보호사명, 예정 시간, 실제 시작/종료, 서비스 중이면 타이머(00:12:34).
class _MonitorCard extends StatelessWidget {
  const _MonitorCard({
    required this.item,
    required this.fontScale,
    required this.i18n,
    required this.canEditOrDelete,
    required this.onEarlyStopTap,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminMatchingListItem item;
  final double fontScale;
  final I18nHelper i18n;
  final bool canEditOrDelete;
  final void Function(AdminMatchingListItem) onEarlyStopTap;
  final Future<void> Function(AdminMatchingListItem) onEdit;
  final Future<void> Function(AdminMatchingListItem) onDelete;

  @override
  Widget build(BuildContext context) {
    final status = AdminMatchingListItem.monitorStatus(item);
    final isInProgress = status == MonitorFilterStatus.inProgress;
    final elapsed = AdminMatchingListItem.elapsedSinceStart(item);
    final isLate = AdminMatchingListItem.isLateStart(item);

    // 상태 강조(Active Status): 서비스 중(in-progress) 카드는 연한 녹색 테두리로 시각 구분
    final borderColor = isInProgress ? AppColors.primaryLight : Colors.transparent;
    final borderWidth = isInProgress ? 2.0 : 0.0;
    // 중복 근무 감지: 동일 user_id·겹치는 시간대 → 배경 연한 빨강(#FFE5E5) 고정
    final cardColor = item.isDuplicate ? AppColors.duplicateRow : Colors.white;
    final textColor = isLate ? AppColors.error : AppColors.textPrimary;

    return Card(
      margin: EdgeInsets.only(bottom: 12 * fontScale),
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.all(16 * fontScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.clientName} / ${item.userName}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15 * fontScale,
                      color: textColor,
                    ),
                  ),
                ),
                if (item.isDuplicate)
                  Tooltip(
                    message: i18n.t('admin_matching_duplicate_hint'),
                    child: Icon(Icons.warning_amber_rounded, size: 20 * fontScale, color: AppColors.warning),
                  ),
                // 거리 대조: 버튼 클릭 좌표 vs 이용자 집 좌표 100m 이상 시 [위치 경고 ⚠️]
                if (AdminMatchingListItem.isLocationWarning(item))
                  Padding(
                    padding: EdgeInsets.only(left: 6 * fontScale),
                    child: Tooltip(
                      message: i18n.t('admin_monitor_location_warning_hint'),
                      child: Icon(Icons.warning_amber_rounded, size: 22 * fontScale, color: AppColors.error),
                    ),
                  ),
              ],
            ),
            if (isInProgress && item.actualStartTime != null && item.actualStartTime!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4 * fontScale),
                child: Text(
                  i18n.t('admin_monitor_status_in_progress_with_time').replaceAll('{{time}}', AdminMatchingListItem.formatTimeOnly(item.actualStartTime)),
                  style: TextStyle(fontSize: 13 * fontScale, color: AppColors.primary, fontWeight: FontWeight.w500),
                ),
              ),
            SizedBox(height: 10 * fontScale),
            _row(i18n.t('admin_monitor_scheduled_time'), _scheduledRange(), fontScale, textColor),
            _row(i18n.t('admin_monitor_actual_start'), AdminMatchingListItem.formatDateTime(item.actualStartTime), fontScale, textColor),
            _row(i18n.t('admin_monitor_actual_end'), AdminMatchingListItem.formatDateTime(item.realEndTime), fontScale, textColor),
            if (isInProgress && elapsed != null) ...[
              SizedBox(height: 8 * fontScale),
              Text(
                '${i18n.t('admin_monitor_timer')} ${AdminMatchingListItem.formatTimer(elapsed)}',
                style: TextStyle(
                  fontSize: 16 * fontScale,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
            if (item.isEarlyStop)
              Padding(
                padding: EdgeInsets.only(top: 10 * fontScale),
                child: InkWell(
                  onTap: () => onEarlyStopTap(item),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * fontScale, vertical: 6 * fontScale),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Text(
                      i18n.t('admin_matching_early_stop_badge'),
                      style: TextStyle(fontSize: 12 * fontScale, color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: 12 * fontScale),
              child: Row(
                children: [
                  TextButton(
                    onPressed: canEditOrDelete ? () => onEdit(item) : null,
                    child: Text(i18n.t('admin_matching_edit_btn'), style: TextStyle(fontSize: 13 * fontScale)),
                  ),
                  if (item.canDelete)
                    TextButton(
                      onPressed: canEditOrDelete ? () => onDelete(item) : null,
                      child: Text(i18n.t('admin_delete_btn'), style: TextStyle(fontSize: 13 * fontScale, color: AppColors.error)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scheduledRange() {
    final s = AdminMatchingListItem.formatDateTime(item.startAt);
    final e = AdminMatchingListItem.formatDateTime(item.endAt);
    return '$s ~ $e';
  }

  Widget _row(String label, String value, double fontScale, Color valueColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4 * fontScale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90 * fontScale, child: Text(label, style: TextStyle(fontSize: 13 * fontScale, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13 * fontScale, color: valueColor))),
        ],
      ),
    );
  }
}

/// 대시보드 갱신(위치 갱신 아님): 1분마다 [매칭 리스트 상태(Status)]만 서버에서 새로 받아와 화면 업데이트.
/// 목적: 지각(10분 경과)·조기 종료 등 상태 변경을 관리자가 새로고침 없이 볼 수 있도록. 타이머(HH:mm:ss)는 1초마다 _MonitorCardList에서 갱신.
class _AutoRefreshMatchings extends StatefulWidget {
  const _AutoRefreshMatchings({required this.ref, required this.child});

  final WidgetRef ref;
  final Widget child;

  @override
  State<_AutoRefreshMatchings> createState() => _AutoRefreshMatchingsState();
}

class _AutoRefreshMatchingsState extends State<_AutoRefreshMatchings> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      widget.ref.invalidate(adminMatchingsListProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
