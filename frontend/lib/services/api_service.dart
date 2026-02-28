import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// Laravel API 통신 서비스
/// Sanctum 토큰 기반 인증 처리.
/// 401 시 토큰 삭제 + on401 콜백(세션 소독) 호출 → 라우터가 로그인으로 강제 리다이렉트.
class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'sanctum_token';
  /// Case A(초기 비번) 전용. Storage에 저장하지 않음 → 새로고침 시 사라짐.
  String? _memoryOnlyToken;

  /// 401 발생 시 호출할 콜백 (세션 clear 등). main/Provider에서 등록.
  static void Function()? on401Callback;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiUrl,
        connectTimeout: Duration(seconds: ApiConfig.connectionTimeout),
        receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await removeToken();
            on401Callback?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// GET 요청
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  /// GET /api/centers — 관리자 로그인 센터 선택용.
  Future<List<dynamic>> getCenters() async {
    final res = await _dio.get('/centers');
    if (res.data is! List) return [];
    return res.data as List<dynamic>;
  }

  /// GET /api/admin/dashboard — 대시보드 메인 (통계 4종 + 오늘 매칭 + 공지 퀵뷰).
  Future<Map<String, dynamic>> getAdminDashboard() async {
    final res = await _dio.get<Map<String, dynamic>>('/admin/dashboard');
    return res.data ?? {};
  }

  /// GET /api/admin/menus — 권한(role)별 메뉴 목록. auth:sanctum 필요.
  Future<List<Map<String, dynamic>>> getAdminMenus() async {
    final res = await _dio.get('/admin/menus');
    final data = res.data;
    if (data is! Map<String, dynamic> || data['menus'] is! List) return [];
    return (data['menus'] as List).whereType<Map<String, dynamic>>().toList();
  }

  /// GET /api/admin/users — 관리자 회원(보호사) 목록. 검색·페이징.
  Future<Map<String, dynamic>> getAdminUsers({String? search, String? searchField, int page = 1, int perPage = 10}) async {
    final res = await _dio.get('/admin/users', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (searchField != null && searchField.isNotEmpty) 'search_field': searchField,
      'page': page,
      'per_page': perPage,
    });
    final data = res.data as Map<String, dynamic>? ?? {};
    final users = (data['users'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    return {
      'users': users,
      'total': data['total'] as int? ?? users.length,
      'current_page': data['current_page'] as int? ?? 1,
      'per_page': data['per_page'] as int? ?? perPage,
      'last_page': data['last_page'] as int? ?? 1,
    };
  }

  /// DELETE /api/admin/users/{id} — 보호사 현재 센터 소속 해제. 타 센터 포함 일정 있으면 422.
  Future<void> deleteAdminUser(int userId) async {
    await _dio.delete('/admin/users/$userId');
  }

  /// POST /api/admin/users/{id}/unlock — 계정 잠금 해제.
  Future<void> postAdminUserUnlock(int userId) async {
    await _dio.post('/admin/users/$userId/unlock');
  }

  /// GET /api/admin/users/check — 휴대폰 번호로 보호사 존재 여부 조회. 스마트 등록용.
  /// 응답: { exists: true|false, name?: "홍길동" }
  Future<Map<String, dynamic>> getAdminUserCheck(String loginId) async {
    final raw = loginId.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.length < 10) return {'exists': false};
    final res = await _dio.get('/admin/users/check', queryParameters: {'login_id': raw});
    final data = res.data as Map<String, dynamic>? ?? {};
    return {'exists': data['exists'] == true, 'name': data['name'] as String?};
  }

  /// POST /api/admin/users — 보호사(회원) 신규 등록. 기존 회원이면 소속만 추가(비밀번호 미전송).
  Future<Response> postAdminUserStore(Map<String, dynamic> data) async {
    return await _dio.post('/admin/users', data: data);
  }

  /// GET /api/admin/clients — 이용자(장애인) 목록. 검색·페이징.
  Future<Map<String, dynamic>> getAdminClients({String? search, String? searchField, int page = 1, int perPage = 10}) async {
    final res = await _dio.get('/admin/clients', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (searchField != null && searchField.isNotEmpty) 'search_field': searchField,
      'page': page,
      'per_page': perPage,
    });
    final data = res.data as Map<String, dynamic>? ?? {};
    final clients = (data['clients'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    return {
      'clients': clients,
      'total': data['total'] as int? ?? clients.length,
      'current_page': data['current_page'] as int? ?? 1,
      'per_page': data['per_page'] as int? ?? perPage,
      'last_page': data['last_page'] as int? ?? 1,
    };
  }

  /// DELETE /api/admin/clients/{id} — 이용자 삭제.
  Future<void> deleteAdminClient(int id) async {
    await _dio.delete('/admin/clients/$id');
  }

  /// POST /api/admin/clients — 이용자(Client) 신규 등록.
  /// Body는 반드시 jsonEncode로 직렬화하여 쌍따옴표 등이 \" 로 이스케이프되도록 함.
  Future<Response> postAdminClientStore(Map<String, dynamic> data) async {
    return await _dio.post(
      '/admin/clients',
      data: jsonEncode(data),
      options: Options(contentType: 'application/json'),
    );
  }

  /// GET /api/admin/matchings — 매칭 목록(모니터링). is_duplicate, is_early_stop, early_stop_reason 포함.
  /// [startDate]/[endDate]: 날짜 필터용 로컬 날짜 문자열(yyyy-MM-dd). null이면 전체.
  Future<Map<String, dynamic>> getAdminMatchings({
    int page = 1,
    int perPage = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (startDate != null) params['start_date'] = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    if (endDate != null) params['end_date'] = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final res = await _dio.get('/admin/matchings', queryParameters: params);
    final data = res.data as Map<String, dynamic>? ?? {};
    final matchings = (data['matchings'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    return {
      'matchings': matchings,
      'total': data['total'] as int? ?? matchings.length,
      'current_page': data['current_page'] as int? ?? 1,
      'per_page': data['per_page'] as int? ?? perPage,
      'last_page': data['last_page'] as int? ?? 1,
    };
  }

  /// POST /api/admin/matchings — 매칭 등록. 전역 중복 시 422.
  Future<Response> postAdminMatching(Map<String, dynamic> data) async {
    return await _dio.post('/admin/matchings', data: data);
  }

  /// PATCH /api/admin/matchings/{id} — 매칭 수정. 시작/종료된 매칭은 시간 변경 불가.
  Future<Response> patchAdminMatching(int id, Map<String, dynamic> data) async {
    return await _dio.patch('/admin/matchings/$id', data: data);
  }

  /// DELETE /api/admin/matchings/{id} — 매칭 삭제. 미래 스케줄만 허용.
  Future<void> deleteAdminMatching(int id) async {
    await _dio.delete('/admin/matchings/$id');
  }

  /// GET /api/admin/settings — 운영 관리 설정(바우처 단가 등) 조회.
  Future<Map<String, dynamic>> getAdminSettings() async {
    final res = await _dio.get('/admin/settings');
    final data = res.data as Map<String, dynamic>? ?? {};
    return {
      'default_hourly_wage': data['default_hourly_wage'] as int? ?? 16150,
      'voucher_price': data['voucher_price'] as int? ?? 16150,
    };
  }

  /// PATCH /api/admin/settings — 바우처 단가 수정. Super만.
  Future<Map<String, dynamic>> patchAdminSettings({required int defaultHourlyWage}) async {
    final res = await _dio.patch('/admin/settings', data: {'default_hourly_wage': defaultHourlyWage});
    return res.data as Map<String, dynamic>;
  }

  /// GET /api/admin/admins — 관리자(admins) 목록. 본인 센터만.
  Future<List<Map<String, dynamic>>> getAdminAdmins() async {
    final res = await _dio.get('/admin/admins');
    final data = res.data as Map<String, dynamic>? ?? {};
    final list = (data['admins'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    return list;
  }

  /// POST /api/admin/admins — 관리자 추가. Super만.
  Future<Map<String, dynamic>> postAdminAdmin(Map<String, dynamic> body) async {
    final res = await _dio.post('/admin/admins', data: body);
    return res.data as Map<String, dynamic>;
  }

  /// GET /api/admin/notices — 공지사항 목록.
  Future<List<Map<String, dynamic>>> getAdminNotices() async {
    final res = await _dio.get('/admin/notices');
    final data = res.data as Map<String, dynamic>? ?? {};
    return (data['notices'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
  }

  /// POST /api/admin/notices — 공지 등록.
  Future<Map<String, dynamic>> postAdminNotice(Map<String, dynamic> body) async {
    final res = await _dio.post('/admin/notices', data: body);
    return res.data as Map<String, dynamic>;
  }

  /// PATCH /api/admin/notices/{id} — 공지 수정.
  Future<Map<String, dynamic>> patchAdminNotice(int id, Map<String, dynamic> body) async {
    final res = await _dio.patch('/admin/notices/$id', data: body);
    return res.data as Map<String, dynamic>;
  }

  /// DELETE /api/admin/notices/{id} — 공지 삭제.
  Future<void> deleteAdminNotice(int id) async {
    await _dio.delete('/admin/notices/$id');
  }

  /// GET /api/admin/settlement — 정산 데이터(급여·바우처). year, month 필수.
  Future<Map<String, dynamic>> getSettlement({required int year, required int month}) async {
    final res = await _dio.get('/admin/settlement', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  /// GET /api/admin/settlement/export — 엑셀 다운로드. 바이트 배열과 파일명 반환.
  Future<({List<int> bytes, String filename})> getSettlementExport({required int year, required int month}) async {
    final res = await _dio.get<List<int>>(
      '/admin/settlement/export',
      queryParameters: {'year': year, 'month': month},
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = res.data ?? <int>[];
    final filename = _filenameFromContentDisposition(res.headers.value('content-disposition')) ?? 'settlement_$year-${month.toString().padLeft(2, '0')}.xlsx';
    return (bytes: bytes, filename: filename);
  }

  static String? _filenameFromContentDisposition(String? value) {
    if (value == null) return null;
    final match = RegExp(r'filename="?([^";\n]+)"?').firstMatch(value);
    return match?.group(1)?.trim();
  }

  /// POST 요청
  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  /// 로그인 전용 POST. statusCode 200일 때만 성공, 그 외 DioException 발생.
  Future<Response> postLogin(String path, {required Map<String, dynamic> data}) async {
    return await _dio.post(
      path,
      data: data,
      options: Options(validateStatus: (status) => status == 200),
    );
  }

  /// PUT 요청
  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  /// DELETE 요청
  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  /// 토큰 저장 (Storage에 영구 저장. Case B 정상 이용자용)
  Future<void> saveToken(String token) async {
    _memoryOnlyToken = null;
    await _storage.write(key: _tokenKey, value: token);
  }

  /// 토큰 조회 (메모리 전용 토큰 우선, 없으면 Storage)
  Future<String?> getToken() async {
    if (_memoryOnlyToken != null && _memoryOnlyToken!.isNotEmpty) return _memoryOnlyToken;
    return await _storage.read(key: _tokenKey);
  }

  /// Case A: 메모리에만 보관. Storage에 저장하지 않음 → 새로고침/재실행 시 로그아웃.
  void setTokenInMemoryOnly(String token) {
    _memoryOnlyToken = token;
  }

  /// 메모리 전용 토큰만 동기적으로 제거 (redirect 등에서 사용)
  void clearMemoryOnlyToken() {
    _memoryOnlyToken = null;
  }

  /// 토큰 삭제 (로그아웃: Storage + 메모리)
  Future<void> removeToken() async {
    _memoryOnlyToken = null;
    await _storage.delete(key: _tokenKey);
  }

  /// Case A → B 전환: 현재(메모리) 토큰을 Storage에 저장. 비밀번호 변경 완료 후 호출.
  Future<void> persistCurrentToken() async {
    final t = _memoryOnlyToken ?? await _storage.read(key: _tokenKey);
    if (t != null && t.isNotEmpty) {
      _memoryOnlyToken = null;
      await _storage.write(key: _tokenKey, value: t);
    }
  }

  /// 로그인 여부 확인
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// 서버에 토큰 폐기 요청 후 로컬 토큰 삭제. 실패해도 로컬은 삭제.
  Future<void> logout() async {
    try {
      await post('/logout');
    } catch (_) {}
    await removeToken();
  }

  /// GET /user — 현재 로그인 사용자 정보 (세션 복원·업무 종료 후 갱신용).
  /// [centerId] 있으면 X-Center-Id 헤더 추가 (보호사 세션 복원 시 필수).
  Future<Response> getUser({int? centerId}) async {
    if (centerId != null) {
      return await _dio.get('/user', options: Options(headers: {'X-Center-Id': centerId.toString()}));
    }
    return await _dio.get('/user');
  }

  /// GET /api/helper/home — 보호사 홈 데이터. X-Center-Id 헤더 필수.
  Future<Map<String, dynamic>> getHelperHome({required int centerId}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/helper/home',
      options: Options(headers: {'X-Center-Id': centerId.toString()}),
    );
    return res.data ?? {};
  }

  /// GET /api/notices/check-new — 보호사 앱 30초마다 호출. 해당 센터 최신 공지 1건(id/title/content/center_name).
  Future<Map<String, dynamic>> getNoticesCheckNew({required int centerId}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notices/check-new',
      options: Options(headers: {'X-Center-Id': centerId.toString()}),
    );
    return res.data ?? {};
  }

  /// POST /api/helper/matchings/{id}/start — 업무 시작.
  Future<void> postHelperMatchingStart(int matchingId, {required int centerId}) async {
    await _dio.post(
      '/helper/matchings/$matchingId/start',
      options: Options(headers: {'X-Center-Id': centerId.toString()}),
    );
  }

  /// POST /api/helper/matchings/{id}/complete — 업무 종료 (work_log, early_end_reason, actual_end_time).
  Future<void> postHelperMatchingComplete(
    int matchingId, {
    required int centerId,
    String? workLog,
    String? earlyEndReason,
    required String actualEndTime,
  }) async {
    await _dio.post(
      '/helper/matchings/$matchingId/complete',
      data: {
        if (workLog != null && workLog.trim().isNotEmpty) 'work_log': workLog.trim(),
        if (earlyEndReason != null && earlyEndReason.trim().isNotEmpty) 'early_end_reason': earlyEndReason.trim(),
        'actual_end_time': actualEndTime,
      },
      options: Options(headers: {'X-Center-Id': centerId.toString()}),
    );
  }

  /// POST /user/end-work — 업무 종료. 조기 종료 시 early_stop_reason 필수. 위치 검증용으로 종료 버튼 클릭 좌표 전달 가능.
  Future<void> postEndWork({
    required String realEndTime,
    String? earlyStopReason,
    double? checkOutLat,
    double? checkOutLng,
  }) async {
    await _dio.post('/user/end-work', data: {
      'real_end_time': realEndTime,
      if (earlyStopReason != null && earlyStopReason.trim().isNotEmpty) 'early_stop_reason': earlyStopReason.trim(),
      if (checkOutLat != null && checkOutLng != null) 'check_out_lat': checkOutLat,
      if (checkOutLat != null && checkOutLng != null) 'check_out_lng': checkOutLng,
    });
  }

  /// 계정 잠금 (3회 본인 확인 실패 시). 보호사 전용.
  Future<void> lock() async {
    await post('/user/lock');
  }

  /// 최초 로그인 비밀번호 변경 (인증 필요). password_confirmation 필수.
  Future<void> changePassword(String password, String passwordConfirmation) async {
    await post('/user/change-password', data: {
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  /// 최초 로그인 완료 (temporary_token 기반, 인증 없음). 성공 시 is_first_login=0.
  Future<void> completeFirstLogin(String temporaryToken, String password, String passwordConfirmation) async {
    await _dio.post(
      '/helper/complete-first-login',
      data: {
        'temporary_token': temporaryToken,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      options: Options(validateStatus: (status) => status == 200),
    );
  }

  /// 최초 로그인 비밀번호 변경 3회 취소 시 계정 잠금. temporary_token으로 유저 식별.
  /// 성공 시 { message, center_name } 반환. 인증 헤더 없이 호출.
  Future<Map<String, dynamic>> lockAccount(String temporaryToken) async {
    final res = await _dio.post(
      '/auth/lock-account',
      data: {'temporary_token': temporaryToken},
      options: Options(validateStatus: (status) => status == 200),
    );
    return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
  }
}
