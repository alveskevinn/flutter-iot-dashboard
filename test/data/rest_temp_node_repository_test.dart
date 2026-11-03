import 'dart:convert';

import 'package:flutter_iot_dashboard/features/devices/data/rest_temp_node_repository.dart';
import 'package:flutter_iot_dashboard/features/devices/domain/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final requests = <Uri>[];

  RestTempNodeRepository repo(http.Response Function(Uri) handler) => RestTempNodeRepository(
    baseUrl: 'https://iot.example.com/api/v1/',
    client: MockClient((req) async {
      requests.add(req.url);
      return handler(req.url);
    }),
  );

  setUp(requests.clear);

  test('maps GET /devices', () async {
    final r = repo(
      (_) => http.Response(
        jsonEncode([
          {
            'id': 'fridge-01',
            'name': 'Vaccines',
            'status': 'alert',
            'last_temp': 9.1,
            'battery_pct': 76,
            'last_seen': '2026-11-03T12:00:00.000Z',
            'alert_min': 2,
            'alert_max': 8,
          },
        ]),
        200,
      ),
    );
    final devices = await r.fetchDevices();
    expect(requests.single.toString(), 'https://iot.example.com/api/v1/devices');
    final d = devices.single;
    expect(d.displayName, 'Vaccines');
    expect(d.status, DeviceStatus.alert);
    expect(d.primaryValue, 9.1);
    expect(d.batteryPct, 76);
    expect(d.isOutOfRange, isTrue);
    expect(d.lastSeen, DateTime.utc(2026, 11, 3, 12));
  });

  test('requests readings since a point in time', () async {
    final r = repo(
      (_) => http.Response(
        jsonEncode([
          {'ts': '2026-11-03T11:55:00.000Z', 't': 4.5},
          {'ts': '2026-11-03T12:00:00.000Z', 't': 4.75},
        ]),
        200,
      ),
    );
    final rows = await r.fetchReadings('fridge 01', since: DateTime.utc(2026, 11, 2, 12));
    expect(requests.single.path, '/api/v1/devices/fridge%2001/readings');
    expect(requests.single.queryParameters['from'], '2026-11-02T12:00:00.000Z');
    expect(rows.map((e) => e.value), [4.5, 4.75]);
  });

  test('throws ApiException on HTTP errors', () async {
    final r = repo((_) => http.Response('{"error":"not_found"}', 404));
    expect(r.fetchDevices(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
  });
}
