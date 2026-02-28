/// admin/금칙어 계정 가드. 백엔드 TEMP_LOGIN_ID_BLACKLIST와 동일.
/// HomeScreen·라우터 등에서 admin 또는 금칙어 로그인 시 로그인으로 쫓아내는 데 사용.

const List<String> tempAdminLoginIdBlacklist = [
  'admin',
  'manager',
  'root',
  'staff',
  'system',
];

/// 현재 로그인 아이디가 admin 또는 금칙어이면 true. 이 계정은 홈 진입 불가·세션 폭파 대상.
bool isTempAdminLoginId(String? loginId) {
  if (loginId == null || loginId.isEmpty) return false;
  return tempAdminLoginIdBlacklist.contains(loginId.trim().toLowerCase());
}
