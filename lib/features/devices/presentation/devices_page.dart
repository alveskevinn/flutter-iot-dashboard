import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_page.dart';
import '../application/providers.dart';
import 'device_detail_page.dart';
import 'widgets/device_tile.dart';

class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(allDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(tempNodesProvider.notifier).refresh(),
        child: switch (devices) {
          AsyncData(:final value) when value.isEmpty => const _Message(
            icon: Icons.sensors_off,
            text: 'No devices yet.\nCheck the API URL and MQTT broker in Settings.',
          ),
          AsyncData(:final value) => ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: value.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, i) => DeviceTile(
              device: value[i],
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => DeviceDetailPage(deviceId: value[i].id))),
            ),
          ),
          AsyncError(:final error) => _Message(
            icon: Icons.cloud_off,
            text: 'Could not reach the API.\n$error',
            action: FilledButton(
              onPressed: () => ref.invalidate(tempNodesProvider),
              child: const Text('Retry'),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    // ListView so pull-to-refresh still works on the empty/error states.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 48, color: outline),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: outline),
        ),
        if (action != null) ...[const SizedBox(height: 16), Center(child: action)],
      ],
    );
  }
}
