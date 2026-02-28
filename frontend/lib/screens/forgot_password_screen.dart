import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/i18n_helper.dart';
import '../utils/input_formatters.dart';

/// 화면 1: 비밀번호 찾기 (정보 입력)
/// • 로그인 화면 하단 링크를 통해 진입.
/// • 상단 [보호사], [관리자] 탭으로 입력 폼 구분.
/// • 보호사: 이름, 아이디, 주민번호, 받을 이메일.
/// • 관리자: 이름, 소속 센터, 아이디, 받을 이메일.
/// • 정보 일치 시 입력된 이메일로 링크 발송 → 성공/실패 팝업 표시 → 확인 시 현재 화면 유지(페이지 이동 금지).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// 0 = 보호사, 1 = 관리자 (이메일 발송 결과 확인 후 해당 탭으로 복귀용)
  final int initialTab;

  const ForgotPasswordScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _loginIdController = TextEditingController();
  final _rrnPrefixController = TextEditingController(); // 주민 앞 6자리
  final _rrnSuffixFirstController = TextEditingController(); // 주민 뒤 1자리
  final _emailController = TextEditingController();
  int? _selectedCenterId;
  List<Map<String, dynamic>> _centers = [];
  bool _loadingCenters = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    _loadCenters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _loginIdController.dispose();
    _rrnPrefixController.dispose();
    _rrnSuffixFirstController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCenters() async {
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.get('/centers');
      if (res.data is List && mounted) {
        setState(() {
          _centers = (res.data as List)
              .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
              .toList();
          _loadingCenters = false;
          if (_centers.isNotEmpty && _selectedCenterId == null) {
            _selectedCenterId = _centers.first['id'] as int?;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCenters = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showEmailFailureDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Text(I18nHelper.of(ctx).t('forgot_failed')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(I18nHelper.of(ctx).t('confirm')),
          ),
        ],
      ),
    );
  }

  void _showEmailSuccessDialog(String email) {
    if (!mounted) return;
    final fontScale = ref.read(fontScaleProvider);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final i18n = I18nHelper.of(ctx);
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i18n.t('forgot_email_sent_to').replaceAll('{{email}}', email)),
              SizedBox(height: 8 * fontScale),
              Text(i18n.t('forgot_check_spam')),
              SizedBox(height: 12 * fontScale),
              Text(
                i18n.t('forgot_email_sent_note'),
                style: TextStyle(
                  fontSize: 14 * fontScale,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB71C1C),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(i18n.t('confirm')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitHelper() async {
    final name = _nameController.text.trim();
    final loginId = _loginIdController.text.replaceAll(RegExp(r'\D'), '');
    final rrnPrefix = _rrnPrefixController.text.trim();
    final rrnSuffixFirst = _rrnSuffixFirstController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || loginId.isEmpty || rrnPrefix.length != 6 || rrnSuffixFirst.length != 1 || email.isEmpty) {
      _showError(I18nHelper.of(context).t('forgot_all_required'));
      return;
    }
    setState(() => _submitting = true);
    final api = ref.read(apiServiceProvider);
    try {
      await api.post('/helper/forgot-password', data: {
        'name': name,
        'login_id': _loginIdController.text.trim(),
        'resident_no_prefix': rrnPrefix,
        'resident_no_suffix_first': rrnSuffixFirst,
        'email': email,
      });
      if (!mounted) return;
      _showEmailSuccessDialog(email);
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status != null && status >= 500) {
        _showEmailFailureDialog();
      } else {
        final i18n = I18nHelper.of(context);
        final msg = e.response?.data is Map && (e.response!.data as Map).containsKey('message')
            ? (e.response!.data as Map)['message'] as String?
            : i18n.t('forgot_unmatched');
        _showError(msg ?? i18n.t('forgot_unmatched'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitAdmin() async {
    final name = _nameController.text.trim();
    final loginId = _loginIdController.text.replaceAll(RegExp(r'\D'), '');
    final email = _emailController.text.trim();
    if (name.isEmpty || _selectedCenterId == null || loginId.isEmpty || email.isEmpty) {
      _showError(I18nHelper.of(context).t('forgot_all_required_admin'));
      return;
    }
    setState(() => _submitting = true);
    final api = ref.read(apiServiceProvider);
    try {
      await api.post('/admin/forgot-password', data: {
        'name': name,
        'center_id': _selectedCenterId,
        'login_id': _loginIdController.text.trim(),
        'email': email,
      });
      if (!mounted) return;
      _showEmailSuccessDialog(email);
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status != null && status >= 500) {
        _showEmailFailureDialog();
      } else {
        final i18n = I18nHelper.of(context);
        final msg = e.response?.data is Map && (e.response!.data as Map).containsKey('message')
            ? (e.response!.data as Map)['message'] as String?
            : i18n.t('forgot_unmatched');
        _showError(msg ?? i18n.t('forgot_unmatched'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final currentLocale = ref.watch(localeProvider);
    final i18n = I18nHelper.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 24 * fontScale),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40 * fontScale,
              height: 40 * fontScale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20 * fontScale),
                color: AppColors.background,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/care_img1.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
            SizedBox(width: 12 * fontScale),
            Text(
              i18n.t('forgot_title'),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20 * fontScale,
              ),
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: i18n.t('font_size'),
            child: IconButton(
              icon: Icon(Icons.text_fields, color: AppColors.textSecondary, size: 24 * fontScale),
              onPressed: () => ref.read(fontScaleProvider.notifier).toggleScale(),
            ),
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
              onChanged: (String? value) {
                if (value != null) ref.read(localeProvider.notifier).changeLocale(value);
              },
              style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textPrimary),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: TextStyle(fontSize: 16 * fontScale, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: i18n.t('tab_helper')),
            Tab(text: i18n.t('tab_admin')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHelperForm(fontScale, i18n),
          _buildAdminForm(fontScale, i18n),
        ],
      ),
    );
  }

  Widget _buildHelperForm(double fontScale, I18nHelper i18n) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24 * fontScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 24 * fontScale),
          Center(
            child: Container(
              width: 100 * fontScale,
              height: 100 * fontScale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50 * fontScale),
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/care_img1.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          SizedBox(height: 24 * fontScale),
          Text(
            i18n.t('forgot_helper_intro'),
            style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
          ),
          SizedBox(height: 20 * fontScale),
          TextFormField(
            controller: _nameController,
            decoration: _decoration(fontScale, i18n.t('name'), i18n.t('name_hint')),
            style: TextStyle(fontSize: 16 * fontScale),
          ),
          SizedBox(height: 16 * fontScale),
          TextFormField(
            controller: _loginIdController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              PhoneMaskInputFormatter(),
            ],
            decoration: _decoration(fontScale, i18n.t('forgot_phone_label'), i18n.t('id_hint')),
            style: TextStyle(fontSize: 16 * fontScale),
          ),
          SizedBox(height: 16 * fontScale),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _rrnPrefixController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _decoration(fontScale, i18n.t('forgot_resident_prefix'), '900101'),
                  style: TextStyle(fontSize: 16 * fontScale),
                ),
              ),
              SizedBox(width: 12 * fontScale),
              Expanded(
                child: TextFormField(
                  controller: _rrnSuffixFirstController,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _decoration(fontScale, i18n.t('forgot_resident_suffix'), '1'),
                  style: TextStyle(fontSize: 16 * fontScale),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * fontScale),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration(fontScale, i18n.t('forgot_email_label'), i18n.t('forgot_email_hint')),
            style: TextStyle(fontSize: 16 * fontScale),
          ),
          SizedBox(height: 32 * fontScale),
          _buildSubmitButton(fontScale, i18n.t('forgot_submit'), _submitting, _submitHelper),
        ],
      ),
    );
  }

  Widget _buildAdminForm(double fontScale, I18nHelper i18n) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24 * fontScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 24 * fontScale),
          Center(
            child: Container(
              width: 100 * fontScale,
              height: 100 * fontScale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50 * fontScale),
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/care_img1.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          SizedBox(height: 24 * fontScale),
          Text(
            i18n.t('forgot_admin_intro'),
            style: TextStyle(fontSize: 14 * fontScale, color: AppColors.textSecondary),
          ),
          SizedBox(height: 20 * fontScale),
          TextFormField(
            controller: _nameController,
            decoration: _decoration(fontScale, i18n.t('name'), i18n.t('name_hint')),
            style: TextStyle(fontSize: 16 * fontScale),
          ),
          SizedBox(height: 16 * fontScale),
          DropdownButtonFormField<int>(
            initialValue: _selectedCenterId,
            decoration: _decoration(fontScale, i18n.t('center'), i18n.t('center_hint')),
            items: _centers.map((c) {
              final id = c['id'] as int?;
              final name = c['name'] as String? ?? '';
              return DropdownMenuItem(value: id, child: Text(name));
            }).toList(),
            onChanged: _loadingCenters ? null : (v) => setState(() => _selectedCenterId = v),
            style: TextStyle(fontSize: 16 * fontScale, color: AppColors.textPrimary),
          ),
          SizedBox(height: 16 * fontScale),
          TextFormField(
            controller: _loginIdController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              PhoneMaskInputFormatter(),
            ],
            decoration: _decoration(fontScale, i18n.t('forgot_phone_label'), i18n.t('id_hint')),
            style: TextStyle(fontSize: 16 * fontScale),
          ),
          SizedBox(height: 16 * fontScale),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration(fontScale, i18n.t('forgot_email_label'), i18n.t('forgot_email_hint')),
            style: TextStyle(fontSize: 16 * fontScale),
          ),
          SizedBox(height: 32 * fontScale),
          _buildSubmitButton(fontScale, i18n.t('forgot_submit'), _submitting, _submitAdmin),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(double fontScale, String label, bool submitting, VoidCallback onPressed) {
    return SizedBox(
      height: 56 * fontScale,
      child: ElevatedButton(
        onPressed: submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * fontScale)),
          elevation: 0,
        ),
        child: submitting
            ? SizedBox(
                height: 20 * fontScale,
                width: 20 * fontScale,
                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: TextStyle(fontSize: 16 * fontScale, fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _decoration(double fontScale, String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 * fontScale),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 * fontScale),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: TextStyle(fontSize: 14 * fontScale),
      hintStyle: TextStyle(fontSize: 14 * fontScale),
      contentPadding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 16 * fontScale),
    );
  }
}
