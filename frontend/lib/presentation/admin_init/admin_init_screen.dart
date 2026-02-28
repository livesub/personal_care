import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/login_form_provider.dart';
import '../../screens/change_password_screen.dart';
import '../../utils/auth_guard_util.dart';
import '../../utils/input_formatters.dart';
import '../../utils/i18n_helper.dart';
import '../../utils/prevent_back_util_stub.dart' if (dart.library.html) '../../utils/prevent_back_util_web.dart' as prevent_back_util;

/// 초기 관리자 설정 일원화: must_change_password면 비밀번호 변경, 임시 계정이면 아이디/비번 설정.
/// 경로: /admin-init (최상위 라우트).
class AdminInitScreen extends ConsumerWidget {
  const AdminInitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.isInitialPasswordState) {
      return const ChangePasswordScreen();
    }
    return const _AdminAccountSetupContent();
  }
}

/// 임시 관리자(admin) 계정 전환. 새 로그인 ID + 비밀번호 설정. 취소/뒤로가기 없음.
class _AdminAccountSetupContent extends ConsumerStatefulWidget {
  const _AdminAccountSetupContent();

  @override
  ConsumerState<_AdminAccountSetupContent> createState() => _AdminAccountSetupContentState();
}

class _AdminAccountSetupContentState extends ConsumerState<_AdminAccountSetupContent> {
  final _formKey = GlobalKey<FormState>();
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _passwordError;

  static const List<String> _loginIdBlacklist = [
    'admin', 'manager', 'root', 'staff', 'system',
  ];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _passwordConfirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  bool _isBlacklisted(String value) => _loginIdBlacklist.contains(value.trim().toLowerCase());

  Future<void> _submit(BuildContext context) async {
    final i18n = I18nHelper.of(context);
    setState(() { _errorMessage = null; _passwordError = null; });
    if (!_formKey.currentState!.validate()) return;
    final newLoginId = _loginIdController.text.trim().toLowerCase();
    if (_isBlacklisted(newLoginId)) {
      setState(() => _errorMessage = i18n.t('admin_setup_id_blocked'));
      return;
    }
    final pwd = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    if (pwd.isEmpty) {
      setState(() => _passwordError = i18n.t('validation_admin_password_required'));
      return;
    }
    if (pwd.length < 10) {
      setState(() => _passwordError = i18n.t('admin_setup_password_min'));
      return;
    }
    if (!passwordMeetsComplexity(pwd)) {
      setState(() => _passwordError = i18n.t('password_rule_full'));
      return;
    }
    if (pwd != confirm) {
      setState(() => _passwordError = i18n.t('admin_setup_password_mismatch'));
      return;
    }
    setState(() => _isLoading = true);
    final api = ref.read(apiServiceProvider);
    final auth = ref.read(authProvider.notifier);
    final fallbackFailed = i18n.t('admin_setup_failed');
    try {
      final res = await api.post('/admin/complete-setup', data: {
        'new_login_id': newLoginId,
        'new_password': _passwordController.text,
        'new_password_confirmation': _passwordConfirmController.text,
      });
      final body = res.data;
      final wasTempAdmin = body is Map<String, dynamic> && (body['was_temp_admin'] == true || body['was_temp_admin'] == 1);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: SelectableText(i18n.t('admin_setup_dialog_title')),
          content: SelectableText(i18n.t('security_relogin_message')),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n.t('confirm')))],
        ),
      );
      if (!mounted) return;
      if (wasTempAdmin) {
        await api.removeToken();
        auth.clearSession();
        ref.invalidate(selectedCenterIdProvider);
        ref.invalidate(authProvider);
        context.go('/login?role=admin');
        prevent_back_util.preventBackToAdminSession();
      } else {
        context.go('/home');
      }
    } on DioException catch (e) {
      String? msg = fallbackFailed;
      if (e.response?.data is Map) {
        final d = e.response!.data as Map<String, dynamic>;
        if (d['errors'] is Map) {
          final errs = d['errors'] as Map;
          final first = errs['new_login_id'];
          if (first is List && first.isNotEmpty) msg = first.first.toString();
        }
        msg = d['message'] as String? ?? msg;
      }
      setState(() { _errorMessage = msg; _isLoading = false; });
    } catch (_) {
      setState(() { _errorMessage = fallbackFailed; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final currentLocale = ref.watch(localeProvider);
    final i18n = I18nHelper.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        final loginId = ref.read(authProvider).user?.loginId;
        if (mounted && isTempAdminLoginId(loginId)) {
          ref.read(authProvider.notifier).clearSession();
          ref.read(apiServiceProvider).removeToken();
          ref.invalidate(selectedCenterIdProvider);
          ref.invalidate(authProvider);
          context.go('/login?role=admin');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Container(
                width: 40 * fontScale,
                height: 40 * fontScale,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20 * fontScale), color: AppColors.background),
                child: ClipOval(child: Image.asset('assets/images/care_img1.png', fit: BoxFit.cover, alignment: Alignment.center)),
              ),
              SizedBox(width: 12 * fontScale),
              Text(i18n.t('admin_setup_title'), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20 * fontScale)),
            ],
          ),
          actions: [
            Tooltip(
              message: i18n.t('font_size'),
              child: IconButton(icon: Icon(Icons.text_fields, color: AppColors.textSecondary, size: 24 * fontScale), onPressed: () => ref.read(fontScaleProvider.notifier).toggleScale()),
            ),
            Padding(
              padding: EdgeInsets.only(right: 8 * fontScale),
              child: DropdownButton<String>(
                value: currentLocale.languageCode,
                icon: Icon(Icons.language, color: AppColors.textSecondary, size: 24 * fontScale),
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'ko', child: Text(i18n.t('language_ko'))),
                  DropdownMenuItem(value: 'en', child: Text(i18n.t('language_en'))),
                  DropdownMenuItem(value: 'vi', child: Text(i18n.t('language_vi'))),
                ],
                onChanged: (String? value) { if (value != null) ref.read(localeProvider.notifier).changeLocale(value); },
                style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24 * fontScale),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 24 * fontScale),
                  Center(
                    child: Container(
                      width: 100 * fontScale,
                      height: 100 * fontScale,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(50 * fontScale), color: AppColors.background),
                      child: ClipOval(child: Image.asset('assets/images/care_img1.png', fit: BoxFit.cover, alignment: Alignment.center)),
                    ),
                  ),
                  SizedBox(height: 24 * fontScale),
                  SelectableText(i18n.t('admin_setup_intro'), style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary)),
                  SizedBox(height: 32 * fontScale),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: EdgeInsets.all(12 * fontScale),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: SelectableText(_errorMessage!, style: TextStyle(fontSize: 14 * fontScale, color: AppColors.error)),
                    ),
                    SizedBox(height: 16 * fontScale),
                  ],
                  TextFormField(
                    controller: _loginIdController,
                    decoration: InputDecoration(
                      labelText: i18n.t('admin_setup_new_id'),
                      hintText: i18n.t('admin_setup_new_id_hint'),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12 * fontScale)),
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LowercaseTextInputFormatter()],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return i18n.t('admin_setup_enter_id');
                      if (_isBlacklisted(v)) return i18n.t('admin_setup_id_blocked');
                      return null;
                    },
                  ),
                  SizedBox(height: 16 * fontScale),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: i18n.t('admin_setup_new_password'),
                      hintText: i18n.t('admin_setup_password_hint'),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12 * fontScale)),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _passwordError = null),
                  ),
                  SizedBox(height: 16 * fontScale),
                  TextFormField(
                    controller: _passwordConfirmController,
                    decoration: InputDecoration(
                      labelText: i18n.t('admin_setup_confirm_password'),
                      hintText: i18n.t('admin_setup_confirm_password_hint'),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12 * fontScale)),
                    ),
                    obscureText: true,
                    onChanged: (_) => setState(() => _passwordError = null),
                  ),
                  if (_passwordError != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8 * fontScale),
                      child: SelectableText(_passwordError!, style: TextStyle(fontSize: 13 * fontScale, color: AppColors.error)),
                    ),
                  SizedBox(height: 32 * fontScale),
                  SizedBox(
                    height: 52 * fontScale,
                    child: FilledButton(
                      onPressed: _isLoading ? null : () => _submit(context),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: _isLoading ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(i18n.t('admin_setup_submit')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
