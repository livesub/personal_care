/// 웹 전용: admin 폭파 직후 브라우저가 이전 'admin 세션' 페이지로 돌아가는 것을 물리적으로 차단.

import 'dart:html' as html;

void preventBackToAdminSession() {
  html.window.history.pushState(null, '', html.window.location.href);
}
