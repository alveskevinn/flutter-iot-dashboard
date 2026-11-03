import 'package:flutter/material.dart';

import '../../domain/device.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.device, {super.key});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final (label, color) = statusStyle(device);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.6),
      ),
    );
  }
}

(String, Color) statusStyle(Device d) {
  if (d.status == DeviceStatus.alert || (d.status == DeviceStatus.ok && d.isOutOfRange)) {
    return ('ALERT', const Color(0xFFF85149));
  }
  return switch (d.status) {
    DeviceStatus.ok => ('OK', const Color(0xFF3FB950)),
    DeviceStatus.stale => ('STALE', const Color(0xFFD29922)),
    DeviceStatus.offline => ('OFFLINE', const Color(0xFF8A93A6)),
    _ => ('UNKNOWN', const Color(0xFF8A93A6)),
  };
}
