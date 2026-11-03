import 'package:flutter_iot_dashboard/features/devices/data/mqtt_gateway_source.dart';
import 'package:flutter_iot_dashboard/features/devices/domain/device.dart';
import 'package:flutter_test/flutter_test.dart';

const base = 'devskin/gateways';

void main() {
  group('parseTelemetry', () {
    test('decodes the gateway payload', () {
      final e = parseTelemetry(
        base,
        '$base/mbgw-3a91f0/telemetry',
        '{"ts":1762190400,"slave":1,"ok":true,"values":{"voltage":229.84,"active_power":918}}',
      )!;
      expect(e.deviceId, 'mbgw-3a91f0');
      expect(e.ts, DateTime.utc(2025, 11, 3, 17, 20));
      expect(e.values, {'voltage': 229.84, 'active_power': 918.0});
    });

    test('falls back to the receive time before SNTP sync', () {
      final now = DateTime.utc(2026, 1, 1);
      final e = parseTelemetry(base, '$base/gw/telemetry', '{"values":{"voltage":230}}', now: now)!;
      expect(e.ts, now);
    });

    test('ignores non-numeric values, other topics and garbage', () {
      final e = parseTelemetry(base, '$base/gw/telemetry', '{"values":{"a":1,"b":"x","c":null}}')!;
      expect(e.values, {'a': 1.0});
      expect(parseTelemetry(base, '$base/gw/info', '{}'), isNull);
      expect(parseTelemetry(base, 'other/gw/telemetry', '{"values":{}}'), isNull);
      expect(parseTelemetry(base, '$base/a/b/telemetry', '{"values":{}}'), isNull);
      expect(parseTelemetry(base, '$base/gw/telemetry', 'not json'), isNull);
    });
  });

  group('parseGatewayStatus', () {
    test('maps the retained status / LWT payloads', () {
      expect(parseGatewayStatus(base, '$base/gw/status', 'online')!.status, DeviceStatus.ok);
      expect(parseGatewayStatus(base, '$base/gw/status', 'updating')!.status, DeviceStatus.ok);
      expect(parseGatewayStatus(base, '$base/gw/status', 'offline')!.status, DeviceStatus.offline);
      expect(parseGatewayStatus(base, '$base/gw/telemetry', 'online'), isNull);
    });
  });
}
