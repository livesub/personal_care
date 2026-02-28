/// GET /api/centers 응답 항목 (관리자 로그인 센터 선택용).
class CenterItem {
  final int id;
  final String name;
  final String code;

  CenterItem({
    required this.id,
    required this.name,
    required this.code,
  });

  factory CenterItem.fromJson(Map<String, dynamic> json) {
    return CenterItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
    );
  }
}
