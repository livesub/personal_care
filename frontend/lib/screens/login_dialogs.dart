import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../models/login_response.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/i18n_helper.dart';
import '../utils/input_formatters.dart';

/// 로그인 화면에서만 쓰는 다이얼로그 (환영 카드, 본인 확인, 비밀번호 변경, 최초 로그인 통합).
class LoginDialogs {
  LoginDialogs._();

  /// 최초 로그인: 본인 확인 + 새 비밀번호 입력. 취소/바깥터치/뒤로가기 시 카운트, 3회 시 lock-account API 후 잠금 데이터 반환.
  /// 반환: true(비밀번호 변경 완료), false(취소), Map(계정 잠금 시 extra로 쓸 데이터) → 호출부에서 context.go('/account-locked', extra) 처리.
  static Future<Object?> showFirstLoginIdentityAndPasswordChange(
    BuildContext context,
    LoginUser user,
    String temporaryToken,
    double fontScale,
    I18nHelper i18n,
    ApiService api,
  ) async {
    int cancelCount = 0;
    String? dialogError;
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String lastValidPassword = '';

    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> doLockAndNavigate() async {
            try {
              final data = await api.lockAccount(temporaryToken);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(data);
            } catch (_) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(i18n.t('login_failed'))),
                );
              }
            }
          }

          void handleCancel() {
            final nextCount = cancelCount + 1;
            setState(() => cancelCount = nextCount);
            if (nextCount >= 3) {
              doLockAndNavigate();
            }
          }

          return Stack(
            children: [
              Positioned.fill(
                child: ModalBarrier(
                  color: Colors.black54,
                  dismissible: false,
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: handleCancel,
                ),
              ),
              PopScope(
                canPop: false,
                onPopInvokedWithResult: (bool didPop, dynamic _) {
                  if (!didPop) handleCancel();
                },
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: AlertDialog(
                      title: Text(i18n.t('identity_confirm_title')),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (user.name != null && user.name!.isNotEmpty) Text('${i18n.t('identity_label_name')}: ${user.name}', style: TextStyle(fontSize: 14 * fontScale)),
                            if (user.centerName != null) Text('${i18n.t('identity_label_center')}: ${user.centerName}', style: TextStyle(fontSize: 14 * fontScale)),
                            if (user.phoneFormatted != null) Text('${i18n.t('identity_label_phone')}: ${user.phoneFormatted}', style: TextStyle(fontSize: 14 * fontScale)),
                            if (user.residentMasked != null) Text('${i18n.t('identity_label_resident')}: ${user.residentMasked}', style: TextStyle(fontSize: 14 * fontScale)),
                            if (cancelCount > 0) ...[
                              SizedBox(height: 12 * fontScale),
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18 * fontScale, color: AppColors.error),
                                  SizedBox(width: 6 * fontScale),
                                  Text(
                                    i18n.t('identity_cancel_count_message').replaceAll('{{count}}', cancelCount.toString()),
                                    style: TextStyle(fontSize: 14 * fontScale, color: AppColors.error, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(width: 8 * fontScale),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10 * fontScale, vertical: 4 * fontScale),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('$cancelCount / 3', style: TextStyle(fontSize: 13 * fontScale, fontWeight: FontWeight.bold, color: AppColors.error)),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: 20 * fontScale),
                            Text(i18n.t('password_change_title'), style: TextStyle(fontSize: 14 * fontScale, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8 * fontScale),
                            TextField(
                              controller: newPasswordController,
                              obscureText: true,
                              inputFormatters: [LowercaseTextInputFormatter()],
                              onChanged: (v) {
                                if (passwordTextAllowed(v)) {
                                  lastValidPassword = v;
                                } else {
                                  final valid = lastValidPassword;
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    try {
                                      if (newPasswordController.text != valid) {
                                        newPasswordController.text = valid;
                                        newPasswordController.selection = TextSelection.collapsed(offset: valid.length);
                                      }
                                    } catch (_) {}
                                  });
                                }
                                setState(() => dialogError = null);
                              },
                              decoration: InputDecoration(
                                labelText: i18n.t('new_password'),
                                hintText: i18n.t('password_hint'),
                                border: const OutlineInputBorder(),
                              ),
                              style: TextStyle(fontSize: 16 * fontScale),
                            ),
                            SizedBox(height: 12 * fontScale),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: true,
                              inputFormatters: [LowercaseTextInputFormatter()],
                              onChanged: (_) => setState(() => dialogError = null),
                              decoration: InputDecoration(
                                labelText: i18n.t('confirm_password'),
                                hintText: i18n.t('password_hint'),
                                border: const OutlineInputBorder(),
                              ),
                              style: TextStyle(fontSize: 16 * fontScale),
                            ),
                            if (dialogError != null && dialogError!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 8 * fontScale),
                                child: Text(
                                  dialogError!,
                                  style: TextStyle(fontSize: 13 * fontScale, color: AppColors.error, fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: handleCancel,
                          child: Text(i18n.t('cancel')),
                        ),
                        FilledButton(
                          onPressed: () async {
                            setState(() => dialogError = null);
                            final newPw = newPasswordController.text;
                            final confirmPw = confirmPasswordController.text;
                            if (newPw != confirmPw) {
                              setState(() => dialogError = i18n.t('admin_setup_password_mismatch'));
                              return;
                            }
                            if (newPw.length < 10 || !passwordMeetsComplexity(newPw)) {
                              setState(() => dialogError = i18n.t('password_rule_full'));
                              return;
                            }
                            if (!passwordTextAllowed(newPw)) {
                              setState(() => dialogError = i18n.t('snackbar_invalid_char'));
                              return;
                            }
                    try {
                      await api.completeFirstLogin(temporaryToken, newPw, confirmPw);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop<bool>(true);
                            } on DioException catch (e) {
                              String? msg;
                              if (e.response?.data is Map) {
                                final d = e.response!.data as Map<String, dynamic>;
                                msg = d['message'] as String?;
                              }
                              if (ctx.mounted) setState(() => dialogError = msg ?? i18n.t('login_failed'));
                            }
                          },
                          child: Text(i18n.t('confirm')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        newPasswordController.dispose();
        confirmPasswordController.dispose();
      });
    });
    return result;
  }

  /// 로그인 성공 후 환영 카드. care_img1 + Personal Care + "이름님, 환영합니다" + [홈으로] 버튼.
  static Future<void> showWelcomeCard(
    BuildContext context,
    String userName,
    double fontScale,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Container(
          padding: EdgeInsets.all(24 * fontScale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/care_img1.png',
                  height: 120 * fontScale,
                  width: 120 * fontScale,
                  fit: BoxFit.cover,
                  errorBuilder: (Object o, Object err, StackTrace? st) => Container(
                    height: 120 * fontScale,
                    width: 120 * fontScale,
                    color: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.favorite, size: 56 * fontScale, color: AppColors.primary),
                  ),
                ),
              ),
              SizedBox(height: 16 * fontScale),
              Text(
                I18nHelper.of(context).t('app_name'),
                style: TextStyle(
                  fontSize: 18 * fontScale,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 20 * fontScale),
              Text(
                userName.trim().isEmpty
                    ? I18nHelper.of(context).t('welcome_short')
                    : I18nHelper.of(context).t('welcome_with_name').replaceAll('{{name}}', userName),
                style: TextStyle(
                  fontSize: 22 * fontScale,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24 * fontScale),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14 * fontScale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(I18nHelper.of(context).t('go_home'), style: TextStyle(fontSize: 16 * fontScale)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 본인 확인 팝업. 확인 시 true, 3회 취소 시 잠금 처리 후 false.
  static Future<bool?> showIdentityVerification(
    BuildContext context,
    LoginResponse response,
    ApiService api,
    AuthNotifier auth,
    I18nHelper i18n,
  ) async {
    final user = response.user!;
    int cancelCount = 0;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final fontScale = MediaQuery.of(context).textScaler.scale(1.0);
          return AlertDialog(
            title: Text(i18n.t('identity_confirm_title')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name ?? ''),
                  if (user.centerName != null) Text(user.centerName!),
                  if (user.phoneFormatted != null) Text(user.phoneFormatted!),
                  if (user.residentMasked != null) Text(user.residentMasked!),
                  if (cancelCount > 0) ...[
                    SizedBox(height: 12 * fontScale),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18 * fontScale, color: AppColors.error),
                        SizedBox(width: 6 * fontScale),
                        Flexible(
                          child: Text(
                            i18n.t('identity_cancel_count_message').replaceAll('{{count}}', cancelCount.toString()),
                            style: TextStyle(fontSize: 14 * fontScale, color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                        ),
                        SizedBox(width: 8 * fontScale),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10 * fontScale, vertical: 4 * fontScale),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$cancelCount / 3', style: TextStyle(fontSize: 13 * fontScale, fontWeight: FontWeight.bold, color: AppColors.error)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  setState(() => cancelCount++);
                  if (cancelCount >= 3) {
                    Navigator.of(ctx).pop(false);
                    try {
                      await api.lock();
                    } catch (_) {}
                    await auth.logout();
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (c) => AlertDialog(
                        content: Text(i18n.t('identity_lock_message')),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(c).pop();
                              context.go('/');
                            },
                            child: Text(i18n.t('confirm')),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: Text(i18n.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(i18n.t('confirm')),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 비밀번호 변경 팝업. 제출 완료 시 호출부에서 로그아웃 후 로그인 화면으로 이동.
  static Future<void> showPasswordChange(
    BuildContext context,
    double fontScale,
    ApiService api,
    I18nHelper i18n,
  ) async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('password_change_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: i18n.t('new_password'),
                  hintText: i18n.t('password_hint'),
                ),
                autofillHints: const [AutofillHints.newPassword],
              ),
              SizedBox(height: 12 * fontScale),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: i18n.t('confirm_password'),
                  hintText: i18n.t('password_hint'),
                ),
                autofillHints: const [AutofillHints.password],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(i18n.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final newPw = newPasswordController.text;
              final confirmPw = confirmPasswordController.text;
              if (newPw != confirmPw) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(i18n.t('password_confirmation_mismatch'))),
                );
                return;
              }
              try {
                await api.changePassword(newPw, confirmPw);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(i18n.t('password_change_success'))),
                );
              } on DioException catch (e) {
                String? msg;
                if (e.response?.data is Map) {
                  final d = e.response!.data as Map<String, dynamic>;
                  msg = d['message'] as String?;
                }
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg ?? i18n.t('login_failed'))),
                  );
                }
              }
            },
            child: Text(i18n.t('submit')),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        newPasswordController.dispose();
        confirmPasswordController.dispose();
      });
    });
  }
}
