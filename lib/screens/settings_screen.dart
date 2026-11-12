import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../settings/settings_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return UiScaffold(
      appBar: const UiAppBar(title: 'Settings', back: true),
      scrollable: true,
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiListGroup(
              header: 'Feedback',
              children: [
                UiSwitchTile(
                  'Sound',
                  icon: Icons.volume_up_rounded,
                  value: settings.sound,
                  onChanged: settings.setSound,
                ),
                UiSwitchTile(
                  'Vibration',
                  icon: Icons.vibration_rounded,
                  value: settings.vibration,
                  onChanged: settings.setVibration,
                ),
                UiSwitchTile(
                  'Auto re-zero',
                  subtitle: 'Slowly follows small changes in the background field',
                  icon: Icons.autorenew_rounded,
                  value: settings.autoRezero,
                  onChanged: settings.setAutoRezero,
                ),
              ],
            ),
            const UiGap(UiSpace.lg),
            const UiListGroup(
              header: 'Privacy',
              children: [
                UiListTile(
                  'Everything stays on this phone',
                  subtitle: 'Metal reads the magnetic field sensor only. '
                      'It uses the internet only to check for app updates.',
                  icon: Icons.lock_rounded,
                  iconStatus: UiStatus.success,
                ),
              ],
            ),
            const UiGap(UiSpace.lg),
            const UiAppearanceSection(),
            const UiGap(UiSpace.lg),
            const UiUpdateSection(storeId: 'metal'),
            const UiGap(UiSpace.lg),
            const UiDeveloperSection(),
          ],
        ),
      ),
    );
  }
}
