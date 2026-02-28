# 통합 시뮬레이션 및 검증 보고서

**대상**: 백엔드(Laravel) + 프론트엔드(Flutter) 전체  
**검증 방식**: 코드 추적, Unit/Feature 테스트 추가, Dry Run, 기존 curl 검증 결과 반영

---

## 1. 백엔드(Laravel) 로직 검증

### 1.1 검증 방법

- **코드 추적**: AdminAuthController, HelperAuthController, AuthController, routes/api.php
- **자동화 테스트**: `tests/Feature/AuthIntegrationTest.php` 추가 (Tinker/수동 curl 대체)
- **실행 명령**: `cd backend && php artisan test tests/Feature/AuthIntegrationTest.php`

### 1.2 결과표

| 시나리오 | 검증 내용 | 코드 위치 | 결과 | 비고 |
|----------|-----------|-----------|------|------|
| Admin 로그인 토큰 발급 | center_id + login_id + password 일치 시 access_token 반환 | AdminAuthController 46-48행: `$admin->createToken($deviceName)->plainTextToken` | **정상** | Feature 테스트 `test_admin_login_issues_token`로 검증 |
| status=suspended 로그인 차단 | status !== 'active' 이면 ValidationException, "비활성화된 계정" 메시지 | AdminAuthController 37-43행, HelperAuthController 77-81행 | **정상** | Feature 테스트 `test_suspended_admin_cannot_login`로 검증 |
| Logout 시 토큰 DB 삭제 | POST /api/logout 시 currentAccessToken()->delete() | AuthController 22행, routes 28행(auth:sanctum 그룹) | **정상** | Feature 테스트 `test_logout_deletes_token_from_db`로 검증. 동일 토큰으로 GET /user 시 401 확인 |

---

## 2. 프론트엔드(Flutter) 네비게이션 로직 검증

### 2.1 검증 방법

- **Dry Run**: router.dart redirect, 각 화면 Scaffold/AppBar, auth_provider·api_service 로그아웃 호출 추적

### 2.2 결과표

| 시나리오 | 검증 내용 | 코드 위치 | 결과 | 비고 |
|----------|-----------|-----------|------|------|
| 로그인 성공 후 로그인 페이지 접근 차단 | 로그인된 상태에서 /, /login, /role-selection 접근 시 즉시 /home으로 리다이렉트 | router.dart 24-26행: `location == '/' \|\| '/login' \|\| '/role-selection'` && `isLoggedIn` → `return '/home'` | **정상** | Navigator.pushReplacement 미사용. GoRouter **redirect**로 동일 효과(로그인 페이지 원천 차단) |
| refreshListenable | 로그인/로그아웃 시 redirect 재평가 | auth_router_refresh.dart, auth_provider setSession/clearSession 시 notifyAuthChange() | **정상** | 라우터가 auth 변경 시 갱신됨 |
| 앱바 있는 모든 페이지에 로그아웃 아이콘 | 앱바가 있는 화면 중 “로그인 후 접근 가능한” 화면에 로그아웃 버튼 존재 | home_screen.dart 80-86행: IconButton(Icons.logout), onPressed → auth.logout() 후 context.go('/role-selection') | **정상** | 현재 앱바 있는 화면: Home(로그아웃 있음), NewLogin(로그인 화면이라 로그아웃 없음=의도된 설계). Splash/RoleSelection은 앱바 없음 |
| 로그아웃 클릭 시 세션 초기화 | 서버 로그아웃 호출 + 로컬 토큰 삭제 + 상태 클리어 | auth_provider 34-36행: logout() → _api.logout() → clearSession(); api_service 89-94행: post('/logout') 후 removeToken() | **정상** | 세션(토큰·auth 상태) 완전 초기화 후 역할선택으로 이동 |

---

## 3. 미들웨어 및 라우트 보호

### 3.1 검증 방법

- **코드 추적**: routes/api.php, bootstrap/app.php
- **실제 호출**: 비로그인 GET /api/user → 401 (이전 curl/PowerShell 검증 완료)

### 3.2 결과표

| 시나리오 | 검증 내용 | 코드 위치 | 결과 | 비고 |
|----------|-----------|-----------|------|------|
| auth:sanctum 적용 | /user, /logout, /user/lock, /user/change-password 는 인증 필수 | api.php 25-30행: Route::middleware('auth:sanctum')->group(...) | **정상** | 로그인 API만 그룹 외부 |
| 비로그인 API 호출 시 401 | 토큰 없이 보호된 API 호출 시 401 JSON 반환 | bootstrap/app.php withExceptions: request->is('api/*') && AuthenticationException → 401 JSON | **정상** | route('login') 미정의 500 방지. Accept: application/json 없어도 API는 401 JSON |

---

## 4. 종합 결과 요약

| 구분 | 정상 | 비정상 | 비고 |
|------|------|--------|------|
| 백엔드 로직 | 3/3 | 0 | Feature 테스트로 자동 검증 가능 |
| 프론트 네비게이션/로그아웃 | 4/4 | 0 | redirect 기반 가드, 홈 앱바 로그아웃·세션 초기화 확인 |
| 미들웨어/라우트 보호 | 2/2 | 0 | sanctum + API 인증 실패 시 401 JSON |

**구멍**: 현재 코드 기준으로 미발견. 추후 “관리자 전용 홈” 등 앱바 있는 인증 후 화면이 추가되면 해당 화면에도 로그아웃 버튼 추가 필요.

---

## 5. 백엔드 테스트 실행 방법

```bash
cd d:\Works\Projects\personal_care\backend
php artisan test tests/Feature/AuthIntegrationTest.php
```

- `test_admin_login_issues_token`: Admin 로그인 200 + access_token 존재
- `test_suspended_admin_cannot_login`: suspended 계정 422 + "비활성화" 메시지
- `test_logout_deletes_token_from_db`: 로그아웃 후 토큰 레코드 0건, 동일 토큰으로 GET /user → 401
- `test_protected_api_returns_401_without_token`: 토큰 없이 GET /api/user → 401
