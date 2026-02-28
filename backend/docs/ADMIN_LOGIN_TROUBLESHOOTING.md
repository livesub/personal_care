# 관리자 로그인 "아이디 또는 비밀번호가 올바르지 않습니다" 해결

## 현재 동작 (수정 반영됨)

- **로그인 시**: Admin **모델을 쓰지 않고** `DB::table('admins')` 로만 조회합니다.
- 비밀번호는 저장된 해시가 **Argon2id**면 Argon2id로, **bcrypt**면 bcrypt로 검증합니다.
- **bcrypt로 로그인에 성공하면** 그 시점에 비밀번호를 **Argon2id로 재저장**합니다. (다음부터는 Argon2id만 사용)
- 따라서 **DB가 bcrypt여도** 양주 admin_YJU / YJU!@# 로 로그인하면 동작합니다. (서버 재부팅·DB 초기화 불필요)

**초기 데이터·안전성 우선(B)** 이면 관리자 전부 지우고 시더로만 다시 만들기:

```bash
php artisan admins:fresh-seed
```

(확인 프롬프트 후, 관리자용 토큰 삭제 → admins 비우기 → AdminSeeder 실행 → Argon2id 계정만 생성.)

기존 관리자 행은 유지하고 **비밀번호만** Argon2id로 바꾸려면:

```bash
php artisan admins:rehash-passwords
```

---

## 원인 (상세, 참고용)

1. **프로젝트 보안 규정**: 비밀번호 해싱은 **Argon2id만** 사용합니다. (`config/hashing.php`, `.env` 의 `HASH_DRIVER=argon2id`)

2. **DB에 저장된 값이 bcrypt인 경우**  
   예전에 Laravel 기본값(bcrypt)으로 시더를 돌렸거나, 마이그레이션/시더가 bcrypt로 저장했다면 `admins.password` 컬럼에는 **bcrypt** 해시(`$2y$...`)가 들어 있습니다.

3. **로그인 시 동작 순서**  
   - `admins` 테이블에서 `login_id`(전역 유일)로 1건 조회 후, `center_id` 일치·비밀번호 검증합니다.  
   - Eloquent가 DB 행을 모델로 채울 때 `password` 컬럼 값이 **hashed 캐스트**를 통과합니다.  
   - Laravel의 `hashed` 캐스트는 **저장 시**: 평문이면 `Hash::make()`(현재 설정 = Argon2id)로 해시하고,  
     **로드 시**: 이미 해시된 값이면 `Hash::verifyConfiguration($value)` 로 **현재 기본 드라이버(Argon2id) 기준**으로 검사합니다.  
   - DB 값이 **bcrypt**이면 Argon2id가 아니므로 `verifyConfiguration` 이 실패하고  
     `RuntimeException("Could not verify the hashed value's configuration.")` 이 발생합니다.  
   - 이 예외를 `AdminAuthController` 에서 잡아서 **401 "아이디 또는 비밀번호가 올바르지 않습니다."** 로 응답합니다.  
   - 따라서 **비밀번호를 한 번도 검사하지 않은 상태에서** 실패 처리됩니다.  
     즉, **아이디/비번이 맞아도** DB 비밀번호가 bcrypt면 무조건 이 메시지가 납니다.

4. **정리**  
   - **원인**: `admins.password` 가 **bcrypt**로 저장되어 있는데, 앱은 **Argon2id만** 사용하도록 설정되어 있어,  
     모델 로드 단계에서 예외가 나고 그게 401로 변환되는 것.  
   - **해결**: DB의 관리자 비밀번호를 **Argon2id**로 다시 저장하면 됩니다.

---

## 해결 방법 (반드시 할 것)

### 1. 시더로 비밀번호를 Argon2id로 다시 저장

**명령 한 줄만 실행하면 됩니다.**

```bash
cd backend
php artisan db:seed --class=AdminSeeder
```

- **의미**: 각 센터별 임시 계정 `admin_{센터코드}`(예: admin_YJU)를 `updateOrCreate` 로 찾아서, 비밀번호를 평문(`{센터코드}!@#`, 예: `YJU!@#`)으로 넣고 저장합니다.  
  Admin 모델의 `password` setter + `hashed` 캐스트가 **현재 설정(Argon2id)**으로 해시해 DB에 넣습니다.  
  따라서 **기존 행이 있어도 비밀번호만 Argon2id로 덮어씌워집니다.**

- **서버 재부팅**: **필요 없음.**  
- **DB 초기화(마이그레이션 롤백/전체 삭제)**: **필요 없음.**  
  시더는 해당 관리자 행만 업데이트합니다.

- **실행 후**:  
  - 양주 센터: ID `admin_YJU`, PW `YJU!@#`  
  - 의정부 센터: ID `admin_UJB`, PW `UJB!@#`  
  등으로 다시 로그인하면 됩니다.

### 2. (선택) DB에서 직접 확인

- 비밀번호 컬럼이 **Argon2id**인지 **bcrypt**인지 확인하려면:

```sql
SELECT id, center_id, login_id, LEFT(password, 20) AS password_prefix FROM admins WHERE login_id LIKE 'admin_%';
```

- `password_prefix` 가 `$argon2id$` 로 시작하면 Argon2id, `$2y$` 또는 `$2a$` 로 시작하면 bcrypt입니다.  
  bcrypt인 행이 있으면 위 시더를 한 번 실행하면 됩니다.

---

## 요약

| 항목 | 내용 |
|------|------|
| **원인** | DB의 `admins.password` 가 bcrypt인데, 앱은 Argon2id만 사용. 모델 로드 시 hashed 캐스트에서 예외 → 401로 처리됨. |
| **해결** | `php artisan db:seed --class=AdminSeeder` 한 번 실행. |
| **서버 재부팅** | **불필요** |
| **DB 초기화** | **불필요** |
