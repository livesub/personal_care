/// 로그인 API 응답 (보호사/관리자 공통 필드)
/// 최초 로그인 시 need_password_change=true면 access_token 없음.
class LoginResponse {
  final String accessToken;
  final String tokenType;
  final bool? isFirstLogin;
  final LoginUser? user;
  final String? message;
  /// 최초 로그인 시 true. 이때 access_token 없고 temporary_token만 있음.
  final bool needPasswordChange;
  final String? temporaryToken;
  /// 관리자 임시 계정(admin) 전환 필요 시 true → /admin-init 강제 이동.
  final bool isTempAccount;

  LoginResponse({
    required this.accessToken,
    this.tokenType = 'Bearer',
    this.isFirstLogin,
    this.user,
    this.message,
    this.needPasswordChange = false,
    this.temporaryToken,
    this.isTempAccount = false,
  });

  /// 서버가 't'/'f', 'true'/'false', 1/0, bool 등으로 내려줄 수 있음.
  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      final lower = v.toLowerCase();
      if (lower == 't' || lower == 'true' || lower == '1') return true;
      if (lower == 'f' || lower == 'false' || lower == '0') return false;
    }
    return false;
  }

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final need = _parseBool(json['need_password_change']) ||
        _parseBool(json['must_change_password']) ||
        _parseBool(json['is_initial_login']);
    return LoginResponse(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      isFirstLogin: _parseBool(json['is_first_login']),
      user: json['user'] != null
          ? LoginUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
      needPasswordChange: need,
      temporaryToken: json['temporary_token'] as String?,
      isTempAccount: _parseBool(json['is_temp_account']),
    );
  }
}

class LoginUser {
  final int? userId;
  final int? adminId;
  final String? name;
  final String? email;
  final String? phoneFormatted;
  final int? centerId;
  final String? centerName;
  /// 근무 종료 시각 (ISO8601). 이 시각 20분 전까지 일지/종료 버튼 비활성화.
  final String? endAt;
  /// 본인 확인 팝업용. 최초 로그인 시만 서버에서 내려줌 (첫 1자리+******).
  final String? residentMasked;
  /// 관리자 로그인 시 서버에서 내려주는 로그인 아이디. admin/금칙어 여부 체크용.
  final String? loginId;
  /// 관리자 역할. 'admin' | 'staff'. 없으면 admin으로 간주.
  final String? role;

  LoginUser({
    this.userId,
    this.adminId,
    this.name,
    this.email,
    this.phoneFormatted,
    this.centerId,
    this.centerName,
    this.endAt,
    this.residentMasked,
    this.loginId,
    this.role,
  });

  factory LoginUser.fromJson(Map<String, dynamic> json) {
    return LoginUser(
      userId: json['user_id'] as int?,
      adminId: json['admin_id'] as int?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phoneFormatted: json['phone_formatted'] as String?,
      centerId: json['center_id'] as int?,
      centerName: json['center_name'] as String?,
      endAt: json['end_at'] as String?,
      residentMasked: json['resident_masked'] as String?,
      loginId: json['login_id'] as String?,
      role: json['role'] as String?,
    );
  }

  /// 표시용 역할 라벨: staff면 Staff, 아니면 관리자.
  bool get isStaff => role == 'staff';
}
