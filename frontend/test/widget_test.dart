// Personal Care 앱 위젯 스모크 테스트
// 앱이 정상적으로 빌드되고 첫 화면 요소가 보이는지 확인

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/login_form_provider.dart';

void main() {
  testWidgets('App starts and shows initial content', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const PersonalCareApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Personal Care'), findsOneWidget);
  });
}
