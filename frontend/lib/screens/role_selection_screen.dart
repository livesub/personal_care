import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../providers/font_scale_provider.dart';
import '../utils/i18n_helper.dart';
import '../widgets/project_guide_dialog.dart';

/// 역할 선택 화면
/// 장애인 보호사 or 관리자 선택. initialRole == 'admin'이면 관리자 버튼을 선택된 것처럼 강조.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key, this.initialRole});

  /// URL query role=admin 등으로 진입 시 해당 역할 버튼 강조 (관리자 탭 선택 효과)
  final String? initialRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontScaleProvider);
    final highlightAdmin = initialRole == 'admin';

    return Scaffold(
      // 배경색: 흰색 (디자인 변경 시 여기 수정)
      backgroundColor: Colors.white,
      
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                // 전체 여백 (디자인 변경 시 여기 수정)
                padding: EdgeInsets.all(40 * fontScale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
              // 앱 이름 (이미지 위에 위치) - 예쁜 디자인
              Text(
                I18nHelper.of(context).t('app_name'),
                style: TextStyle(
                  fontSize: 42 * fontScale, // 큰 텍스트 크기 (디자인 변경 시 여기 수정)
                  fontWeight: FontWeight.w800, // 굵은 글씨
                  color: AppColors.primary, // Green 톤 (디자인 변경 시 여기 수정)
                  letterSpacing: 2.0, // 넓은 자간 (디자인 변경 시 여기 수정)
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.1), // 은은한 그림자 (디자인 변경 시 여기 수정)
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30 * fontScale), // 간격 (디자인 변경 시 여기 수정)
              
              // 메인 이미지: 장애인과 보호사 (크게, 동적 효과)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0), // 크기 애니메이션 (디자인 변경 시 여기 수정)
                duration: const Duration(milliseconds: 800), // 애니메이션 속도 (디자인 변경 시 여기 수정)
                curve: Curves.easeOutBack, // 튕기는 효과 (디자인 변경 시 여기 수정)
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 280 * fontScale, // 큰 이미지 크기 (디자인 변경 시 여기 수정)
                      height: 280 * fontScale,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(140 * fontScale), // 원형
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2), // Green 톤 그림자 (디자인 변경 시 여기 수정)
                            blurRadius: 30 * fontScale, // 그림자 크기 (디자인 변경 시 여기 수정)
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/care_img1.png', // 장애인과 보호사 이미지 (디자인 변경 시 여기 수정)
                          fit: BoxFit.cover,
                          alignment: Alignment.center, // 중앙 정렬 (디자인 변경 시 여기 수정)
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: 60 * fontScale), // 간격 (디자인 변경 시 여기 수정)
              
              // 장애인 보호사 버튼
              _buildRoleButton(
                context: context,
                fontScale: fontScale,
                icon: Icons.favorite_border, // 하트 아이콘 (디자인 변경 시 여기 수정)
                label: I18nHelper.of(context).t('role_helper'),
                backgroundColor: const Color(0xFF81C9E8), // 파란색 톤 (디자인 변경 시 여기 수정)
                onTap: () {
                  context.push('/login?role=helper');
                },
                highlighted: false,
              ),
              
              SizedBox(height: 20 * fontScale), // 버튼 간격 (디자인 변경 시 여기 수정)
              
              // 관리자 버튼 (role=admin으로 진입 시 선택된 것처럼 강조)
              _buildRoleButton(
                context: context,
                fontScale: fontScale,
                icon: Icons.admin_panel_settings, // 관리자 아이콘 (디자인 변경 시 여기 수정)
                label: I18nHelper.of(context).t('tab_admin'),
                backgroundColor: AppColors.primary, // Green 톤 (디자인 변경 시 여기 수정)
                onTap: () {
                  context.push('/login?role=admin');
                },
                highlighted: highlightAdmin,
              ),
              SizedBox(height: 16 * fontScale),
              // 비밀번호 찾기 (작게) → 보호사 비밀번호 찾기 화면으로
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: TextStyle(fontSize: 13 * fontScale),
                ),
                child: Text(I18nHelper.of(context).t('forgot_title')),
              ),
                ],
              ),
            ),
          ),
        ),
        // [프로젝트 가이드] 버튼 (하단, 눈에 띄게)
        Padding(
          padding: EdgeInsets.all(24 * fontScale),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => showProjectGuideDialog(context),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 18 * fontScale),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: TextStyle(fontSize: 18 * fontScale, fontWeight: FontWeight.bold),
              ),
              child: const Text('프로젝트 가이드'),
            ),
          ),
        ),
      ],
    ),
    );
  }

  /// 역할 선택 버튼 위젯. highlighted 시 관리자 탭 선택된 것처럼 테두리 강조.
  Widget _buildRoleButton({
    required BuildContext context,
    required double fontScale,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30 * fontScale), // 둥근 정도 (디자인 변경 시 여기 수정)
      child: Container(
        width: double.infinity, // 전체 너비
        padding: EdgeInsets.symmetric(
          horizontal: 40 * fontScale,
          vertical: 20 * fontScale,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30 * fontScale),
          border: highlighted
              ? Border.all(color: Colors.white, width: 3 * fontScale)
              : null,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 15 * fontScale,
              offset: Offset(0, 8 * fontScale),
            ),
            if (highlighted)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 20 * fontScale,
                spreadRadius: 2 * fontScale,
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘
            Icon(
              icon,
              color: Colors.white,
              size: 28 * fontScale, // 아이콘 크기 (디자인 변경 시 여기 수정)
            ),
            SizedBox(width: 12 * fontScale), // 간격 (디자인 변경 시 여기 수정)
            // 텍스트
            Text(
              label,
              style: TextStyle(
                fontSize: 18 * fontScale, // 텍스트 크기 (디자인 변경 시 여기 수정)
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
