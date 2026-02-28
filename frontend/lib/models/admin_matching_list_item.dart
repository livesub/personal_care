import 'dart:math' as math;

/// GET /api/admin/matchings 목록 응답 항목. 모니터링·부정 수급·조기 종료 표시용.
class AdminMatchingListItem {
  final int id;
  final int userId;
  final String userName;
  final int? clientId;
  final String clientName;
  final String? startAt;
  final String? endAt;
  /// 실제 업무 시작 시각 (보호사가 '업무 시작' 버튼 누른 시점). API: actual_start_time.
  final String? actualStartTime;
  final String? realEndTime;
  final String? earlyStopReason;
  final bool isEarlyStop;
  final bool isDuplicate;
  final int hourlyWage;
  /// 시간(시작/종료) 수정 가능 여부. 이미 시작·종료된 매칭은 false.
  final bool canEditTime;
  /// 삭제 가능 여부. 미래 스케줄(아직 시작 전)만 true.
  final bool canDelete;
  /// 이용자 집 좌표 (위치 검증용). [위치 정책] 실시간 추적 절대 없음.
  final double? clientHomeLat;
  final double? clientHomeLng;
  /// [위치 정책] '시작'/'종료' 버튼을 누른 그 순간의 스냅샷(Snapshot)만 저장. 추적 없음.
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;

  AdminMatchingListItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.clientId,
    required this.clientName,
    this.startAt,
    this.endAt,
    this.actualStartTime,
    this.realEndTime,
    this.earlyStopReason,
    required this.isEarlyStop,
    required this.isDuplicate,
    this.hourlyWage = 0,
    this.canEditTime = false,
    this.canDelete = false,
    this.clientHomeLat,
    this.clientHomeLng,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
  });

  factory AdminMatchingListItem.fromJson(Map<String, dynamic> json) {
    return AdminMatchingListItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String? ?? '',
      clientId: json['client_id'] as int?,
      clientName: json['client_name'] as String? ?? '',
      startAt: json['start_at'] as String?,
      endAt: json['end_at'] as String?,
      actualStartTime: json['actual_start_time'] as String?,
      realEndTime: json['real_end_time'] as String?,
      earlyStopReason: json['early_stop_reason'] as String?,
      isEarlyStop: json['is_early_stop'] == true,
      isDuplicate: json['is_duplicate'] == true,
      hourlyWage: (json['hourly_wage'] is int) ? json['hourly_wage'] as int : 0,
      canEditTime: json['can_edit_time'] == true,
      canDelete: json['can_delete'] == true,
      clientHomeLat: _toDouble(json['client_home_lat']),
      clientHomeLng: _toDouble(json['client_home_lng']),
      checkInLat: _toDouble(json['check_in_lat']),
      checkInLng: _toDouble(json['check_in_lng']),
      checkOutLat: _toDouble(json['check_out_lat']),
      checkOutLng: _toDouble(json['check_out_lng']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// 거리 대조(Validation): [이용자 집 좌표]와 [버튼 클릭 시점 스냅샷 좌표] 간 거리(m). 100m 이상 시 경고.
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * (math.pi / 180);

  /// 위치 경고 ⚠️: (저장된 버튼 클릭 좌표)와 (이용자 집 좌표) 거리가 100m 이상이면 true.
  static bool isLocationWarning(AdminMatchingListItem item) {
    final homeLat = item.clientHomeLat;
    final homeLng = item.clientHomeLng;
    if (homeLat == null || homeLng == null) return false;
    if (item.checkInLat != null && item.checkInLng != null) {
      if (distanceMeters(homeLat, homeLng, item.checkInLat!, item.checkInLng!) >= 100) return true;
    }
    if (item.checkOutLat != null && item.checkOutLng != null) {
      if (distanceMeters(homeLat, homeLng, item.checkOutLat!, item.checkOutLng!) >= 100) return true;
    }
    return false;
  }

  /// 서버에서 내려준 날짜 문자열(APP_TIMEZONE 기준)을 기기 로컬 시간으로 표시 (예: 2026-02-22 09:00).
  static String formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// actual_start_time 등 날짜 문자열에서 시:분만 추출 (예: 13:05). 상태 옆 표시용.
  static String formatTimeOnly(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final local = d.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// 서버 날짜 문자열을 로컬 DateTime으로 파싱. 타이머/비교 시 로컬 기준 사용.
  static DateTime? parseToLocal(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    return d?.toLocal();
  }

  /// 모니터링 필터용 상태: 전체/서비스 중/시작 전/조기 종료/완료 (로컬 시간 기준)
  static MonitorFilterStatus monitorStatus(AdminMatchingListItem item) {
    final now = DateTime.now();
    final startLocal = parseToLocal(item.startAt);
    final endLocal = parseToLocal(item.endAt);
    final realEndLocal = parseToLocal(item.realEndTime);
    if (startLocal == null) return MonitorFilterStatus.completed;
    if (now.isBefore(startLocal)) return MonitorFilterStatus.notStarted;
    final effectiveEnd = realEndLocal ?? endLocal;
    if (effectiveEnd != null && now.isAfter(effectiveEnd)) {
      return item.isEarlyStop ? MonitorFilterStatus.earlyStop : MonitorFilterStatus.completed;
    }
    return MonitorFilterStatus.inProgress;
  }

  /// 종료됨(예정 종료 또는 실제 종료 시각 경과). 완료 탭 필터용.
  static bool isEnded(AdminMatchingListItem item) {
    final now = DateTime.now();
    final endLocal = parseToLocal(item.endAt);
    final realEndLocal = parseToLocal(item.realEndTime);
    final effectiveEnd = realEndLocal ?? endLocal;
    return effectiveEnd != null && now.isAfter(effectiveEnd);
  }

  /// 지각 알림: 예정 시작(로컬)보다 10분 지났는데 아직 '시작 전' 상태(서비스 미시작).
  /// 조건: now >= startAt.toLocal() + 10분 이고, 아직 종료 전(now < effectiveEnd).
  /// (actual_start_time 없이 예정 시작+10분 경과 & 미종료면 지각으로 간주)
  static bool isLateStart(AdminMatchingListItem item) {
    final now = DateTime.now();
    final startLocal = parseToLocal(item.startAt);
    if (startLocal == null) return false;
    final deadline = startLocal.add(const Duration(minutes: 10));
    if (now.isBefore(deadline)) return false;
    final endLocal = parseToLocal(item.endAt);
    final realEndLocal = parseToLocal(item.realEndTime);
    final effectiveEnd = realEndLocal ?? endLocal;
    if (effectiveEnd != null && !now.isBefore(effectiveEnd)) return false;
    return true;
  }

  /// 서비스 중일 때 경과 시간. 실제 시작(actual_start_time) 있으면 그 시각 기준, 없으면 예정 시작 기준. 로컬 시간.
  static Duration? elapsedSinceStart(AdminMatchingListItem item) {
    final startLocal = parseToLocal(item.actualStartTime) ?? parseToLocal(item.startAt);
    if (startLocal == null) return null;
    final now = DateTime.now();
    if (now.isBefore(startLocal)) return null;
    final endLocal = parseToLocal(item.endAt);
    final realEndLocal = parseToLocal(item.realEndTime);
    final effectiveEnd = realEndLocal ?? endLocal;
    if (effectiveEnd != null && now.isAfter(effectiveEnd)) return null;
    return now.difference(startLocal);
  }

  /// 경과 시간을 00:12:34 형식으로 포맷
  static String formatTimer(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// 모니터링 필터 탭 상태
enum MonitorFilterStatus {
  all,
  inProgress,
  notStarted,
  earlyStop,
  completed,
}
