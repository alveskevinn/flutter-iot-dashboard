import 'package:flutter/material.dart';
import 'package:flutter_iot_dashboard/app.dart';
import 'package:flutter_iot_dashboard/core/notifications/notification_service.dart';
import 'package:flutter_iot_dashboard/features/devices/application/providers.dart';
import 'package:flutter_iot_dashboard/features/devices/domain/device.dart';
import 'package:flutter_iot_dashboard/features/devices/domain/devices_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRepository implements TempNodeRepository {
  FakeRepository(this.devices, {this.fail = false});

  final List<Device> devices;
  final bool fail;

  @override
  Future<List<Device>> fetchDevices() async {
    if (fail) throw Exception('connection refused');
    return devices;
  }

  @override
  Future<List<Reading>> fetchReadings(String deviceId, {required DateTime since}) async => [
    for (var i = 0; i < 12; i++) Reading(DateTime.utc(2026, 11, 3, 10, i * 5), 4 + i / 10),
  ];
}

class RecordingNotifications implements NotificationService {
  final shown = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> show(int id, String title, String body) async => shown.add(title);
}

Device node(String id, double t, {DeviceStatus status = DeviceStatus.ok}) => Device(
  id: id,
  source: DeviceSource.tempNode,
  status: status,
  primaryValue: t,
  unit: '°C',
  batteryPct: 80,
  lastSeen: DateTime.now(),
  alertMin: 2,
  alertMax: 8,
);

Future<RecordingNotifications> pumpApp(WidgetTester tester, TempNodeRepository repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final notifications = RecordingNotifications();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notifications),
        tempNodeRepositoryProvider.overrideWithValue(repo),
      ],
      child: const IotDashboardApp(),
    ),
  );
  await tester.pump(); // resolve the first fetch
  return notifications;
}

void main() {
  testWidgets('lists devices with alerts first and notifies once', (tester) async {
    final notifications = await pumpApp(
      tester,
      FakeRepository([node('cold-room', 3.1), node('fridge-lab', 9.3, status: DeviceStatus.alert)]),
    );

    expect(find.text('cold-room'), findsOneWidget);
    expect(find.text('9.3 °C'), findsOneWidget);
    expect(find.text('ALERT'), findsOneWidget);

    final top = tester.getTopLeft(find.text('fridge-lab')).dy;
    expect(top, lessThan(tester.getTopLeft(find.text('cold-room')).dy));
    expect(notifications.shown, ['fridge-lab out of range']);
  });

  testWidgets('opens the device detail with its chart', (tester) async {
    await pumpApp(tester, FakeRepository([node('cold-room', 3.1)]));
    await tester.tap(find.text('cold-room'));
    await tester.pumpAndSettle();
    expect(find.text('Last 24 hours'), findsOneWidget);
    expect(find.text('Alert range: 2.0 … 8.0 °C'), findsOneWidget);
  });

  testWidgets('shows a retry action when the API is unreachable', (tester) async {
    await pumpApp(tester, FakeRepository(const [], fail: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Could not reach the API'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });
}
