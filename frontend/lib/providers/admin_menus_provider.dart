import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_menu_item.dart';
import 'auth_provider.dart';

/// GET /api/admin/menus — 로그인한 관리자 권한(role)별 메뉴. Staff면 설정 제외.
final adminMenusProvider = FutureProvider<List<AdminMenuItem>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final list = await api.getAdminMenus();
  return list.map((e) => AdminMenuItem.fromJson(e)).toList();
});
