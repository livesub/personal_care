import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_client_list_item.dart';
import '../models/admin_matching_list_item.dart';
import '../models/admin_member_user.dart';
import 'auth_provider.dart';

/// 모니터링 화면 필터 탭: 전체 / 서비스 중 / 시작 전 / 조기 종료 / 완료
final matchingMonitorFilterProvider = StateProvider<MonitorFilterStatus>((ref) => MonitorFilterStatus.all);

/// 조기 종료 알림 팝업을 이미 보여준 매칭 ID 집합. 리스트/갱신 시 새로 생긴 조기 종료만 팝업 표시.
final adminEarlyStopShownIdsProvider = StateProvider<Set<int>>((ref) => {});

/// GET /api/admin/users — 관리자 회원(보호사) 목록 (1페이지 10건, 레거시 호환).
final adminMembersProvider = FutureProvider<List<AdminMemberUser>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getAdminUsers(page: 1, perPage: 10);
  final list = (data['users'] as List?)?.map((e) => AdminMemberUser.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  return list;
});

/// 보호사 관리 화면: 검색어.
final helperSearchQueryProvider = StateProvider<String>((ref) => '');
/// 보호사 관리 화면: 검색 조건 (name, phone, email).
final helperSearchFieldProvider = StateProvider<String>((ref) => 'name');
/// 보호사 관리 화면: 현재 페이지.
final helperPageProvider = StateProvider<int>((ref) => 1);
/// 보호사 관리 화면: 목록 + 페이징 정보.
final adminHelpersListProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final search = ref.watch(helperSearchQueryProvider);
  final searchField = ref.watch(helperSearchFieldProvider);
  final page = ref.watch(helperPageProvider);
  final data = await api.getAdminUsers(
    search: search.isEmpty ? null : search,
    searchField: searchField,
    page: page,
    perPage: 10,
  );
  final users = (data['users'] as List?)?.map((e) => AdminMemberUser.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  return {
    'users': users,
    'total': data['total'] as int? ?? 0,
    'current_page': data['current_page'] as int? ?? 1,
    'per_page': data['per_page'] as int? ?? 10,
    'last_page': data['last_page'] as int? ?? 1,
  };
});

/// 장애인 관리 화면: 검색어.
final clientSearchQueryProvider = StateProvider<String>((ref) => '');
/// 장애인 관리 화면: 검색 조건 (name, phone, resident_no).
final clientSearchFieldProvider = StateProvider<String>((ref) => 'name');
/// 장애인 관리 화면: 현재 페이지.
final clientPageProvider = StateProvider<int>((ref) => 1);
/// 장애인 관리 화면: 목록 + 페이징 정보.
final adminClientsListProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final search = ref.watch(clientSearchQueryProvider);
  final searchField = ref.watch(clientSearchFieldProvider);
  final page = ref.watch(clientPageProvider);
  final data = await api.getAdminClients(
    search: search.isEmpty ? null : search,
    searchField: searchField,
    page: page,
    perPage: 10,
  );
  final clients = (data['clients'] as List?)?.map((e) => AdminClientListItem.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  return {
    'clients': clients,
    'total': data['total'] as int? ?? 0,
    'current_page': data['current_page'] as int? ?? 1,
    'per_page': data['per_page'] as int? ?? 10,
    'last_page': data['last_page'] as int? ?? 1,
  };
});

/// 매칭 등록 다이얼로그: 현재 센터 소속 보호사 목록 (드롭다운용, per_page=100).
final adminHelpersForMatchingProvider = FutureProvider<List<AdminMemberUser>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getAdminUsers(page: 1, perPage: 100);
  final list = (data['users'] as List?)?.map((e) => AdminMemberUser.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  return list;
});

/// 매칭 등록 다이얼로그: 현재 센터 소속 이용자 목록 (드롭다운용, per_page=100).
final adminClientsForMatchingProvider = FutureProvider<List<AdminClientListItem>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getAdminClients(page: 1, perPage: 100);
  final list = (data['clients'] as List?)?.map((e) => AdminClientListItem.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  return list;
});

/// 매칭 목록(모니터링) 페이지.
final matchingPageProvider = StateProvider<int>((ref) => 1);
/// 매칭 목록 + 페이징.
final adminMatchingsListProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final page = ref.watch(matchingPageProvider);
  final data = await api.getAdminMatchings(page: page, perPage: 10);
  final list = (data['matchings'] as List?)?.map((e) => AdminMatchingListItem.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  return {
    'matchings': list,
    'total': data['total'] as int? ?? 0,
    'current_page': data['current_page'] as int? ?? 1,
    'per_page': data['per_page'] as int? ?? 10,
    'last_page': data['last_page'] as int? ?? 1,
  };
});

/// 실시간 모니터링: 오늘(로컬 00:00 ~ 23:59:59) 매칭만. 1분마다 갱신용.
final adminMonitorTodayListProvider = FutureProvider<List<AdminMatchingListItem>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
  final data = await api.getAdminMatchings(
    page: 1,
    perPage: 100,
    startDate: todayStart,
    endDate: todayEnd,
  );
  final list = (data['matchings'] as List?)?.map((e) => AdminMatchingListItem.fromJson(e as Map<String, dynamic>)).toList() ?? [];
  return list;
});

/// 운영 관리 — 설정(바우처 단가) 조회.
final adminSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getAdminSettings();
});

/// 운영 관리 — 관리자(admins) 목록.
final adminAdminsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getAdminAdmins();
});

/// 운영 관리 — 공지사항 목록.
final adminNoticesListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getAdminNotices();
});
