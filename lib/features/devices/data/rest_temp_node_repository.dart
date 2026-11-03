import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/device.dart';
import '../domain/devices_repository.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// REST client for the esp32-temp-sensor-node API (`/api/v1`).
class RestTempNodeRepository implements TempNodeRepository {
  RestTempNodeRepository({required String baseUrl, http.Client? client})
    : _base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      _client = client ?? http.Client();

  final String _base;
  final http.Client _client;
  static const _timeout = Duration(seconds: 10);

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final res = await _client.get(uri, headers: {'accept': 'application/json'}).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body);
  }

  @override
  Future<List<Device>> fetchDevices() async {
    final list = await _get('/devices') as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(Device.fromTempNodeJson).toList();
  }

  @override
  Future<List<Reading>> fetchReadings(String deviceId, {required DateTime since}) async {
    final list = await _get('/devices/${Uri.encodeComponent(deviceId)}/readings', {
      'from': since.toUtc().toIso8601String(),
      'limit': '2000',
    }) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(Reading.fromJson).toList();
  }
}
