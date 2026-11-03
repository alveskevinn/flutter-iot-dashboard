import 'package:flutter/material.dart';

import '../../domain/device.dart';
import 'status_badge.dart';

String formatAgo(DateTime? t, {DateTime? now}) {
  if (t == null) return 'never';
  final s = (now ?? DateTime.now()).difference(t).inSeconds;
  if (s < 90) return '${s < 0 ? 0 : s}s ago';
  if (s < 5400) return '${(s / 60).round()} min ago';
  if (s < 172800) return '${(s / 3600).round()} h ago';
  return '${(s / 86400).round()} d ago';
}

String formatValue(Device d) {
  final v = d.primaryValue;
  if (v == null) return '—';
  final digits = v.abs() >= 100 ? 0 : 1;
  return '${v.toStringAsFixed(digits)} ${d.unit}'.trim();
}

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, required this.onTap});

  final Device device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    final icon = device.source == DeviceSource.tempNode ? Icons.thermostat : Icons.electric_meter;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.displayName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (device.batteryPct != null) '🔋 ${device.batteryPct}%',
                        formatAgo(device.lastSeen),
                      ].join(' · '),
                      style: muted,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatValue(device), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  StatusBadge(device),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
