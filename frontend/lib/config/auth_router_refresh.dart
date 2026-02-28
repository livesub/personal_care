import 'package:flutter/foundation.dart';

/// 라우터 리다이렉트 갱신용. 로그인/로그아웃 시 notifyListeners() 호출.
final authRouterRefresh = ValueNotifier<int>(0);

void notifyAuthChange() {
  authRouterRefresh.value++;
}
