import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig({
    String? apiBaseUrl,
    this.mqttHost = '',
    this.mqttPort = 1883,
    this.mqttUsername = '',
    this.mqttPassword = '',
    this.baseTopic = 'devskin/gateways',
    this.gatewayMetric = 'active_power',
    this.gatewayAlertMax,
  }) : apiBaseUrl = apiBaseUrl ?? defaultApiBaseUrl;

  /// `--dart-define=API_URL=https://…/api/v1` wins. Otherwise points at a
  /// backend on the development machine: Android emulators reach the host at
  /// 10.0.2.2, the iOS simulator at localhost.
  static String get defaultApiBaseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:3000/api/v1';
  }

  final String apiBaseUrl;

  /// Empty disables the MQTT connection (REST-only).
  final String mqttHost;
  final int mqttPort;
  final String mqttUsername;
  final String mqttPassword;
  final String baseTopic;

  /// Gateway value shown in the list and charted live.
  final String gatewayMetric;

  /// Optional upper limit for [gatewayMetric] that raises an alert.
  final double? gatewayAlertMax;

  bool get mqttEnabled => mqttHost.trim().isNotEmpty;

  AppConfig copyWith({
    String? apiBaseUrl,
    String? mqttHost,
    int? mqttPort,
    String? mqttUsername,
    String? mqttPassword,
    String? baseTopic,
    String? gatewayMetric,
    double? Function()? gatewayAlertMax,
  }) => AppConfig(
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    mqttHost: mqttHost ?? this.mqttHost,
    mqttPort: mqttPort ?? this.mqttPort,
    mqttUsername: mqttUsername ?? this.mqttUsername,
    mqttPassword: mqttPassword ?? this.mqttPassword,
    baseTopic: baseTopic ?? this.baseTopic,
    gatewayMetric: gatewayMetric ?? this.gatewayMetric,
    gatewayAlertMax: gatewayAlertMax != null ? gatewayAlertMax() : this.gatewayAlertMax,
  );
}

/// Persists [AppConfig] in SharedPreferences.
class ConfigStore {
  ConfigStore(this._prefs);

  final SharedPreferences _prefs;
  static const _p = 'config.';

  AppConfig load() {
    final d = AppConfig();
    return AppConfig(
      apiBaseUrl: _prefs.getString('${_p}api') ?? d.apiBaseUrl,
      mqttHost: _prefs.getString('${_p}mqttHost') ?? d.mqttHost,
      mqttPort: _prefs.getInt('${_p}mqttPort') ?? d.mqttPort,
      mqttUsername: _prefs.getString('${_p}mqttUser') ?? d.mqttUsername,
      mqttPassword: _prefs.getString('${_p}mqttPass') ?? d.mqttPassword,
      baseTopic: _prefs.getString('${_p}topic') ?? d.baseTopic,
      gatewayMetric: _prefs.getString('${_p}metric') ?? d.gatewayMetric,
      gatewayAlertMax: _prefs.getDouble('${_p}alertMax'),
    );
  }

  Future<void> save(AppConfig c) async {
    await _prefs.setString('${_p}api', c.apiBaseUrl);
    await _prefs.setString('${_p}mqttHost', c.mqttHost);
    await _prefs.setInt('${_p}mqttPort', c.mqttPort);
    await _prefs.setString('${_p}mqttUser', c.mqttUsername);
    await _prefs.setString('${_p}mqttPass', c.mqttPassword);
    await _prefs.setString('${_p}topic', c.baseTopic);
    await _prefs.setString('${_p}metric', c.gatewayMetric);
    if (c.gatewayAlertMax == null) {
      await _prefs.remove('${_p}alertMax');
    } else {
      await _prefs.setDouble('${_p}alertMax', c.gatewayAlertMax!);
    }
  }
}
