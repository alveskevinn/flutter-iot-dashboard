// End-to-end run against a live temp-node API (see README "Demo without hardware").
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart \
//     --dart-define=API_URL=http://localhost:3000/api/v1
//
// The test prints `SCREENSHOT:<name>` and holds the frame for a few seconds,
// so a host script can capture it (`xcrun simctl io booted screenshot`,
// `adb exec-out screencap`). binding.takeScreenshot() returns a blank image on
// iOS with Impeller, hence this approach.
import 'package:flutter/material.dart';
import 'package:flutter_iot_dashboard/app.dart';
import 'package:flutter_iot_dashboard/core/notifications/notification_service.dart';
import 'package:flutter_iot_dashboard/features/devices/application/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SilentNotifications implements NotificationService {
  final titles = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> show(int id, String title, String body) async => titles.add(title);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> hold(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    debugPrint('SCREENSHOT:$name');
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 8)));
    await tester.pump();
  }

  testWidgets('lists devices from the API and opens a 24 h chart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifications = SilentNotifications();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: const IotDashboardApp(),
      ),
    );

    // Wait for the first REST response.
    for (var i = 0; i < 50 && find.byType(Card).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(Card), findsWidgets);
    await tester.pump(const Duration(milliseconds: 500));
    await hold(tester, 'devices');

    await tester.tap(find.text('Vaccine fridge'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Last 24 hours'), findsOneWidget);
    await hold(tester, 'detail');
  });
}
