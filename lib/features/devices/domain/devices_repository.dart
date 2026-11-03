import 'device.dart';

/// One telemetry message from a gateway, already decoded.
class TelemetryEvent {
  const TelemetryEvent({required this.deviceId, required this.ts, required this.values});

  final String deviceId;
  final DateTime ts;
  final Map<String, double> values;
}

class GatewayStatusEvent {
  const GatewayStatusEvent(this.deviceId, this.status);

  final String deviceId;
  final DeviceStatus status;
}

abstract interface class TempNodeRepository {
  Future<List<Device>> fetchDevices();
  Future<List<Reading>> fetchReadings(String deviceId, {required DateTime since});
}

abstract interface class GatewayTelemetrySource {
  Stream<TelemetryEvent> get telemetry;
  Stream<GatewayStatusEvent> get statuses;
  Future<void> connect();
  Future<void> dispose();
}
