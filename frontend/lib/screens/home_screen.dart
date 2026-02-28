import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../models/login_response.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../providers/login_form_provider.dart';
import '../utils/auth_guard_util.dart';
import '../utils/i18n_helper.dart';
import '../widgets/logout_button.dart';

/// 실시간 가드레일: end_at 20분 전까지 일지 작성/종료 버튼 비활성화.
const int _minutesBeforeEndToEnable = 20;

/// 홈 화면
/// 로그인 후 메인 대시보드. 종료 시각 타이머 + 20분 전까지 버튼 비활성화.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.accessDenied = false});

  final bool accessDenied;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

const String _prefsKeyLastSeenNoticeIdPrefix = 'helper_last_seen_notice_id_';

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? _elapsedTimer;
  Timer? _noticeCheckTimer;
  bool _accessDeniedShown = false;
  Map<String, dynamic>? _homeData;
  bool _homeLoading = false;
  String? _homeError;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadHelperHome(),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureCenterAndLoadHome(),
    );
  }

  /// 센터 ID 복원(prefs) 후 일정 로딩. 로그인/새로고침 시 1회 호출.
  /// API가 real_end_time IS NULL인 미종료 근무를 반환하면 current_matching.status == 'start'로 내려와
  /// '근무 중' UI 및 경과 타이머가 자동 복구됨 (추가 또는 이슈 개발 1단계).
  Future<void> _ensureCenterAndLoadHome() async {
    await ref.read(selectedCenterIdProvider.notifier).loadFromPrefs();
    if (!mounted) return;
    _loadHelperHome();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedTimer?.cancel();
    _noticeCheckTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadHelperHome() async {
    final centerId =
        ref.read(authProvider).user?.centerId ??
        ref.read(selectedCenterIdProvider);
    if (centerId == null) {
      setState(() {
        _homeData = null;
        _homeLoading = false;
        _homeError = null;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _homeLoading = true;
      _homeError = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      // 서버가 미종료 근무(real_end_time IS NULL)를 복구해 current_matching으로 내려주면 '근무 중' UI 표시
      final data = await api.getHelperHome(centerId: centerId);
      if (mounted) {
        setState(() {
          _homeData = data;
          _homeLoading = false;
          _homeError = null;
        });
        _startOrStopElapsedTimer(data);
        final centerId =
            ref.read(authProvider).user?.centerId ??
            ref.read(selectedCenterIdProvider);
        if (centerId != null) _startNoticeCheckTimerIfNeeded(centerId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _homeData = null;
          _homeLoading = false;
          _homeError = e.toString();
        });
      }
    }
  }

  void _startOrStopElapsedTimer(Map<String, dynamic>? data) {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    final matching = data?['current_matching'] as Map<String, dynamic>?;
    if (matching != null && matching['status'] == 'start') {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _startNoticeCheckTimerIfNeeded(int centerId) {
    if (_noticeCheckTimer != null) return;
    _noticeCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkNewNotice(),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _checkNewNotice();
    });
  }

  Future<void> _checkNewNotice() async {
    final centerId =
        ref.read(authProvider).user?.centerId ??
        ref.read(selectedCenterIdProvider);
    if (centerId == null || !mounted) return;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final lastSeenId = prefs.getInt(
        '$_prefsKeyLastSeenNoticeIdPrefix$centerId',
      );
      final api = ref.read(apiServiceProvider);
      final data = await api.getNoticesCheckNew(centerId: centerId);
      final id = data['id'];
      final noticeId = id is int ? id : (id is num ? id.toInt() : null);
      if (noticeId == null || noticeId == lastSeenId) return;
      if (!mounted) return;
      final title = data['title']?.toString() ?? '';
      final content = data['content']?.toString() ?? '';
      final centerName = data['center_name']?.toString() ?? '';
      final fontScale = ref.read(fontScaleProvider);
      final i18n = I18nHelper.of(context);
      await _showNoticeDialog(
        context,
        fontScale,
        i18n,
        centerName,
        title,
        content,
      );
      if (!mounted) return;
      final prefsAgain = ref.read(sharedPreferencesProvider);
      await prefsAgain.setInt(
        '$_prefsKeyLastSeenNoticeIdPrefix$centerId',
        noticeId,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final auth = ref.watch(authProvider);

    // 관리자 페이지 침범 후 리다이렉트: "잘못된 접근입니다" SnackBar 1회 표시 후 URL 정리
    if (widget.accessDenied && !_accessDeniedShown && mounted) {
      _accessDeniedShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18nHelper.of(context).t('access_denied'))),
        );
        context.go('/home');
      });
    }

    // 데이터 가드: admin 또는 금칙어 계정이면 흔적 없이 로그인으로 쫓아냄 (앱/웹 공통)
    if (auth.isLoggedIn && isTempAdminLoginId(auth.user?.loginId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(apiServiceProvider).removeToken();
        ref.read(authProvider.notifier).clearSession();
        if (context.mounted) context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final centerId = auth.user?.centerId ?? ref.watch(selectedCenterIdProvider);
    final i18n = I18nHelper.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/care_img1.png',
                  width: 28 * fontScale,
                  height: 28 * fontScale,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 12 * fontScale),
              Text(
                i18n.t('app_name'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20 * fontScale,
                ),
              ),
            ],
          ),
          actions: [
            const LogoutButton(),
            Padding(
              padding: EdgeInsets.only(right: 8 * fontScale),
              child: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: AppColors.primary),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24 * fontScale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (auth.user?.centerName != null &&
                  auth.user!.centerName!.isNotEmpty) ...[
                SizedBox(height: 8 * fontScale),
                Text(
                  auth.user!.centerName!,
                  style: TextStyle(
                    fontSize: 14 * fontScale,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16 * fontScale),
              ],
              _buildHeroCard(context, fontScale, i18n),
              if (_homeData?['client_voucher'] != null)
                _buildVoucherSection(fontScale, i18n),
              SizedBox(height: 20 * fontScale),
              _buildSalarySection(context, fontScale, i18n),
              SizedBox(height: 24 * fontScale),
              _buildTimelineSection(fontScale, i18n),
              SizedBox(height: 24 * fontScale),
              _buildNoticesSection(context, fontScale, i18n),
              SizedBox(height: 24 * fontScale),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '--:--';
    return DateFormat('HH:mm').format(dt.toLocal());
  }

  static String _formatAmount(int value) {
    return NumberFormat('#,###').format(value);
  }

  Widget _buildHeroCard(
    BuildContext context,
    double fontScale,
    I18nHelper i18n,
  ) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = (screenHeight * 0.33).clamp(180.0, 320.0);

    if (_homeLoading && _homeData == null) {
      return SizedBox(
        height: heroHeight,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final matching = _homeData?['current_matching'] as Map<String, dynamic>?;
    final isInProgress = matching != null && matching['status'] == 'start';
    final isWaiting = matching != null && !isInProgress;
    final noSchedule = matching == null;

    String titleText;
    Widget? actionButton;

    if (noSchedule) {
      titleText = i18n.t('home_hero_no_schedule');
      actionButton = null;
    } else if (isInProgress) {
      final name = matching['client_name']?.toString() ?? '';
      final startIso =
          matching['actual_start_time']?.toString() ??
          matching['start_at']?.toString();
      final startTime = _formatTime(startIso);
      titleText = i18n
          .t('home_hero_care_in_progress')
          .replaceAll('{{name}}', name)
          .replaceAll('{{time}}', startTime);
      final elapsed = _elapsedDuration(matching);
      actionButton = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (elapsed != null) ...[
            Text(
              elapsed,
              style: TextStyle(
                fontSize: 20 * fontScale,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12 * fontScale),
          ],
          SizedBox(
            width: double.infinity,
            height: 56 * fontScale,
            child: FilledButton(
              onPressed: () =>
                  _onEndWorkWithDialog(context, ref, matching, fontScale),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * fontScale),
                ),
              ),
              child: Text(
                i18n.t('home_hero_btn_end'),
                style: TextStyle(
                  fontSize: 18 * fontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      final name = matching['client_name']?.toString() ?? '';
      final startIso = matching['start_at']?.toString();
      final startTime = _formatTime(startIso);
      titleText = i18n
          .t('home_hero_next_schedule')
          .replaceAll('{{time}}', startTime)
          .replaceAll('{{name}}', name);
      actionButton = SizedBox(
        width: double.infinity,
        height: 56 * fontScale,
        child: FilledButton(
          onPressed: () => _onStartWork(context, ref, matching, fontScale),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12 * fontScale),
            ),
          ),
          child: Text(
            i18n.t('home_hero_btn_start'),
            style: TextStyle(
              fontSize: 18 * fontScale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: heroHeight),
      margin: EdgeInsets.only(bottom: 16 * fontScale),
      padding: EdgeInsets.all(24 * fontScale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * fontScale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            titleText,
            style: TextStyle(
              fontSize: 18 * fontScale,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionButton != null) ...[
            SizedBox(height: 20 * fontScale),
            actionButton,
          ],
        ],
      ),
    );
  }

  String? _elapsedDuration(Map<String, dynamic> matching) {
    final startIso =
        matching['actual_start_time']?.toString() ??
        matching['start_at']?.toString();
    if (startIso == null) return null;
    final start = DateTime.tryParse(startIso);
    if (start == null) return null;
    final elapsed = DateTime.now().difference(start.toLocal());
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    if (h > 0) return '$h시간 $m분 $s초';
    if (m > 0) return '$m분 $s초';
    return '$s초';
  }

  Widget _buildVoucherSection(double fontScale, I18nHelper i18n) {
    final v = _homeData!['client_voucher'] as Map<String, dynamic>?;
    if (v == null) return const SizedBox.shrink();
    final name = v['client_name']?.toString() ?? '';
    final current = (v['current_balance'] as num?)?.toInt() ?? 0;
    final expected = (v['expected_balance_after_today'] as num?)?.toInt() ?? 0;
    final line1 = i18n
        .t('home_voucher_current')
        .replaceAll('{{name}}', name)
        .replaceAll('{{amount}}', _formatAmount(current));
    final line2 = i18n
        .t('home_voucher_expected')
        .replaceAll('{{amount}}', _formatAmount(expected));
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * fontScale),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12 * fontScale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line1,
            style: TextStyle(
              fontSize: 15 * fontScale,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6 * fontScale),
          Text(
            line2,
            style: TextStyle(
              fontSize: 13 * fontScale,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalarySection(
    BuildContext context,
    double fontScale,
    I18nHelper i18n,
  ) {
    final salary =
        (_homeData?['monthly_expected_salary'] as num?)?.toInt() ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: 28 * fontScale,
                horizontal: 20 * fontScale,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFD4AF37),
                    const Color(0xFFF4E4BC),
                    const Color(0xFFD4AF37),
                  ],
                ),
                borderRadius: BorderRadius.circular(16 * fontScale),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    i18n.t('home_salary_label'),
                    style: TextStyle(
                      fontSize: 16 * fontScale,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5D4E00),
                    ),
                  ),
                  SizedBox(height: 8 * fontScale),
                  TweenAnimationBuilder<double>(
                    key: ValueKey(salary),
                    tween: Tween(begin: 0, end: salary.toDouble()),
                    duration: const Duration(milliseconds: 1600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Text(
                        '${_formatAmount(value.toInt())}원',
                        style: TextStyle(
                          fontSize: (32 * fontScale).clamp(24.0, 42.0),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3D3500),
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  final w = constraints.maxWidth;
                  final left = w * (_shimmerAnimation.value.clamp(0.0, 1.0));
                  return IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16 * fontScale),
                      child: Stack(
                        children: [
                          Positioned(
                            left: left - 80,
                            top: 0,
                            bottom: 0,
                            width: 160,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.25),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineSection(double fontScale, I18nHelper i18n) {
    final list = _homeData?['today_schedules'] as List<dynamic>?;
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          i18n.t('home_timeline_title'),
          style: TextStyle(
            fontSize: 16 * fontScale,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12 * fontScale),
        ...list.map<Widget>((e) {
          final item = e as Map<String, dynamic>;
          final startAt = item['start_at']?.toString();
          final endAt = item['end_at']?.toString();
          final timeStr = '${_formatTime(startAt)}~${_formatTime(endAt)}';
          final clientName = item['client_name']?.toString() ?? '';
          final status = item['status']?.toString() ?? 'scheduled';
          final isComplete = status == 'complete';
          String statusLabel = i18n.t('home_schedule_status_waiting');
          if (status == 'in_progress')
            statusLabel = i18n.t('home_schedule_status_in_progress');
          if (status == 'complete')
            statusLabel = i18n.t('home_schedule_status_complete');
          return Container(
            margin: EdgeInsets.only(bottom: 8 * fontScale),
            padding: EdgeInsets.symmetric(
              horizontal: 14 * fontScale,
              vertical: 12 * fontScale,
            ),
            decoration: BoxDecoration(
              color: isComplete ? Colors.grey.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(10 * fontScale),
              boxShadow: isComplete
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 14 * fontScale,
                    fontWeight: FontWeight.w500,
                    color: isComplete
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
                SizedBox(width: 12 * fontScale),
                Expanded(
                  child: Text(
                    clientName,
                    style: TextStyle(
                      fontSize: 14 * fontScale,
                      color: isComplete
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: isComplete
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * fontScale,
                    vertical: 4 * fontScale,
                  ),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Colors.grey.shade400
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12 * fontScale,
                      fontWeight: FontWeight.w600,
                      color: isComplete ? Colors.white : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNoticesSection(
    BuildContext context,
    double fontScale,
    I18nHelper i18n,
  ) {
    final list = _homeData?['notices'] as List<dynamic>?;
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          i18n.t('home_notices_title'),
          style: TextStyle(
            fontSize: 16 * fontScale,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12 * fontScale),
        ...list.take(3).map<Widget>((e) {
          final notice = e as Map<String, dynamic>;
          final centerName = notice['center_name']?.toString() ?? '';
          final title = notice['title']?.toString() ?? '';
          final content = notice['content']?.toString() ?? '';
          return Padding(
            padding: EdgeInsets.only(bottom: 8 * fontScale),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10 * fontScale),
              child: InkWell(
                onTap: () => _showNoticeDialog(
                  context,
                  fontScale,
                  i18n,
                  centerName,
                  title,
                  content,
                ),
                borderRadius: BorderRadius.circular(10 * fontScale),
                child: Padding(
                  padding: EdgeInsets.all(14 * fontScale),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (centerName.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(right: 10 * fontScale),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * fontScale,
                            vertical: 4 * fontScale,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '[$centerName]',
                            style: TextStyle(
                              fontSize: 11 * fontScale,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14 * fontScale,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20 * fontScale,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showNoticeDialog(
    BuildContext context,
    double fontScale,
    I18nHelper i18n,
    String centerName,
    String title,
    String content,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(centerName.isNotEmpty ? '[$centerName] $title' : title),
        content: SingleChildScrollView(
          child: SelectableText(
            content,
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

  Future<void> _onStartWork(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> matching,
    double fontScale,
  ) async {
    final i18n = I18nHelper.of(context);
    final id = matching['id'] as int?;
    final centerId =
        ref.read(authProvider).user?.centerId ??
        (matching['center_id'] is int ? matching['center_id'] as int : null) ??
        ref.read(selectedCenterIdProvider);
    if (id == null) return;
    if (centerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.t('home_center_required_retry'))),
        );
      }
      return;
    }
    try {
      await ref
          .read(apiServiceProvider)
          .postHelperMatchingStart(id, centerId: centerId);
      await _loadHelperHome();
      final res = await ref
          .read(apiServiceProvider)
          .getUser(centerId: centerId);
      if (res.data is Map<String, dynamic>) {
        ref
            .read(authProvider.notifier)
            .setSessionFromUser(
              LoginUser.fromJson(res.data as Map<String, dynamic>),
            );
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.t('home_work_start_success'))),
        );
    } on DioException catch (e) {
      if (mounted) {
        final msg = _userFriendlyHelperApiError(
          e,
          i18n.t('home_work_start_failed'),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.t('home_work_start_failed'))),
        );
      }
    }
  }

  Future<void> _onEndWorkWithDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> matching,
    double fontScale,
  ) async {
    final i18n = I18nHelper.of(context);
    // scheduled_end_time = DB 예정 종료 시각 (matchings.end_at)
    final scheduledEndTime = matching['end_at'] != null
        ? DateTime.tryParse(matching['end_at'] as String)
        : null;
    final now = DateTime.now();
    final isEarly = scheduledEndTime != null && now.isBefore(scheduledEndTime);

    final workLogC = TextEditingController();
    final earlyReasonC = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final earlyReasonEmpty = earlyReasonC.text.trim().isEmpty;
            final canConfirm = !isEarly || !earlyReasonEmpty;
            return AlertDialog(
              title: Text(i18n.t('home_work_end_btn')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      i18n.t('home_work_end_log_hint'),
                      style: TextStyle(
                        fontSize: 14 * fontScale,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8 * fontScale),
                    TextField(
                      controller: workLogC,
                      decoration: InputDecoration(
                        hintText: i18n.t('home_work_end_log_label'),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    if (isEarly) ...[
                      SizedBox(height: 16 * fontScale),
                      Container(
                        padding: EdgeInsets.all(12 * fontScale),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error, width: 1),
                        ),
                        child: Text(
                          i18n.t('home_work_end_early_warning'),
                          style: TextStyle(
                            fontSize: 14 * fontScale,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 10 * fontScale),
                      TextField(
                        controller: earlyReasonC,
                        decoration: InputDecoration(
                          hintText: i18n.t('home_work_end_early_reason_hint'),
                          border: const OutlineInputBorder(),
                          errorText: earlyReasonEmpty
                              ? i18n.t('home_work_end_early_reason_required')
                              : null,
                        ),
                        maxLines: 2,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(i18n.t('cancel')),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () {
                          Navigator.of(ctx).pop({
                            'work_log': workLogC.text,
                            'early_end_reason': earlyReasonC.text,
                          });
                        }
                      : null,
                  child: Text(i18n.t('home_work_end_confirm_btn')),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    final id = matching['id'] as int?;
    final centerId =
        ref.read(authProvider).user?.centerId ??
        (matching['center_id'] is int ? matching['center_id'] as int : null) ??
        ref.read(selectedCenterIdProvider);
    if (id == null) return;
    if (centerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.t('home_center_required_retry'))),
        );
      }
      return;
    }
    try {
      await ref
          .read(apiServiceProvider)
          .postHelperMatchingComplete(
            id,
            centerId: centerId,
            workLog: result['work_log']?.toString().trim().isEmpty == true
                ? null
                : result['work_log']?.toString(),
            earlyEndReason:
                result['early_end_reason']?.toString().trim().isEmpty == true
                ? null
                : result['early_end_reason']?.toString(),
            actualEndTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
          );
      await _loadHelperHome();
      final res = await ref
          .read(apiServiceProvider)
          .getUser(centerId: centerId);
      if (res.data is Map<String, dynamic>) {
        ref
            .read(authProvider.notifier)
            .setSessionFromUser(
              LoginUser.fromJson(res.data as Map<String, dynamic>),
            );
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.t('home_work_end_success'))),
        );
    } on DioException catch (e) {
      if (mounted) {
        final msg = _userFriendlyHelperApiError(
          e,
          i18n.t('home_work_end_failed'),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.t('home_work_end_failed'))));
      }
    }
  }

  /// X-Center-Id 누락·권한 등 보호사 API 에러를 사용자 친화적 문구로 변환.
  static String _userFriendlyHelperApiError(DioException e, String fallback) {
    if (e.response?.data is Map) {
      final msg = (e.response!.data as Map)['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
      final code = (e.response!.data as Map)['code']?.toString();
      if (code == 'ERR_AUTH_003') return fallback;
    }
    return fallback;
  }
}
