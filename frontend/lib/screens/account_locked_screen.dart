import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../utils/i18n_helper.dart';

/// 3회 취소로 계정 잠금 후 전용 화면. 뒤로가기 차단, 앱 재시작해도 로그인 불가(서버 status=suspended).
class AccountLockedScreen extends StatelessWidget {
  const AccountLockedScreen({super.key, this.extra});

  final Object? extra;

  @override
  Widget build(BuildContext context) {
    final i18n = I18nHelper.of(context);
    final fontScale = MediaQuery.of(context).textScaler.scale(1.0);
    final Map<String, dynamic> data = extra is Map<String, dynamic> ? extra! as Map<String, dynamic> : <String, dynamic>{};
    final String? centerName = data['center_name'] as String?;
    final String? centerPhone = data['center_phone'] as String?;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24 * fontScale),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80 * fontScale,
                  color: AppColors.error,
                ),
                SizedBox(height: 24 * fontScale),
                Text(
                  i18n.t('account_locked_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18 * fontScale,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 32 * fontScale),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20 * fontScale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i18n.t('account_locked_contact_title'),
                        style: TextStyle(
                          fontSize: 14 * fontScale,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 12 * fontScale),
                      if (centerName != null && centerName.isNotEmpty)
                        Text(
                          centerName,
                          style: TextStyle(
                            fontSize: 22 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      if (centerPhone != null && centerPhone.isNotEmpty) ...[
                        SizedBox(height: 8 * fontScale),
                        SelectableText(
                          centerPhone,
                          style: TextStyle(
                            fontSize: 24 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ] else if (centerName != null && centerName.isNotEmpty)
                        Text(
                          i18n.t('account_locked_contact_sub'),
                          style: TextStyle(
                            fontSize: 14 * fontScale,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 40 * fontScale),
                SizedBox(
                  width: double.infinity,
                  height: 52 * fontScale,
                  child: FilledButton(
                    onPressed: () => context.go('/'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      i18n.t('account_locked_confirm'),
                      style: TextStyle(fontSize: 16 * fontScale),
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
