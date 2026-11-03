import 'device.dart';

enum AlertKind { outOfRange, offline, recovered }

class AlertEvent {
  const AlertEvent(this.device, this.kind);

  final Device device;
  final AlertKind kind;

  String get title => switch (kind) {
    AlertKind.outOfRange => '${device.displayName} out of range',
    AlertKind.offline => '${device.displayName} is not reporting',
    AlertKind.recovered => '${device.displayName} back to normal',
  };

  String get body {
    final v = device.primaryValue;
    final value = v == null ? '' : '${v.toStringAsFixed(1)} ${device.unit}';
    return switch (kind) {
      AlertKind.outOfRange =>
        '$value (allowed ${device.alertMin ?? '–'}…${device.alertMax ?? '–'} ${device.unit})',
      AlertKind.offline => 'Last seen ${device.lastSeen?.toLocal() ?? 'never'}',
      AlertKind.recovered => value,
    };
  }
}

/// Turns successive device snapshots into alert *transitions*.
///
/// A device that stays in alert produces exactly one notification, not one per
/// refresh; a device that recovers produces a single "back to normal".
class AlertMonitor {
  final Map<String, _State> _last = {};

  List<AlertEvent> update(Iterable<Device> devices) {
    final events = <AlertEvent>[];
    for (final d in devices) {
      final now = _classify(d);
      final before = _last[d.id];
      _last[d.id] = now;
      if (before == null) {
        // First sighting: report problems, but never "recovered".
        if (now != _State.normal) events.add(AlertEvent(d, _kindFor(now)));
        continue;
      }
      if (now == before) continue;
      events.add(AlertEvent(d, now == _State.normal ? AlertKind.recovered : _kindFor(now)));
    }
    return events;
  }

  static _State _classify(Device d) {
    if (d.status == DeviceStatus.offline || d.status == DeviceStatus.stale) {
      return _State.silent;
    }
    if (d.status == DeviceStatus.alert || d.isOutOfRange) return _State.outOfRange;
    return _State.normal;
  }

  static AlertKind _kindFor(_State s) => s == _State.silent ? AlertKind.offline : AlertKind.outOfRange;
}

enum _State { normal, outOfRange, silent }
