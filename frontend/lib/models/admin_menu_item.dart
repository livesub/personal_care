/// GET /api/admin/menus 응답 항목.
class AdminMenuItem {
  final int id;
  final String name;
  final String routeName;
  final String? icon;

  AdminMenuItem({
    required this.id,
    required this.name,
    required this.routeName,
    this.icon,
  });

  factory AdminMenuItem.fromJson(Map<String, dynamic> json) {
    return AdminMenuItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      routeName: json['route_name'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }
}
