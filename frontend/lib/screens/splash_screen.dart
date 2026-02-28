import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../models/login_response.dart';
import '../providers/auth_provider.dart';
import '../providers/login_form_provider.dart';
import '../utils/i18n_helper.dart';

/// 스플래시 화면
/// 앱 시작 시 토큰 유무 확인 → GET /user로 세션 복원 후 홈 또는 역할선택으로 이동
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // 인증 확인이 끝날 때까지 대기 후 진행 (짧은 딜레이로 스플래시 노출)
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final api = ref.read(apiServiceProvider);
    final authNotifier = ref.read(authProvider.notifier);
    await ref.read(selectedCenterIdProvider.notifier).loadFromPrefs();
    if (!mounted) return;
    final token = await api.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      authNotifier.finishInitialization();
      if (!mounted) return;
      context.go('/role-selection');
      return;
    }
    final centerId = ref.read(selectedCenterIdProvider);
    try {
      final res = await api.getUser(centerId: centerId);
      if (!mounted) return;
      if (res.statusCode == null || res.statusCode! < 200 || res.statusCode! >= 300) {
        await api.removeToken();
        authNotifier.finishInitialization();
        if (!mounted) return;
        context.go('/role-selection');
        return;
      }
      final data = res.data;
      if (data == null || data is! Map<String, dynamic>) {
        await api.removeToken();
        authNotifier.finishInitialization();
        if (!mounted) return;
        context.go('/role-selection');
        return;
      }
      final user = LoginUser.fromJson(data);
      if (user.userId == null && user.adminId == null) {
        await api.removeToken();
        authNotifier.finishInitialization();
        if (!mounted) return;
        context.go('/role-selection');
        return;
      }
      final needPasswordChange = data['need_password_change'] == true ||
          data['need_password_change'] == 1 ||
          (data['need_password_change'] is String && (data['need_password_change'] as String).toLowerCase() == 'true');
      authNotifier.setSessionFromUserWithPasswordChange(user, needPasswordChange);
      if (user.centerId != null) {
        ref.read(selectedCenterIdProvider.notifier).select(user.centerId);
      }
      if (!mounted) return;
      final isAdmin = user.adminId != null;
      if (isAdmin && needPasswordChange) {
        context.go('/admin-init');
      } else {
        context.go(isAdmin ? '/admin/dashboard' : '/home');
      }
    } catch (e) {
      await api.removeToken();
      authNotifier.finishInitialization();
      if (!mounted) return;
      context.go('/role-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색: 흰색 (디자인 변경 시 여기 수정)
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 이미지: 장애인과 보호사 (디자인 변경 시 여기 수정)
            ClipRRect(
              borderRadius: BorderRadius.circular(20), // 둥근 모서리 (디자인 변경 시 여기 수정)
              child: Container(
                padding: const EdgeInsets.all(32), // 이미지 여백 (디자인 변경 시 여기 수정)
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08), // 그림자 투명도 (디자인 변경 시 여기 수정)
                      blurRadius: 30, // 그림자 흐림 정도 (디자인 변경 시 여기 수정)
                      offset: const Offset(0, 10), // 그림자 위치 (디자인 변경 시 여기 수정)
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 크롭된 이미지: 중앙 아이콘 부분만 표시
                    // 원본 이미지의 중앙 부분(휠체어+보호사)만 클립
                    Container(
                      width: 200, // 이미지 너비 (디자인 변경 시 여기 수정)
                      height: 200, // 이미지 높이 (디자인 변경 시 여기 수정)
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100), // 원형으로 (디자인 변경 시 여기 수정)
                        color: AppColors.background,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/care_img1.png', // 스플래시 로딩 이미지 (디자인 변경 시 여기 수정)
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, Object error, StackTrace? stackTrace) => Icon(Icons.image_not_supported, size: 80, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // 간격 (디자인 변경 시 여기 수정)
                    
                    // 앱 이름
                    Text(
                      I18nHelper.of(context).t('app_name'),
                      style: TextStyle(
                        fontSize: 32, // 텍스트 크기 (디자인 변경 시 여기 수정)
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.2, // 자간 (디자인 변경 시 여기 수정)
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50), // 간격 (디자인 변경 시 여기 수정)
            
            // 로딩 인디케이터: Green 톤
            SizedBox(
              width: 40, // 인디케이터 크기 (디자인 변경 시 여기 수정)
              height: 40,
              child: CircularProgressIndicator(
                color: AppColors.primary, // Green 톤 (디자인 변경 시 여기 수정)
                strokeWidth: 3, // 선 두께 (디자인 변경 시 여기 수정)
              ),
            ),
            const SizedBox(height: 20), // 간격 (디자인 변경 시 여기 수정)
            
            // 로딩 텍스트
            Text(
              '잠시만 기다려주세요...',
              style: TextStyle(
                fontSize: 15, // 텍스트 크기 (디자인 변경 시 여기 수정)
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
