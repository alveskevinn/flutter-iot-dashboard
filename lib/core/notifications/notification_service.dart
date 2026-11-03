import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class NotificationService {
  Future<void> init();
  Future<void> show(int id, String title, String body);
}

/// Local notifications raised by the app while it is running.
///
/// Push from the server (FCM / APNs) is on the roadmap; local notifications
/// keep the alert path testable without a Firebase project.
class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationDetails(
    'device_alerts',
    'Device alerts',
    channelDescription: 'Out-of-range readings and devices that stopped reporting',
    importance: Importance.high,
    priority: Priority.high,
  );

  bool _permissionAsked = false;

  /// Registers the plugin without prompting: the permission dialog is shown
  /// only when the first alert actually fires, so the user sees why it is needed.
  @override
  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> _ensurePermission() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  Future<void> show(int id, String title, String body) async {
    await _ensurePermission();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
    );
  }
}
