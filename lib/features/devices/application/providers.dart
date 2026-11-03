import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/notifications/notification_service.dart';
import '../data/mqtt_gateway_source.dart';
import '../data/rest_temp_node_repository.dart';
import '../domain/alert_monitor.dart';
import '../domain/device.dart';
import '../domain/devices_repository.dart';

// --- Infrastructure (overridden in main() and in tests) ----------------------

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPreferencesProvider in main()'),
);

final notificationServiceProvider = Provider<NotificationService>((ref) => LocalNotificationService());

const tempNodeRefreshInterval = Duration(seconds: 30);
const gatewaySeriesLength = 300;

// --- Configuration -----------------------------------------------------------

class ConfigNotifier extends Notifier<AppConfig> {
  late final ConfigStore _store = ConfigStore(ref.read(sharedPreferencesProvider));

  @override
  AppConfig build() => _store.load();

  Future<void> save(AppConfig config) async {
    await _store.save(config);
    state = config;
  }
}

final configProvider = NotifierProvider<ConfigNotifier, AppConfig>(ConfigNotifier.new);

// --- Data sources ------------------------------------------------------------

final tempNodeRepositoryProvider = Provider<TempNodeRepository>((ref) {
  final baseUrl = ref.watch(configProvider.select((c) => c.apiBaseUrl));
  return RestTempNodeRepository(baseUrl: baseUrl);
});

/// Null when MQTT is not configured. Rebuilt (and reconnected) when settings change.
final gatewaySourceProvider = Provider<GatewayTelemetrySource?>((ref) {
  final c = ref.watch(configProvider);
  if (!c.mqttEnabled) return null;
  final source = MqttGatewaySource(
    host: c.mqttHost,
    port: c.mqttPort,
    baseTopic: c.baseTopic,
    username: c.mqttUsername,
    password: c.mqttPassword,
  );
  ref.onDispose(source.dispose);
  return source;
});

// --- Temperature nodes (REST, polled) ---------------------------------------

class TempNodesNotifier extends AsyncNotifier<List<Device>> {
  @override
  Future<List<Device>> build() async {
    final timer = Timer(tempNodeRefreshInterval, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
    return ref.watch(tempNodeRepositoryProvider).fetchDevices();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final tempNodesProvider = AsyncNotifierProvider<TempNodesNotifier, List<Device>>(TempNodesNotifier.new);

/// Last 24 h of a temperature node, refreshed with the device list.
final tempNodeSeriesProvider = FutureProvider.family<List<Reading>, String>((ref, id) {
  ref.watch(tempNodesProvider); // re-fetch whenever the list refreshes
  return ref
      .watch(tempNodeRepositoryProvider)
      .fetchReadings(id, since: DateTime.now().subtract(const Duration(hours: 24)));
});

// --- Gateways (MQTT, live) --------------------------------------------------

class GatewayView {
  const GatewayView(this.device, this.series);

  final Device device;
  final List<Reading> series;
}

class GatewaysNotifier extends Notifier<Map<String, GatewayView>> {
  @override
  Map<String, GatewayView> build() {
    final source = ref.watch(gatewaySourceProvider);
    final config = ref.watch(configProvider);
    if (source == null) return const {};

    final subs = [source.telemetry.listen((e) => _onTelemetry(e, config)), source.statuses.listen(_onStatus)];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
    });
    unawaited(
      source.connect().catchError((Object _) {
        // Broker unreachable: the list simply shows no gateways. autoReconnect
        // only applies after a first successful connection.
      }),
    );
    return const {};
  }

  Device _blank(String id, AppConfig config) => Device(
    id: id,
    source: DeviceSource.modbusGateway,
    status: DeviceStatus.unknown,
    unit: _unitFor(config.gatewayMetric),
    alertMax: config.gatewayAlertMax,
  );

  void _onTelemetry(TelemetryEvent e, AppConfig config) {
    final current = state[e.deviceId];
    final device = (current?.device ?? _blank(e.deviceId, config)).copyWith(
      status: DeviceStatus.ok,
      primaryValue: e.values[config.gatewayMetric],
      lastSeen: e.ts,
      metrics: e.values,
    );
    final value = e.values[config.gatewayMetric];
    final series = [...?current?.series, if (value != null) Reading(e.ts, value)];
    final trimmed = series.length > gatewaySeriesLength
        ? series.sublist(series.length - gatewaySeriesLength)
        : series;
    state = {...state, e.deviceId: GatewayView(device, trimmed)};
  }

  void _onStatus(GatewayStatusEvent e) {
    final config = ref.read(configProvider);
    final current = state[e.deviceId];
    final device = (current?.device ?? _blank(e.deviceId, config)).copyWith(status: e.status);
    state = {...state, e.deviceId: GatewayView(device, current?.series ?? const [])};
  }

  static String _unitFor(String metric) => switch (metric) {
    'voltage' => 'V',
    'current' => 'A',
    'active_power' => 'W',
    'apparent_power' => 'VA',
    'reactive_power' => 'var',
    'frequency' => 'Hz',
    'import_energy' || 'export_energy' => 'kWh',
    _ => '',
  };
}

final gatewaysProvider = NotifierProvider<GatewaysNotifier, Map<String, GatewayView>>(GatewaysNotifier.new);

// --- Combined view + alerts --------------------------------------------------

/// Every device, problems first, then by name.
final allDevicesProvider = Provider<AsyncValue<List<Device>>>((ref) {
  final nodes = ref.watch(tempNodesProvider);
  final gateways = ref.watch(gatewaysProvider).values.map((g) => g.device).toList();

  int rank(Device d) => switch (d.status) {
    DeviceStatus.alert => 0,
    DeviceStatus.offline || DeviceStatus.stale => 1,
    _ => d.isOutOfRange ? 0 : 2,
  };

  List<Device> merge(List<Device> list) => [...list, ...gateways]
    ..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.displayName.compareTo(b.displayName);
    });

  // `value` keeps the previous list while a periodic refresh is in flight, so
  // the screen does not flash a spinner every 30 s.
  final list = nodes.value;
  if (list != null) return AsyncData(merge(list));
  if (nodes.hasError) {
    // A REST failure must not hide live gateways.
    return gateways.isNotEmpty
        ? AsyncData(merge(const []))
        : AsyncError(nodes.error!, nodes.stackTrace ?? StackTrace.current);
  }
  return const AsyncLoading();
});

/// Watch this once at the app root: raises a notification on every alert transition.
final alertWatcherProvider = Provider<AlertMonitor>((ref) {
  final monitor = AlertMonitor();
  final notifications = ref.read(notificationServiceProvider);
  ref.listen(allDevicesProvider, (_, next) {
    if (next case AsyncData(:final value)) {
      for (final event in monitor.update(value)) {
        notifications.show(event.device.id.hashCode & 0x7fffffff, event.title, event.body);
      }
    }
  }, fireImmediately: true);
  return monitor;
});
