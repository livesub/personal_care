import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_router_refresh.dart';
import '../providers/auth_provider.dart';
import '../utils/i18n_helper.dart';
import '../screens/account_locked_screen.dart';
import '../presentation/admin_init/admin_init_screen.dart';
import '../screens/change_password_screen.dart';
import '../layout/admin_layout.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin/client_management_screen.dart';
import '../screens/admin/helper_management_screen.dart';
import '../screens/admin/matching_management_screen.dart';
import '../screens/admin/operations_management_screen.dart';
import '../screens/admin/real_time_monitoring_screen.dart';
import '../screens/admin/settlement_screen.dart';
import '../screens/admin_placeholder_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/home_screen.dart';
import '../screens/new_login_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/splash_screen.dart';

/// GoRouter 설정
/// .cursorrules: 앱과 웹의 URL 이동 관리
/// Guard: 비로그인 시 보호 경로 접근 → 로그인 유도, 로그인 상태에서 로그인/역할선택 접근 → 홈으로 리다이렉트
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: authRouterRefresh,
    redirect: (BuildContext context, GoRouterState state) {
      try {
        final container = ProviderScope.containerOf(context);
        final auth = container.read(authProvider);
        final fullPath = state.uri.path;
        final isInitialPasswordState = auth.isInitialPasswordState;
        final isAdminGroup = auth.isAdminGroup;

        // [초기화 중] 토큰/센터 복원을 위해 스플래시(/) 경유 강제. 새로고침 후 일정 사라짐 방지.
        if (auth.isInitializing && (fullPath == '/home' || fullPath.startsWith('/home?'))) {
          return '/';
        }
        // [최우선] /admin 하위 경로: 인증 확인 완료 전에는 스플래시(/)로 보내 세션 복원 후 가드 적용.
        if (fullPath.startsWith('/admin')) {
          if (auth.isInitializing) return '/';
          if (auth.status == AuthStatus.unauthenticated || !auth.isLoggedIn) return '/role-selection';
          if (isAdminGroup && isInitialPasswordState) return '/admin-init';
          if (!isAdminGroup) {
            if (isInitialPasswordState) return '/role-selection';
            return '/home';
          }
          return null;
        }

        if (auth.isInitializing) return null;

        // [보호사 홈 Access Guard] /home: 보호사 + 비밀번호 변경 완료만 허용
        if (fullPath == '/home' || fullPath.startsWith('/home?')) {
          if (!auth.isLoggedIn || auth.status == AuthStatus.unauthenticated) return '/role-selection';
          if (isAdminGroup) return '/role-selection';
          if (isInitialPasswordState) return '/role-selection';
          return null;
        }

      // ——— 시나리오 1. [비로그인] 상태 (Guest) ———
        if (auth.status == AuthStatus.unauthenticated) {
          if (fullPath == '/') return '/role-selection';
          if (fullPath == '/role-selection' || fullPath == '/login') return null;
          return '/role-selection';
        }

        // ——— 시나리오 2. [초기 비밀번호] 감옥: 관리자(admin/staff) must_change_password면 무조건 /admin-init ———
        if (auth.status == AuthStatus.authenticated && isAdminGroup && isInitialPasswordState) {
          if (fullPath != '/admin-init') return '/admin-init';
          return null;
        }

        // ——— 시나리오 3. [보호사]가 [관리자 페이지] 직접 접근 시 → 보호사 홈으로 강제 이동 ———
        if (auth.status == AuthStatus.authenticated &&
            !isAdminGroup &&
            fullPath.startsWith('/admin')) {
          return '/home';
        }

        // ——— 시나리오 4. [로그인된 사용자]가 [로그인 페이지] 역주행 시 ———
        if (auth.status == AuthStatus.authenticated && fullPath == '/login') {
          if (isAdminGroup) return '/admin/dashboard';
          return '/home';
        }

        // ——— 시나리오 5. [정상 관리자]의 정상 접속 ———
        if (fullPath == '/' || fullPath == '/role-selection') {
          if (auth.isLoggedIn) {
            if (isAdminGroup) return '/admin/dashboard';
            return '/home';
          }
          return null;
        }
        if (fullPath == '/account-locked' && state.extra == null) return '/home';
        if (fullPath == '/admin-init' && auth.isLoggedIn && isAdminGroup && !isInitialPasswordState) return '/admin/dashboard';
        return null;
      } catch (e) {
        return null;
      }
    },
    routes: [
      // 스플래시 화면
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // 역할 선택 화면 (보호사 or 관리자). query role=admin 시 관리자 버튼 강조.
      GoRoute(
        path: '/role-selection',
        name: 'role-selection',
        builder: (context, state) {
          final initialRole = state.uri.queryParameters['role'];
          return RoleSelectionScreen(initialRole: initialRole);
        },
      ),
      
      // 로그인 화면 (tab=admin|user 또는 role 쿼리로 초기 탭 지정)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final roleParam = state.uri.queryParameters['role'];
          final role = tab == 'admin'
              ? 'admin'
              : (tab == 'user'
                  ? 'helper'
                  : (roleParam ?? 'helper'));
          return NewLoginScreen(role: role);
        },
      ),
      // Case A 전용: 초기 비번 변경. 이 화면 이탈 시 로그아웃 처리됨
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      // 계정 잠금 화면 (3회 취소 후 Replacement, 뒤로가기 차단)
      GoRoute(
        path: '/account-locked',
        name: 'account-locked',
        builder: (context, state) => AccountLockedScreen(extra: state.extra),
      ),
      // 초기 관리자 설정 (최상위 독립 라우트). must_change_password | 임시계정 전환.
      GoRoute(
        path: '/admin-init',
        name: 'admin-init',
        builder: (context, state) => const AdminInitScreen(),
      ),
      // 관리자 Shell: 접근 제어 후 진입. 비로그인/비관리자면 builder 실행 전에 여기서 차단.
      GoRoute(
        path: '/admin',
        redirect: (context, state) {
          final p = state.uri.path;
          final container = ProviderScope.containerOf(context);
          final auth = container.read(authProvider);
          if (auth.isInitializing) return '/';
          if (auth.status == AuthStatus.unauthenticated || !auth.isLoggedIn) return '/role-selection';
          if (auth.isAdminGroup && auth.isInitialPasswordState) return '/admin-init';
          if (!auth.isAdminGroup) {
            if (auth.isInitialPasswordState) return '/role-selection';
            return '/home';
          }
          if (p == '/admin' || p == '/admin/') return '/admin/dashboard';
          return null;
        },
        builder: (context, state) => AdminLayout(child: const AdminDashboardScreen()),
        routes: [
          ShellRoute(
            builder: (context, state, child) => AdminLayout(child: child),
            routes: [
              GoRoute(path: 'dashboard', name: 'admin-dashboard', builder: (_, __) => const AdminDashboardScreen()),
              GoRoute(
                path: 'members',
                redirect: (context, state) {
                  final p = state.uri.path;
                  if (p == '/admin/members' || p == '/admin/members/') return '/admin/members/helpers';
                  return null;
                },
                routes: [
                  GoRoute(path: 'helpers', name: 'admin_members_helpers', builder: (_, __) => const HelperManagementScreen()),
                  GoRoute(path: 'clients', name: 'admin-clients', builder: (_, __) => const ClientManagementScreen()),
                ],
              ),
              GoRoute(path: 'matchings', name: 'admin-matchings', builder: (_, __) => const MatchingManagementScreen()),
              GoRoute(path: 'monitoring', name: 'admin-monitoring', builder: (_, __) => const RealTimeMonitoringScreen()),
              GoRoute(path: 'settlement', name: 'admin-settlement', builder: (_, __) => const SettlementScreen()),
              GoRoute(path: 'operations', name: 'admin-operations', builder: (_, __) => const OperationsManagementScreen()),
              GoRoute(path: 'settings', name: 'admin-settings', redirect: (_, __) => '/admin/operations'),
              GoRoute(path: 'placeholder', name: 'admin-placeholder', builder: (context, state) {
                final name = state.uri.queryParameters['name'] ?? 'menu';
                return AdminPlaceholderScreen(title: name);
              }),
            ],
          ),
        ],
      ),
      // 비밀번호 찾기 (query: tab=helper|admin 으로 초기 탭 지정)
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'] ?? 'helper';
          return ForgotPasswordScreen(initialTab: tab == 'admin' ? 1 : 0);
        },
      ),
      // 비밀번호 재설정 (이메일 링크: /reset-password?token=...&email=...)
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          final email = state.uri.queryParameters['email'];
          return ResetPasswordScreen(token: token, email: email);
        },
      ),
      // 홈 화면 (access_denied=1 시 "잘못된 접근입니다" SnackBar 표시)
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => HomeScreen(
          accessDenied: state.uri.queryParameters['access_denied'] == '1',
        ),
      ),
    ],
    
    // 에러 페이지
    errorBuilder: (context, state) {
      final i18n = I18nHelper.of(context);
      return Scaffold(
        body: Center(
          child: Text('${i18n.t('page_not_found')}: ${state.uri}'),
        ),
      );
    },
  );
}
