import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/devices/application/providers.dart';
import 'features/devices/presentation/devices_page.dart';

class IotDashboardApp extends ConsumerWidget {
  const IotDashboardApp({super.key});

  static const _seed = Color(0xFF58A6FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(alertWatcherProvider); // keeps alert notifications running app-wide

    return MaterialApp(
      title: 'IoT Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark, useMaterial3: true),
      home: const DevicesPage(),
    );
  }
}
