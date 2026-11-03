/// Where a device's data comes from.
enum DeviceSource {
  /// Battery temperature node, read over the REST API of esp32-temp-sensor-node.
  tempNode,

  /// Modbus RTU → MQTT gateway (esp32-modbus-mqtt-gateway), streamed live.
  modbusGateway,
}

enum DeviceStatus { ok, alert, stale, offline, unknown }

DeviceStatus parseStatus(String? value) => switch (value) {
  'ok' || 'online' => DeviceStatus.ok,
  'alert' => DeviceStatus.alert,
  'stale' => DeviceStatus.stale,
  'offline' => DeviceStatus.offline,
  _ => DeviceStatus.unknown,
};

class Device {
  const Device({
    required this.id,
    required this.source,
    required this.status,
    this.name,
    this.primaryValue,
    this.unit = '',
    this.batteryPct,
    this.lastSeen,
    this.alertMin,
    this.alertMax,
    this.metrics = const {},
  });

  final String id;
  final String? name;
  final DeviceSource source;
  final DeviceStatus status;

  /// Headline value shown in the list (temperature, active power, ...).
  final double? primaryValue;
  final String unit;
  final int? batteryPct;
  final DateTime? lastSeen;
  final double? alertMin;
  final double? alertMax;

  /// Every value of the latest telemetry message (gateways only).
  final Map<String, double> metrics;

  String get displayName => (name == null || name!.isEmpty) ? id : name!;

  bool get isOutOfRange {
    final v = primaryValue;
    if (v == null) return false;
    return (alertMin != null && v < alertMin!) || (alertMax != null && v > alertMax!);
  }

  Device copyWith({
    DeviceStatus? status,
    double? primaryValue,
    DateTime? lastSeen,
    Map<String, double>? metrics,
  }) => Device(
    id: id,
    name: name,
    source: source,
    status: status ?? this.status,
    primaryValue: primaryValue ?? this.primaryValue,
    unit: unit,
    batteryPct: batteryPct,
    lastSeen: lastSeen ?? this.lastSeen,
    alertMin: alertMin,
    alertMax: alertMax,
    metrics: metrics ?? this.metrics,
  );

  /// Maps a device from `GET /api/v1/devices`.
  factory Device.fromTempNodeJson(Map<String, dynamic> j) => Device(
    id: j['id'] as String,
    name: j['name'] as String?,
    source: DeviceSource.tempNode,
    status: parseStatus(j['status'] as String?),
    primaryValue: (j['last_temp'] as num?)?.toDouble(),
    unit: '°C',
    batteryPct: (j['battery_pct'] as num?)?.toInt(),
    lastSeen: j['last_seen'] == null ? null : DateTime.parse(j['last_seen'] as String),
    alertMin: (j['alert_min'] as num?)?.toDouble(),
    alertMax: (j['alert_max'] as num?)?.toDouble(),
  );
}

class Reading {
  const Reading(this.ts, this.value);

  final DateTime ts;
  final double value;

  factory Reading.fromJson(Map<String, dynamic> j) =>
      Reading(DateTime.parse(j['ts'] as String), (j['t'] as num).toDouble());
}
