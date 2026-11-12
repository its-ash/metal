import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'platform/device_channel.dart';
import 'screens/home_screen.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  runApp(MetalApp(settings: settings, device: const DeviceChannel()));
}

class MetalApp extends StatelessWidget {
  const MetalApp({super.key, required this.settings, required this.device});

  final SettingsStore settings;
  final Device device;

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'Metal',
      home: HomeScreen(device: device, settings: settings),
    );
  }
}
