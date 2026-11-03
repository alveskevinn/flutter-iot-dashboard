import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/device.dart';
import 'widgets/device_tile.dart';
import 'widgets/series_chart.dart';
import 'widgets/status_badge.dart';

class DeviceDetailPage extends ConsumerWidget {
  const DeviceDetailPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allDevicesProvider).value ?? const <Device>[];
    final device = all.where((d) => d.id == deviceId).firstOrNull;

    if (device == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Device not found')),
      );
    }

    final theme = Theme.of(context);
    final series = switch (device.source) {
      DeviceSource.tempNode => ref.watch(tempNodeSeriesProvider(deviceId)),
      DeviceSource.modbusGateway => AsyncData(
        ref.watch(gatewaysProvider)[deviceId]?.series ?? const <Reading>[],
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(device.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatValue(device), style: theme.textTheme.displaySmall),
              const Spacer(),
              StatusBadge(device),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              device.source == DeviceSource.tempNode ? 'Temperature node' : 'Modbus gateway',
              'updated ${formatAgo(device.lastSeen)}',
              if (device.batteryPct != null) 'battery ${device.batteryPct}%',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),
          Text(
            device.source == DeviceSource.tempNode ? 'Last 24 hours' : 'Live',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          switch (series) {
            AsyncError(:final error) => Text('Could not load readings: $error'),
            AsyncValue(:final value?) => SeriesChart(
              readings: value,
              min: device.alertMin,
              max: device.alertMax,
              unit: device.unit,
            ),
            _ => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
          },
          if (device.alertMin != null || device.alertMax != null) ...[
            const SizedBox(height: 8),
            Text(
              'Alert range: ${device.alertMin ?? '–'} … ${device.alertMax ?? '–'} ${device.unit}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (device.metrics.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Latest values', style: theme.textTheme.titleSmall),
            Card(
              child: Column(
                children: [
                  for (final e in device.metrics.entries)
                    ListTile(
                      dense: true,
                      title: Text(e.key.replaceAll('_', ' ')),
                      trailing: Text(e.value.toStringAsFixed(2), style: theme.textTheme.bodyLarge),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
