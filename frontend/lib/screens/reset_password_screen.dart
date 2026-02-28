import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../utils/i18n_helper.dart';
import '../utils/input_formatters.dart';

/// 화면 2: 새 비밀번호 설정 (딥링크 전용 진입)
/// • 이메일 링크를 통해서만 접근. 새 비밀번호(확인 포함) 입력 및 유효성 검사.
/// • 저장 시 소문자 변환 + Argon2id 암호화(백엔드) 필수.
/// 화면 3: 완료 시 '재설정 완료' 표시, [로그인으로 이동] 버튼 → 로그인 페이지.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? token;
  final String? email;

  const ResetPasswordScreen({super.key, this.token, this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _lastValidPassword = '';
  bool _submitting = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final t = widget.token?.trim().isNotEmpty ?? false;
    final e = widget.email?.trim().isNotEmpty ?? false;
    final p = _passwordController.text;
    final c = _confirmController.text;
    return t && e && p.length >= 10 && passwordMeetsComplexity(p) && p == c;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    final password = _passwordController.text;
    if (!passwordTextAllowed(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18nHelper.of(context).t('snackbar_invalid_char'))),
      );
      return;
    }
    setState(() => _submitting = true);
    final api = ref.read(apiServiceProvider);
    try {
      await api.post('/helper/reset-password', data: {
        'email': widget.email,
        'token': widget.token,
        'password': password.toLowerCase(),
        'password_confirmation': _confirmController.text.toLowerCase(),
      });
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e.response?.data is Map && (e.response!.data as Map).containsKey('message')
          ? (e.response!.data as Map)['message'] as String?
          : (e.response?.data is Map && (e.response!.data as Map).containsKey('errors')
              ? '링크가 만료되었거나 잘못되었습니다.'
              : '요청에 실패했습니다.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg ?? '오류가 발생했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final i18n = I18nHelper.of(context);
    if (widget.token == null || widget.token!.isEmpty || widget.email == null || widget.email!.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24 * fontScale),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  i18n.t('reset_invalid_link'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16 * fontScale),
                ),
                SizedBox(height: 24 * fontScale),
                TextButton(
                  onPressed: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      context.go('/login?role=helper');
                    });
                  },
                  child: Text(i18n.t('reset_go_login')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_success) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24 * fontScale),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/password_reset_success.png',
                    width: 240 * fontScale,
                    height: 240 * fontScale,
                    fit: BoxFit.contain,
                    errorBuilder: (Object o, Object err, StackTrace? st) => Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 120 * fontScale,
                    ),
                  ),
                  SizedBox(height: 24 * fontScale),
                  Text(
                    i18n.t('reset_success_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22 * fontScale, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 12 * fontScale),
                  Text(
                    i18n.t('reset_success_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16 * fontScale, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 32 * fontScale),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!context.mounted) return;
                          context.go('/login?role=helper');
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 16 * fontScale),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(i18n.t('reset_go_login_btn')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(i18n.t('reset_form_title'), style: TextStyle(color: AppColors.textPrimary, fontSize: 18 * fontScale)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24 * fontScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              inputFormatters: [LowercaseTextInputFormatter()],
              onChanged: (value) {
                if (passwordTextAllowed(value)) {
                  _lastValidPassword = value;
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _passwordController.text = _lastValidPassword;
                      _passwordController.selection = TextSelection.collapsed(offset: _lastValidPassword.length);
                    }
                  });
                }
              },
              decoration: _decoration(fontScale, i18n.t('new_password'), i18n.t('password_rule_full')),
              style: TextStyle(fontSize: 16 * fontScale),
            ),
            SizedBox(height: 8 * fontScale),
            _buildRuleRow(fontScale, i18n.t('password_rule_length'), passwordMeetsLength(_passwordController.text)),
            SizedBox(height: 4 * fontScale),
            _buildRuleRow(fontScale, i18n.t('password_rule_complexity'), passwordMeetsComplexity(_passwordController.text)),
            SizedBox(height: 16 * fontScale),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              inputFormatters: [LowercaseTextInputFormatter()],
              decoration: _decoration(fontScale, i18n.t('confirm_password'), i18n.t('reset_confirm_password_hint')),
              style: TextStyle(fontSize: 16 * fontScale),
            ),
            if (_confirmController.text.isNotEmpty && _passwordController.text != _confirmController.text)
              Padding(
                padding: EdgeInsets.only(top: 8 * fontScale),
                child: Text(
                  i18n.t('password_confirmation_mismatch'),
                  style: TextStyle(fontSize: 13 * fontScale, color: AppColors.error),
                ),
              ),
            SizedBox(height: 32 * fontScale),
            SizedBox(
              height: 56 * fontScale,
              child: ElevatedButton(
                onPressed: _canSubmit && !_submitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * fontScale)),
                ),
                child: _submitting
                    ? SizedBox(
                        height: 20 * fontScale,
                        width: 20 * fontScale,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('비밀번호 변경'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleRow(double fontScale, String label, bool met) {
    return Row(
      children: [
        Icon(met ? Icons.check_circle : Icons.cancel, size: 18 * fontScale, color: met ? AppColors.primary : AppColors.error),
        SizedBox(width: 6 * fontScale),
        Text(label, style: TextStyle(fontSize: 13 * fontScale, color: met ? AppColors.primary : AppColors.error)),
      ],
    );
  }

  InputDecoration _decoration(double fontScale, String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12 * fontScale), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12 * fontScale), borderSide: BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 16 * fontScale),
    );
  }
}
