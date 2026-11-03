import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../devices/application/providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _form = GlobalKey<FormState>();
  late final AppConfig _initial = ref.read(configProvider);
  late final _api = TextEditingController(text: _initial.apiBaseUrl);
  late final _host = TextEditingController(text: _initial.mqttHost);
  late final _port = TextEditingController(text: '${_initial.mqttPort}');
  late final _user = TextEditingController(text: _initial.mqttUsername);
  late final _pass = TextEditingController(text: _initial.mqttPassword);
  late final _topic = TextEditingController(text: _initial.baseTopic);
  late final _metric = TextEditingController(text: _initial.gatewayMetric);
  late final _alertMax = TextEditingController(text: _initial.gatewayAlertMax?.toString() ?? '');

  @override
  void dispose() {
    for (final c in [_api, _host, _port, _user, _pass, _topic, _metric, _alertMax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final alertMax = double.tryParse(_alertMax.text.trim());
    await ref
        .read(configProvider.notifier)
        .save(
          _initial.copyWith(
            apiBaseUrl: _api.text.trim(),
            mqttHost: _host.text.trim(),
            mqttPort: int.parse(_port.text.trim()),
            mqttUsername: _user.text.trim(),
            mqttPassword: _pass.text,
            baseTopic: _topic.text.trim(),
            gatewayMetric: _metric.text.trim(),
            gatewayAlertMax: () => alertMax,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Widget field(
      TextEditingController c,
      String label, {
      String? hint,
      bool obscure = false,
      TextInputType? type,
      FormFieldValidator<String>? validator,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: type,
        validator: validator,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Temperature nodes (REST)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            field(
              _api,
              'API base URL',
              hint: 'https://iot.example.com/api/v1',
              type: TextInputType.url,
              validator: (v) => Uri.tryParse(v ?? '')?.hasScheme == true ? null : 'Enter a full URL',
            ),
            const SizedBox(height: 8),
            Text('Modbus gateways (MQTT)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            field(_host, 'Broker host', hint: 'empty = disabled'),
            field(
              _port,
              'Port',
              type: TextInputType.number,
              validator: (v) {
                final p = int.tryParse(v ?? '');
                return p != null && p > 0 && p < 65536 ? null : '1–65535';
              },
            ),
            field(_user, 'Username'),
            field(_pass, 'Password', obscure: true),
            field(_topic, 'Base topic'),
            field(_metric, 'Metric to chart', hint: 'active_power, voltage, …'),
            field(
              _alertMax,
              'Alert above (optional)',
              type: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  (v == null || v.trim().isEmpty || double.tryParse(v.trim()) != null) ? null : 'Number',
            ),
          ],
        ),
      ),
    );
  }
}
