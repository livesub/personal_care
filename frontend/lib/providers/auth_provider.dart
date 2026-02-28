import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/auth_router_refresh.dart';
import '../models/login_response.dart';
import '../services/api_service.dart';

/// 인증 상태 (리다이렉트 대기용)
enum AuthStatus {
  initializing,
  unauthenticated,
  authenticated,
}

/// 로그인 후 세션 상태.
/// [mustChangePassword] true면 초기 비번: 관리자는 토큰 미저장 → F5 시 로그아웃. 보호사는 항상 저장.
class AuthState {
  final LoginUser? user;
  final bool mustChangePassword;
  final AuthStatus status;
  const AuthState({
    this.user,
    this.mustChangePassword = false,
    this.status = AuthStatus.initializing,
  });
  bool get isLoggedIn => user != null;
  String? get endAt => user?.endAt;
  bool get isInitializing => status == AuthStatus.initializing;
  bool get isInitialPasswordState => mustChangePassword;
  /// 관리자 그룹(admin/staff): adminId 있으면 관리자
  bool get isAdminGroup => user?.adminId != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api) : super(const AuthState(status: AuthStatus.initializing));

  final ApiService _api;

  void setSession(LoginResponse response) {
    state = AuthState(
      user: response.user,
      mustChangePassword: response.needPasswordChange,
      status: AuthStatus.authenticated,
    );
    notifyAuthChange();
  }

  void setSessionFromUser(LoginUser? user) {
    state = AuthState(
      user: user,
      mustChangePassword: false,
      status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
    notifyAuthChange();
  }

  /// 세션 복원용. GET /user 응답에서 need_password_change 반영.
  void setSessionFromUserWithPasswordChange(LoginUser? user, bool mustChangePassword) {
    state = AuthState(
      user: user,
      mustChangePassword: mustChangePassword,
      status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
    notifyAuthChange();
  }

  void markPasswordChangeComplete() {
    state = AuthState(
      user: state.user,
      mustChangePassword: false,
      status: AuthStatus.authenticated,
    );
    notifyAuthChange();
  }

  /// 비밀번호 변경 성공 시 역할에 따라 토큰 저장.
  /// - 관리자(admin/staff): 로그인 시 토큰을 저장하지 않았으므로, 이때 Storage에 저장(메모리 → write).
  /// - 보호사(user): 로그인 시 이미 저장됨. 서버가 새 토큰을 주면 [newTokenFromServer]로 덮어쓰기.
  Future<void> onPasswordChangeSuccess(String? newTokenFromServer) async {
    if (state.user == null) return;
    final isAdmin = state.user!.adminId != null;
    if (isAdmin) {
      await _api.persistCurrentToken();
    } else {
      if (newTokenFromServer != null && newTokenFromServer.isNotEmpty) {
        await _api.saveToken(newTokenFromServer);
      }
    }
  }

  void clearSession() {
    state = const AuthState(status: AuthStatus.unauthenticated);
    notifyAuthChange();
  }

  /// 스플래시에서 토큰 확인 완료 후 호출. 유저 없으면 unauthenticated로 전환
  void finishInitialization() {
    if (state.status == AuthStatus.initializing) {
      state = AuthState(
        user: null,
        mustChangePassword: false,
        status: AuthStatus.unauthenticated,
      );
      notifyAuthChange();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    clearSession();
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});
