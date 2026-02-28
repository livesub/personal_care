/// API 설정 파일
/// Laravel 백엔드 서버 주소 설정
class ApiConfig {
  // 로컬 개발 서버 주소 (Laravel artisan serve)
  static const String baseUrl = 'http://127.0.0.1:8000';

  // API 엔드포인트
  static const String apiPrefix = '/api';

  // 전체 API URL
  static String get apiUrl => '$baseUrl$apiPrefix';

  // Sanctum CSRF 쿠키
  static String get csrfCookieUrl => '$baseUrl/sanctum/csrf-cookie';

  // 타임아웃 설정 (초)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;
}
