import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/center_item.dart';
import '../providers/auth_provider.dart';

const String _keyLastCenterId = 'login_last_selected_center_id';

/// GET /api/centers 호출 — 관리자 탭 센터 드롭다운용.
final centersProvider = FutureProvider<List<CenterItem>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final list = await api.getCenters();
  return list
      .map((e) => e is Map<String, dynamic> ? CenterItem.fromJson(e) : null)
      .whereType<CenterItem>()
      .toList();
});

/// 선택된 센터 ID. 앱 재시작 후에도 유지(SharedPreferences).
class SelectedCenterNotifier extends StateNotifier<int?> {
  SelectedCenterNotifier(this._prefs) : super(null);

  final SharedPreferences _prefs;

  /// 저장된 마지막 선택 센터 ID 로드.
  Future<void> loadFromPrefs() async {
    final id = _prefs.getInt(_keyLastCenterId);
    if (id != null) state = id;
  }

  void select(int? centerId) {
    state = centerId;
    if (centerId != null) {
      _prefs.setInt(_keyLastCenterId, centerId);
    } else {
      _prefs.remove(_keyLastCenterId);
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden (e.g. in main.dart) with runWithOverrides.',
  );
});

final selectedCenterIdProvider =
    StateNotifierProvider<SelectedCenterNotifier, int?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SelectedCenterNotifier(prefs);
});
