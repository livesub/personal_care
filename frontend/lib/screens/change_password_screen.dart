import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../utils/i18n_helper.dart';
import '../utils/input_formatters.dart';

/// Case A 전용: 초기 비번 상태에서 반드시 비밀번호 변경 후 이용.
/// 뒤로가기 시 로그아웃 처리.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    final i18n = I18nHelper.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('logout')),
        content: Text(i18n.t('change_password_back_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(i18n.t('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(i18n.t('confirm'))),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    final api = ref.read(apiServiceProvider);
    api.clearMemoryOnlyToken();
    await api.removeToken();
    ref.read(authProvider.notifier).clearSession();
    if (mounted) context.go('/login');
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final i18n = I18nHelper.of(context);

    if (password.isEmpty) {
      setState(() => _errorMessage = i18n.t('validation_admin_password_required'));
      return;
    }
    if (password.length < 10) {
      setState(() => _errorMessage = i18n.t('admin_setup_password_min'));
      return;
    }
    if (!passwordMeetsComplexity(password)) {
      setState(() => _errorMessage = i18n.t('password_rule_full'));
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = i18n.t('admin_setup_password_mismatch'));
      return;
    }

    setState(() => _isLoading = true);
    final api = ref.read(apiServiceProvider);
    final auth = ref.read(authProvider.notifier);

    try {
      await api.changePassword(password, confirm);
      await auth.onPasswordChangeSuccess(null);
      auth.markPasswordChangeComplete();
      if (!mounted) return;
      final isAdmin = ref.read(authProvider).user?.adminId != null;
      context.go(isAdmin ? '/admin/dashboard' : '/home');
    } on DioException catch (e) {
      String? msg;
      if (e.response?.data is Map) {
        final d = e.response!.data as Map<String, dynamic>;
        msg = d['message'] as String?;
        if (msg == null && d['errors'] is Map) {
          final errs = d['errors'] as Map;
          final first = errs['password'] ?? errs['password_confirmation'] ?? (errs.values.isNotEmpty ? errs.values.first : null);
          if (first is List && first.isNotEmpty) msg = first.first.toString();
        }
      }
      setState(() {
        _errorMessage = msg ?? i18n.t('admin_setup_failed');
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = i18n.t('admin_setup_failed');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final i18n = I18nHelper.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(i18n.t('password_change_title')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24 * fontScale),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    i18n.t('change_password_intro'),
                    style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 24 * fontScale),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: i18n.t('new_password'),
                      hintText: i18n.t('admin_setup_password_hint'),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 16 * fontScale),
                  TextFormField(
                    controller: _confirmController,
                    decoration: InputDecoration(
                      labelText: i18n.t('confirm_password'),
                      hintText: i18n.t('admin_setup_confirm_password_hint'),
                    ),
                    obscureText: true,
                  ),
                  if (_errorMessage != null) ...[
                    Padding(
                      padding: EdgeInsets.only(top: 8 * fontScale),
                      child: Text(_errorMessage!, style: TextStyle(color: AppColors.error, fontSize: 14 * fontScale)),
                    ),
                  ],
                  SizedBox(height: 32 * fontScale),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(i18n.t('submit')),
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
