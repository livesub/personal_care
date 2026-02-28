import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../models/login_response.dart';
import '../providers/auth_provider.dart';
import '../providers/font_scale_provider.dart';
import '../providers/login_form_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../utils/i18n_helper.dart';
import '../utils/input_formatters.dart';
import '../widgets/project_guide_dialog.dart';
import 'login_dialogs.dart';

/// 로그인 화면 (최종본).
/// 역할별 로그인(보호사/관리자), 접근성(글자 크기·언어), Material 3 Green 톤.
class NewLoginScreen extends ConsumerStatefulWidget {
  /// 'helper' = 보호사, 'admin' = 관리자
  final String role;
  
  const NewLoginScreen({super.key, required this.role});

  @override
  ConsumerState<NewLoginScreen> createState() => _NewLoginScreenState();
}

class _NewLoginScreenState extends ConsumerState<NewLoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _lastValidPassword = '';

  /// 0 = 보호사, 1 = 관리자 (탭 인덱스)
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  /// 관리자 탭에서만 사용. ref.watch(selectedCenterIdProvider) 제거로 로그인 화면에서 Provider 구독 없음.
  int? _adminSelectedCenterId;

  @override
  void initState() {
    super.initState();
    // 로그인 화면 진입 가드: 찌꺼기 데이터 있으면 강제 초기화 (죽은 객체 참조 방지)
    if (ref.read(authProvider).user != null) {
      ref.read(authProvider.notifier).clearSession();
      ref.invalidate(authProvider);
      ref.invalidate(selectedCenterIdProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(apiServiceProvider).removeToken();
      });
    }
    _selectedTabIndex = widget.role == 'admin' ? 1 : 0;
    _passwordController.addListener(_onPasswordChanged);
    _idController.addListener(() => setState(() {}));
    final centerNotifier = ref.read(selectedCenterIdProvider.notifier);
    if (widget.role == 'admin') {
      _adminSelectedCenterId = null;
      centerNotifier.select(null);
    } else {
      centerNotifier.loadFromPrefs();
    }
    if (widget.role == 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedTabIndex != 1) {
          setState(() => _selectedTabIndex = 1);
        }
      });
    }
  }

  @override
  void didUpdateWidget(NewLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      setState(() {
        _selectedTabIndex = widget.role == 'admin' ? 1 : 0;
        if (widget.role == 'admin') {
          _adminSelectedCenterId = null;
        }
      });
      if (widget.role == 'admin') {
        ref.read(selectedCenterIdProvider.notifier).select(null);
      } else {
        ref.read(selectedCenterIdProvider.notifier).loadFromPrefs();
      }
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() => setState(() {});

  void _showLoginFailed(BuildContext context, I18nHelper i18n) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(i18n.t('login_failed'))),
    );
  }

  /// [이중 보안] 저장된 토큰으로 GET /user 호출.
  /// POST 로그인 200만 믿지 않고, 서버에 토큰 유효성 검증 후 세션 설정.
  /// statusCode 정확히 200일 때만 LoginUser 반환, 그 외 null.
  /// [centerId] 보호사일 때 X-Center-Id 헤더로 전달 (선택).
  Future<LoginUser?> _verifyTokenWithServer(ApiService api, {int? centerId}) async {
    try {
      final res = await api.getUser(centerId: centerId);
      if (res.statusCode != 200) return null;
      final data = res.data;
      if (data == null || data is! Map<String, dynamic>) return null;
      final user = LoginUser.fromJson(data);
      if (user.userId == null && user.adminId == null) return null;
      return user;
    } catch (_) {
      return null;
    }
  }

  /// 서버 응답이 실제 로그인 성공인지 검사 (토큰 + 사용자 식별자 필수)
  bool _isValidLoginResponse(LoginResponse response, {required bool isHelper}) {
    final user = response.user;
    if (user == null) return false;
    if (isHelper) {
      if (response.needPasswordChange) {
        return response.temporaryToken != null && response.temporaryToken!.isNotEmpty;
      }
      return response.accessToken.trim().isNotEmpty && user.userId != null;
    }
    return response.accessToken.trim().isNotEmpty && user.adminId != null;
  }

  /// 비밀번호 조건 한 줄: 충족 시 초록 ✔, 미충족 시 빨강 ✖
  Widget _buildPasswordRuleRow(double fontScale, String label, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.cancel,
          size: 18 * fontScale,
          color: met ? AppColors.primary : AppColors.error,
        ),
        SizedBox(width: 6 * fontScale),
        Text(
          label,
          style: TextStyle(
            fontSize: 13 * fontScale,
            color: met ? AppColors.primary : AppColors.error,
          ),
        ),
      ],
    );
  }

  /// 로그인 처리 (이중 보안).
  /// 1) 시도 시 기존 세션·토큰 초기화
  /// 2) POST 로그인 — statusCode 정확히 200일 때만 성공으로 간주 (401/422 시 예외)
  /// 3) 토큰 저장 후 GET /user 로 서버 검증 — 실패 시 토큰 삭제, 홈 이동 없음
  /// 4) 검증 통과 시에만 setSessionFromUser → context.go('/home')
  /// 보호사: 아이디 = 전화번호(10~11자리), 관리자: 아이디 = 문자열 — 검증·메시지 분리
  Future<void> _handleLogin() async {
    final api = ref.read(apiServiceProvider);
    final auth = ref.read(authProvider.notifier);
    final i18n = I18nHelper.of(context);

    // 현재 선택된 탭 기준으로 검사 (관리자 탭 = Admin, 보호사 탭 = Helper)
    final isAdminTab = _selectedTabIndex == 1;

    // ——— 보호사(Helper) 탭: 아이디 = 휴대폰 번호(10~11자리), 정규식 필수 ———
    if (!isAdminTab) {
      final digits = _idController.text.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.t('validation_helper_id_required'))),
          );
        }
        return;
      }
      if (digits.length < 10 || digits.length > 11) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.t('validation_helper_id_phone'))),
          );
        }
        return;
      }
      if (_passwordController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.t('validation_helper_password_required'))),
          );
        }
        return;
      }
      // 보호사 검증 끝
    } else {
      // ——— 관리자(Admin) 탭: 아이디 = 일반 문자열. 휴대폰/정규식 절대 금지. isNotEmpty만 ———
      final centerId = ref.read(selectedCenterIdProvider);
      if (centerId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.t('enter_center'))),
          );
        }
        return;
      }
      if (_idController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.t('validation_admin_id_required'))),
          );
        }
        return;
      }
      if (_passwordController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(i18n.t('validation_admin_password_required'))),
          );
        }
        return;
      }
      // 관리자 검증 끝 (정규식 없음)
    }

    setState(() => _isLoading = true);
    auth.clearSession();
    await api.removeToken();

    try {
      LoginResponse? loginResponse;
      if (!isAdminTab) {
        final loginId = _idController.text.replaceAll(RegExp(r'\D'), '');
        final data = {
          'login_id': loginId,
          'password': _passwordController.text,
          'device_name': 'flutter-app',
        };
        final res = await api.postLogin('/helper/login', data: data);
        if (!mounted) return;
        if (res.statusCode != 200) {
          _showLoginFailed(context, i18n);
          return;
        }
        final responseData = res.data;
        if (responseData == null || responseData is! Map<String, dynamic>) {
          _showLoginFailed(context, i18n);
          return;
        }
        loginResponse = LoginResponse.fromJson(responseData);
        if (!_isValidLoginResponse(loginResponse, isHelper: true)) {
          _showLoginFailed(context, i18n);
          return;
        }
        // CASE B: 보호사는 must_change_password 여부와 관계없이 로그인 성공 시 항상 토큰 영구 저장.
        final helperToken = loginResponse.temporaryToken ?? (loginResponse.accessToken.isNotEmpty ? loginResponse.accessToken : null);
        if (helperToken != null && helperToken.isNotEmpty) {
          await api.saveToken(helperToken);
        }
        // 최초 로그인: 본인 확인 + 비밀번호 변경 팝업 후 메인으로 이동.
        if (loginResponse.needPasswordChange && loginResponse.user != null && loginResponse.temporaryToken != null) {
          if (!mounted) return;
          final dialogResult = await LoginDialogs.showFirstLoginIdentityAndPasswordChange(
            context,
            loginResponse.user!,
            loginResponse.temporaryToken!,
            ref.read(fontScaleProvider),
            i18n,
            api,
          );
          if (!mounted) return;
          if (dialogResult == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(i18n.t('password_change_success'))),
            );
            if (!context.mounted) return;
            auth.setSessionFromUser(loginResponse.user!);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              context.go('/home');
            });
          } else if (dialogResult is Map<String, dynamic>) {
            final data = dialogResult;
            // 다이얼로그 제거가 완료된 다음 프레임에 이동해, 중간 오류 화면 깜빡임 방지
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              context.goNamed('account-locked', extra: data);
            });
          }
          return;
        }

        // 보호사 정상 로그인(비밀번호 변경 완료): 세션 즉시 갱신 후 홈으로 이동. (GET /user 검증 생략하여 가드에 걸리지 않게 함)
        if (loginResponse.user != null) {
          auth.setSessionFromUser(loginResponse.user!);
          if (loginResponse.user!.centerId != null) {
            ref.read(selectedCenterIdProvider.notifier).select(loginResponse.user!.centerId);
          }
          if (!mounted) return;
          await LoginDialogs.showWelcomeCard(
            context,
            loginResponse.user!.name ?? '',
            ref.read(fontScaleProvider),
          );
          if (!mounted) return;
          context.go('/home');
          return;
        }
      } else {
        final centerId = ref.read(selectedCenterIdProvider);
        if (centerId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(i18n.t('enter_center'))),
            );
          }
          return;
        }
        final adminData = {
          'center_id': centerId,
          'login_id': _idController.text.trim().toLowerCase(),
          'password': _passwordController.text,
          'device_name': 'flutter-app',
        };
        final res = await api.postLogin('/admin/login', data: adminData);
        if (!mounted) return;
        if (res.statusCode != 200) {
          _showLoginFailed(context, i18n);
          return;
        }
        final data = res.data;
        if (data == null || data is! Map<String, dynamic>) {
          _showLoginFailed(context, i18n);
          return;
        }
        try {
          loginResponse = LoginResponse.fromJson(data);
        } catch (e, _) {
          _showLoginFailed(context, i18n);
          return;
        }
        if (!_isValidLoginResponse(loginResponse, isHelper: false)) {
          _showLoginFailed(context, i18n);
          return;
        }
        // Case A: 관리자 초기 비번 → 토큰도 저장(새로고침 시 세션 유지), /change-password로 이동
        if (loginResponse.needPasswordChange && loginResponse.user != null) {
          final token = loginResponse.temporaryToken ?? (loginResponse.accessToken.isNotEmpty ? loginResponse.accessToken : null);
          if (token != null && token.isNotEmpty) {
            if (!mounted) return;
            await api.saveToken(token);
            auth.setSession(loginResponse);
            if (!mounted) return;
            context.go('/change-password');
            return;
          }
        }
      }

      if (!mounted) return;
      await api.saveToken(loginResponse.accessToken);

      if (!mounted) return;
      if (loginResponse.isTempAccount == true) {
        auth.setSessionFromUser(loginResponse.user);
        context.go('/admin-init');
        return;
      }

      final centerId = loginResponse.user?.centerId ?? ref.read(selectedCenterIdProvider);
      final user = await _verifyTokenWithServer(api, centerId: centerId);
      if (!mounted) return;
      if (user == null) {
        await api.removeToken();
        if (!mounted) return;
        _showLoginFailed(context, i18n);
        return;
      }

      auth.setSessionFromUser(user);
      if (user.centerId != null && !isAdminTab) {
        ref.read(selectedCenterIdProvider.notifier).select(user.centerId);
      }
      if (!ref.read(authProvider).isLoggedIn) {
        _showLoginFailed(context, i18n);
        return;
      }
      if (!mounted) return;
      await LoginDialogs.showWelcomeCard(
        context,
        ref.read(authProvider).user?.name ?? '',
        ref.read(fontScaleProvider),
      );
      if (!mounted) return;
      if (isAdminTab) {
        context.go('/admin/dashboard');
      } else {
        context.go('/home');
      }
    } on DioException catch (e) {
      String? msg;
      if (e.response?.data is Map) {
        final d = e.response!.data as Map<String, dynamic>;
        msg = d['message'] as String?;
        if (msg == null && d['errors'] is Map) {
          final errs = d['errors'] as Map;
          final first = errs.values.isNotEmpty ? errs.values.first : null;
          msg = first is List && first.isNotEmpty ? first.first.toString() : first?.toString();
        }
      }
      msg ??= e.message ?? i18n.t('login_failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.t('login_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(fontScaleProvider);
    final currentLocale = ref.watch(localeProvider);
    final i18n = I18nHelper.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      
      // 상단 앱바
      appBar: AppBar(
        // 앱바 배경색: 흰색 (디자인 변경 시 여기 수정)
        backgroundColor: Colors.white,
        elevation: 0,
        
        // 로고: 휠체어+보호사 크롭 이미지
        title: Row(
          children: [
            // 로고 이미지 (디자인 변경 시 여기 수정)
            Container(
              width: 40 * fontScale,
              height: 40 * fontScale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20 * fontScale),
                color: AppColors.background,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/care_img1.png', // 앱바 로고 (작은 공간) (디자인 변경 시 여기 수정)
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
            SizedBox(width: 12 * fontScale), // 간격 (디자인 변경 시 여기 수정)
            
            // 앱 이름 텍스트
            Text(
              i18n.t('app_name'),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20 * fontScale, // 글자 크기 적용 (디자인 변경 시 여기 수정)
              ),
            ),
          ],
        ),
        
        // 우측 버튼들 (접근성 기능)
        actions: [
          // 글자 크기 조절 버튼
          Tooltip(
            message: i18n.t('font_size'),
            child: IconButton(
              // 아이콘: 텍스트 크기 (디자인 변경 시 여기 수정)
              icon: Icon(
                Icons.text_fields,
                color: AppColors.textSecondary,
                size: 24 * fontScale,
              ),
              onPressed: () {
                // 글자 크기 변경: 1.0 -> 1.2 -> 1.5 -> 1.0 순환
                ref.read(fontScaleProvider.notifier).toggleScale();
              },
            ),
          ),
          
          // 언어 변경 드롭다운
          Padding(
            padding: EdgeInsets.only(right: 8 * fontScale), // 우측 여백 (디자인 변경 시 여기 수정)
            child: DropdownButton<String>(
              value: currentLocale.languageCode,
              icon: Icon(
                Icons.language,
                color: AppColors.textSecondary,
                size: 24 * fontScale,
              ),
              underline: const SizedBox(), // 밑줄 제거
              items: [
                DropdownMenuItem(value: 'ko', child: Text(i18n.t('language_ko'))),
                DropdownMenuItem(value: 'en', child: Text(i18n.t('language_en'))),
                DropdownMenuItem(value: 'vi', child: Text(i18n.t('language_vi'))),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  // 언어 변경
                  ref.read(localeProvider.notifier).changeLocale(value);
                }
              },
              // 드롭다운 텍스트 크기 조절
              style: TextStyle(
                fontSize: 14 * fontScale,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      
      // 접근성 바 아래: [보호사] / [관리자] 탭 + 폼
      body: Column(
        children: [
          _buildTabBar(fontScale, i18n),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildHelperLoginForm(fontScale, i18n)
                : _buildAdminLoginForm(fontScale, i18n),
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

  /// [보호사] / [관리자] 탭 (그린 톤)
  Widget _buildTabBar(double fontScale, I18nHelper i18n) {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: _selectedTabIndex == 0 ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = 0),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14 * fontScale),
                  child: Text(
                    i18n.t('tab_helper'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16 * fontScale,
                      fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                      color: _selectedTabIndex == 0 ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: _selectedTabIndex == 1 ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = 1),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14 * fontScale),
                  child: Text(
                    i18n.t('tab_admin'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16 * fontScale,
                      fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                      color: _selectedTabIndex == 1 ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 보호사 로그인 폼
  Widget _buildHelperLoginForm(double fontScale, I18nHelper i18n) {
    return SingleChildScrollView(
      // 패딩: 전체 여백 (디자인 변경 시 여기 수정)
      padding: EdgeInsets.all(24 * fontScale),
      child: Column(
        children: [
          SizedBox(height: 40 * fontScale), // 상단 여백 (디자인 변경 시 여기 수정)
          
          // 로고 이미지: 휠체어+보호사 크롭 (디자인 변경 시 여기 수정)
          Container(
            width: 100 * fontScale,
            height: 100 * fontScale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50 * fontScale),
              color: AppColors.background,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/care_img1.png', // 보호사 로그인 폼 메인 이미지 (중간 크기) (디자인 변경 시 여기 수정)
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          
          SizedBox(height: 40 * fontScale), // 간격 (디자인 변경 시 여기 수정)
          
          // 아이디 입력 (휴대폰 번호): 숫자만 + 하이픈 자동 포맷 010-1234-5678
          TextFormField(
            controller: _idController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              PhoneMaskInputFormatter(),
            ],
            style: TextStyle(fontSize: 16 * fontScale),
            decoration: InputDecoration(
              labelText: i18n.t('id'),
              hintText: i18n.t('id_hint'),
              filled: true,
              fillColor: Colors.grey.shade50,
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16 * fontScale,
                vertical: 16 * fontScale,
              ),
            ),
          ),
          
          SizedBox(height: 16 * fontScale),
          
          // 비밀번호 입력: 소문자 강제 + 허용 문자만 (미허용 시 스낵바)
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('snackbar_invalid_char'))),
                    );
                  }
                });
              }
            },
            style: TextStyle(fontSize: 16 * fontScale),
            decoration: InputDecoration(
              labelText: i18n.t('password'),
              hintText: i18n.t('password_hint'),
              filled: true,
              fillColor: Colors.grey.shade50,
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16 * fontScale,
                vertical: 16 * fontScale,
              ),
            ),
          ),
          // 비밀번호 실시간 검사: 10자 이상, 영문+숫자+특수문자 (초록 ✔ / 빨강 ✖)
          Padding(
            padding: EdgeInsets.only(top: 8 * fontScale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPasswordRuleRow(
                  fontScale,
                  i18n.t('password_rule_length'),
                  passwordMeetsLength(_passwordController.text),
                ),
                SizedBox(height: 4 * fontScale),
                _buildPasswordRuleRow(
                  fontScale,
                  i18n.t('password_rule_complexity'),
                  passwordMeetsComplexity(_passwordController.text),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 32 * fontScale),
          
          // 로그인 버튼
          SizedBox(
            width: double.infinity, // 전체 너비
            height: 56 * fontScale, // 버튼 높이 (디자인 변경 시 여기 수정)
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                // 버튼 배경색: Green 톤 (디자인 변경 시 여기 수정)
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                // 버튼 모서리: 둥글게 (디자인 변경 시 여기 수정)
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * fontScale),
                ),
                elevation: 0, // 그림자 제거 (디자인 변경 시 여기 수정)
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20 * fontScale,
                      width: 20 * fontScale,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      i18n.t('login'),
                      style: TextStyle(
                        fontSize: 18 * fontScale, // 버튼 텍스트 크기 (디자인 변경 시 여기 수정)
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 16 * fontScale),
          // 비밀번호 찾기 (기획서 11~12p)
          TextButton(
            onPressed: () => context.push('/forgot-password'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: TextStyle(fontSize: 14 * fontScale),
            ),
            child: Text(i18n.t('forgot_title')),
          ),
        ],
      ),
    );
  }

  /// 관리자 로그인 폼 (GET /api/centers 드롭다운). SelectedCenterNotifier watch 없음 — 로컬 상태만 사용.
  Widget _buildAdminLoginForm(double fontScale, I18nHelper i18n) {
    final centersAsync = ref.watch(centersProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(24 * fontScale),
      child: Column(
        children: [
          SizedBox(height: 40 * fontScale),
          Container(
            width: 100 * fontScale,
            height: 100 * fontScale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50 * fontScale),
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
          SizedBox(height: 40 * fontScale),
          // 센터 선택: 로컬 상태 _adminSelectedCenterId 사용 (선택 시 notifier에도 반영해 _handleLogin에서 read)
          centersAsync.when(
            data: (centers) {
              final validId = _adminSelectedCenterId != null && centers.any((c) => c.id == _adminSelectedCenterId);
              return DropdownButtonFormField<int?>(
                value: validId ? _adminSelectedCenterId : null,
                decoration: InputDecoration(
                  labelText: i18n.t('center'),
                  hintText: i18n.t('center_hint'),
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16 * fontScale,
                    vertical: 16 * fontScale,
                  ),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(i18n.t('center_hint')),
                  ),
                  ...centers.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _adminSelectedCenterId = value);
                  ref.read(selectedCenterIdProvider.notifier).select(value);
                },
                style: TextStyle(
                  fontSize: 16 * fontScale,
                  color: AppColors.textPrimary,
                ),
              );
            },
            loading: () => InputDecorator(
              decoration: InputDecoration(
                labelText: i18n.t('center'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12 * fontScale)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20 * fontScale,
                    height: 20 * fontScale,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12 * fontScale),
                  Text(i18n.t('loading'), style: TextStyle(fontSize: 14 * fontScale)),
                ],
              ),
            ),
            error: (Object error, StackTrace stackTrace) => InputDecorator(
              decoration: InputDecoration(
                labelText: i18n.t('center'),
                errorText: i18n.t('centers_load_error'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12 * fontScale)),
              ),
              child: Text(i18n.t('center_hint')),
            ),
          ),
          
          SizedBox(height: 16 * fontScale),
          
          // 아이디 입력: 관리자는 일반 문자열만. 휴대폰/숫자 키패드 금지.
          TextFormField(
            controller: _idController,
            keyboardType: TextInputType.text,
            inputFormatters: [LowercaseTextInputFormatter()],
            style: TextStyle(fontSize: 16 * fontScale),
            decoration: InputDecoration(
              labelText: i18n.t('id'),
              hintText: i18n.t('id_hint_admin'),
              filled: true,
              fillColor: Colors.grey.shade50,
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16 * fontScale,
                vertical: 16 * fontScale,
              ),
            ),
          ),
          
          SizedBox(height: 16 * fontScale),
          
          // 비밀번호 입력: 소문자 강제 + 허용 문자만 (미허용 시 스낵바)
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(i18n.t('snackbar_invalid_char'))),
                    );
                  }
                });
              }
            },
            style: TextStyle(fontSize: 16 * fontScale),
            decoration: InputDecoration(
              labelText: i18n.t('password'),
              hintText: i18n.t('password_hint'),
              filled: true,
              fillColor: Colors.grey.shade50,
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16 * fontScale,
                vertical: 16 * fontScale,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8 * fontScale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPasswordRuleRow(
                  fontScale,
                  i18n.t('password_rule_length'),
                  passwordMeetsLength(_passwordController.text),
                ),
                SizedBox(height: 4 * fontScale),
                _buildPasswordRuleRow(
                  fontScale,
                  i18n.t('password_rule_complexity'),
                  passwordMeetsComplexity(_passwordController.text),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 32 * fontScale),
          // 로그인 버튼: 센터·아이디·비밀번호 모두 입력 시에만 활성화
          Builder(
            builder: (_) {
              final canLogin = _adminSelectedCenterId != null &&
                  _idController.text.trim().isNotEmpty &&
                  _passwordController.text.isNotEmpty &&
                  !_isLoading;
              return SizedBox(
                width: double.infinity,
                height: 56 * fontScale,
                child: ElevatedButton(
                  onPressed: canLogin ? _handleLogin : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * fontScale),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20 * fontScale,
                      width: 20 * fontScale,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      i18n.t('login'),
                      style: TextStyle(
                        fontSize: 18 * fontScale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
