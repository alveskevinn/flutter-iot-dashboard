import 'package:flutter_iot_dashboard/features/devices/domain/alert_monitor.dart';
import 'package:flutter_iot_dashboard/features/devices/domain/device.dart';
import 'package:flutter_test/flutter_test.dart';

Device fridge(double temp, {DeviceStatus status = DeviceStatus.ok}) => Device(
  id: 'fridge-01',
  name: 'Vaccine fridge',
  source: DeviceSource.tempNode,
  status: status,
  primaryValue: temp,
  unit: '°C',
  alertMin: 2,
  alertMax: 8,
);

void main() {
  late AlertMonitor monitor;
  setUp(() => monitor = AlertMonitor());

  test('a healthy device on first sight raises nothing', () {
    expect(monitor.update([fridge(5)]), isEmpty);
  });

  test('a device already in alert on first sight is reported once', () {
    final events = monitor.update([fridge(9.4)]);
    expect(events.single.kind, AlertKind.outOfRange);
    expect(monitor.update([fridge(9.6)]), isEmpty, reason: 'still in alert: no repeat');
  });

  test('transitions produce out-of-range, then recovered', () {
    monitor.update([fridge(5)]);
    expect(monitor.update([fridge(1.5)]).single.kind, AlertKind.outOfRange);
    final recovered = monitor.update([fridge(4)]).single;
    expect(recovered.kind, AlertKind.recovered);
    expect(recovered.title, 'Vaccine fridge back to normal');
  });

  test('stale and offline devices are reported as not reporting', () {
    monitor.update([fridge(5)]);
    final e = monitor.update([fridge(5, status: DeviceStatus.stale)]).single;
    expect(e.kind, AlertKind.offline);
    expect(e.title, contains('not reporting'));
  });

  test('server-side alert status is honoured even without limits', () {
    const d = Device(id: 'x', source: DeviceSource.tempNode, status: DeviceStatus.alert);
    expect(monitor.update([d]).single.kind, AlertKind.outOfRange);
  });

  test('alert body shows the value and the allowed range', () {
    final e = monitor.update([fridge(9.42)]).single;
    expect(e.body, '9.4 °C (allowed 2.0…8.0 °C)');
  });
}
