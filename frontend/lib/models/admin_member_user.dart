/// GET /api/admin/users 응답 항목. 보호사(회원) 목록.
class AdminMemberUser {
  final int userId;
  final String name;
  final String email;
  /// 원본 휴대폰 번호 (API의 login_id). 표시 시 이 값을 우선 사용.
  final String loginId;
  final String loginIdMasked;
  final String status;
  final bool hasDuplicateMatching;
  /// 보호사 기본 시급(원). 매칭 등록 시 자동 로드.
  final int defaultHourlyWage;

  AdminMemberUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.loginId,
    required this.loginIdMasked,
    required this.status,
    required this.hasDuplicateMatching,
    this.defaultHourlyWage = 16150,
  });

  factory AdminMemberUser.fromJson(Map<String, dynamic> json) {
    return AdminMemberUser(
      userId: json['user_id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      loginId: (json['login_id'] ?? json['phone']) as String? ?? '',
      loginIdMasked: json['login_id_masked'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      hasDuplicateMatching: json['has_duplicate_matching'] == true,
      defaultHourlyWage: (json['default_hourly_wage'] is int)
          ? json['default_hourly_wage'] as int
          : (int.tryParse(json['default_hourly_wage']?.toString() ?? '') ?? 16150),
    );
  }

  bool get isSuspended => status == 'suspended';
}
