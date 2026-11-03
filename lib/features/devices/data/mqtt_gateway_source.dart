import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../domain/device.dart';
import '../domain/devices_repository.dart';

/// Parses `<base>/<id>/telemetry` payloads published by esp32-modbus-mqtt-gateway.
/// Returns null for topics or payloads that are not gateway telemetry.
TelemetryEvent? parseTelemetry(String baseTopic, String topic, String payload, {DateTime? now}) {
  final id = _deviceIdFor(baseTopic, topic, 'telemetry');
  if (id == null) return null;
  try {
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) return null;
    final raw = json['values'];
    if (raw is! Map<String, dynamic>) return null;
    final values = <String, double>{
      for (final e in raw.entries)
        if (e.value is num) e.key: (e.value as num).toDouble(),
    };
    final ts = json['ts'] is int
        ? DateTime.fromMillisecondsSinceEpoch((json['ts'] as int) * 1000, isUtc: true)
        : (now ?? DateTime.now()).toUtc();
    return TelemetryEvent(deviceId: id, ts: ts, values: values);
  } on FormatException {
    return null;
  }
}

/// Parses the retained `<base>/<id>/status` topic (`online` / `offline` / `updating`).
GatewayStatusEvent? parseGatewayStatus(String baseTopic, String topic, String payload) {
  final id = _deviceIdFor(baseTopic, topic, 'status');
  if (id == null) return null;
  return GatewayStatusEvent(id, switch (payload.trim()) {
    'online' || 'updating' => DeviceStatus.ok,
    'offline' => DeviceStatus.offline,
    _ => DeviceStatus.unknown,
  });
}

String? _deviceIdFor(String baseTopic, String topic, String leaf) {
  final prefix = baseTopic.endsWith('/') ? baseTopic : '$baseTopic/';
  if (!topic.startsWith(prefix) || !topic.endsWith('/$leaf')) return null;
  final id = topic.substring(prefix.length, topic.length - leaf.length - 1);
  return id.isEmpty || id.contains('/') ? null : id;
}

/// Live gateway data over MQTT, with automatic reconnect.
class MqttGatewaySource implements GatewayTelemetrySource {
  MqttGatewaySource({
    required this.host,
    required this.port,
    required this.baseTopic,
    this.username,
    this.password,
  });

  final String host;
  final int port;
  final String baseTopic;
  final String? username;
  final String? password;

  final _telemetry = StreamController<TelemetryEvent>.broadcast();
  final _statuses = StreamController<GatewayStatusEvent>.broadcast();
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _sub;

  @override
  Stream<TelemetryEvent> get telemetry => _telemetry.stream;

  @override
  Stream<GatewayStatusEvent> get statuses => _statuses.stream;

  @override
  Future<void> connect() async {
    final clientId = 'iot-dashboard-${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient.withPort(host, clientId, port)
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false);
    client.connectionMessage = MqttConnectMessage().withClientIdentifier(clientId).startClean();
    _client = client;

    await client.connect(
      (username?.isEmpty ?? true) ? null : username,
      (password?.isEmpty ?? true) ? null : password,
    );
    client.subscribe('$baseTopic/+/telemetry', MqttQos.atMostOnce);
    client.subscribe('$baseTopic/+/status', MqttQos.atLeastOnce);

    _sub = client.updates?.listen((messages) {
      for (final m in messages) {
        final msg = m.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
        final t = parseTelemetry(baseTopic, m.topic, payload);
        if (t != null) {
          _telemetry.add(t);
          continue;
        }
        final s = parseGatewayStatus(baseTopic, m.topic, payload);
        if (s != null) _statuses.add(s);
      }
    });
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _client?.disconnect();
    await _telemetry.close();
    await _statuses.close();
  }
}
