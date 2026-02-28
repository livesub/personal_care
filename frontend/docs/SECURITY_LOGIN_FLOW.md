# 로그인 보안: 전수 조사 및 시뮬레이션

## 1. 플러터 로그인 응답 처리 (확인·수정 사항)

- **실제 사용 화면**: `/login` 라우트는 `NewLoginScreen`(`new_login_screen.dart`)만 사용. `login_screen.dart`는 미사용(버튼 시 역할 선택으로만 이동).
- **HTTP 상태 코드**:
  - 로그인 POST는 `ApiService.postLogin()` 사용. **`validateStatus: (status) => status == 200`** → **정확히 200일 때만** 성공으로 간주, 401/422/500 등은 전부 **DioException** 발생.
  - `NewLoginScreen._handleLogin()`에서도 **`res.statusCode != 200`이면** 즉시 `_showLoginFailed()` 후 return, **Navigator/context.go('/home') 실행 안 함**.
- **응답 본문**: `success` 필드에 의존하지 않음. **statusCode == 200** 이후에만 `access_token`·`user` 검증(`_isValidLoginResponse`) 수행.
- **이중 검증**: POST 200 + 응답 유효해도 **토큰 저장 후 GET /user** 호출. **GET /user의 statusCode != 200**이면 `_verifyTokenWithServer`가 null 반환 → 토큰 삭제, 로그인 실패 처리, **홈으로 이동하지 않음**.

---

## 2. 라라벨 로그인 검증 (확인·수정 사항)

- **로그인 API**:
  - **보호사**: `HelperAuthController::login()` (POST `/api/helper/login`)
  - **관리자**: `AdminAuthController::login()` (POST `/api/admin/login`)
  - `AuthController.php`에는 **로그인 메서드 없음** (logout, me만 존재).
- **인증 방식**: `Auth::attempt()` 미사용. `User::where('login_id', ...)->first()` + `Hash::check(password, $user->password)`로 검증.
- **잘못된 비밀번호/비활성 계정**:
  - **수정 후**: `return response()->json(['message' => '...'], 401);` 로 **명시적 401** 반환.
  - try-catch로 감싸서 에러 시에도 성공 응답을 보내는 구간 없음. 예외 발생 시 Laravel이 500 등 적절한 상태 코드로 응답.

---

## 3. 시뮬레이션: 잘못된 비번 요청 시 동작

| 구분 | 백엔드가 내보내는 HTTP 상태 코드 | 백엔드 응답 본문 (예) | 프론트엔드 동작 | 프론트엔드가 띄우는 메시지 |
|------|----------------------------------|------------------------|------------------|----------------------------|
| 보호사: 잘못된 비밀번호 | **401** | `{"message":"아이디 또는 비밀번호가 올바르지 않습니다."}` | `postLogin()`에서 **DioException** → catch 블록 진입. 세션 저장·홈 이동 없음. | 스낵바: `response.data['message']` 또는 i18n `login_failed` ("로그인에 실패했습니다") |
| 보호사: 비활성 계정 | **401** | `{"message":"비활성화된 계정입니다. 센터에 문의하세요."}` | 동일. 홈 이동 없음. | 스낵바: "비활성화된 계정입니다. 센터에 문의하세요." |
| 관리자: 잘못된 비밀번호 | **401** | `{"message":"아이디 또는 비밀번호가 올바르지 않습니다."}` | 동일. 홈 이동 없음. | 스낵바: "아이디 또는 비밀번호가 올바르지 않습니다." 또는 "로그인에 실패했습니다" |
| 관리자: 비활성 계정 | **401** | `{"message":"비활성화된 계정입니다."}` | 동일. 홈 이동 없음. | 스낵바: "비활성화된 계정입니다." 또는 "로그인에 실패했습니다" |
| POST 200인데 GET /user 401 (토큰 무효) | 로그인: **200** / GET /user: **401** | - | POST 후 토큰 저장 → GET /user 호출 → 401 → `_verifyTokenWithServer` null → 토큰 삭제, `_showLoginFailed()`, **홈 이동 안 함** | "로그인에 실패했습니다" |
| 서버 미기동(연결 실패) | - | - | **DioException** (연결 오류) → catch → **홈 이동 안 함** | "로그인에 실패했습니다" 또는 Dio 메시지 |

---

## 4. 정리

- **플러터**: `statusCode == 200`일 때만 로그인 성공으로 간주하고, POST 성공 후에도 GET /user가 200일 때만 세션 설정·홈 이동.
- **라라벨**: 잘못된 비밀번호·비활성 계정 시 **항상 401 + JSON message** 반환, try-catch로 성공 응답을 덮어쓰지 않음.
- 위 표와 같이 잘못된 비번 요청 시 백엔드는 401, 프론트는 스낵바만 띄우고 **환영(홈) 화면으로 넘어가지 않음**.
