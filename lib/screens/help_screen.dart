import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

/// What the detector can and cannot find, and how to use it.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UiScaffold(
      appBar: UiAppBar(title: 'Help', back: true),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiListGroup(
            header: 'What it detects',
            footer: 'Metal changes the magnetic field the phone measures. Only magnetic metal does this.',
            children: [
              UiListTile(
                'Detected',
                subtitle: 'Iron, steel, nickel and magnets: nails, screws, studs, pipes, rebar, tools, keys.',
                icon: Icons.check_circle_rounded,
                iconStatus: UiStatus.success,
                maxSubtitleLines: 5,
              ),
              UiListTile(
                'Not detected',
                subtitle: 'Aluminium, copper, brass, gold, silver, plastic, wood and stone. '
                    'Stainless steel is often not detected either.',
                icon: Icons.cancel_rounded,
                iconStatus: UiStatus.danger,
                maxSubtitleLines: 5,
              ),
            ],
          ),
          UiGap(UiSpace.lg),
          UiListGroup(
            header: 'How to use it',
            children: [
              UiListTile(
                '1. Zero',
                subtitle: 'Hold the phone still, away from metal, then tap Zero. '
                    'It averages the field for about 1.5 seconds.',
                icon: Icons.adjust_rounded,
                maxSubtitleLines: 5,
              ),
              UiListTile(
                '2. Sweep slowly',
                subtitle: 'The sensor is usually near the top of the phone. Move the top edge slowly '
                    'along the wall or floor, and keep the phone at the same angle.',
                icon: Icons.swipe_rounded,
                maxSubtitleLines: 5,
              ),
              UiListTile(
                '3. Follow the tone',
                subtitle: 'Higher pitch and faster beeps mean more metal nearby. '
                    'The strongest reading is closest to the metal.',
                icon: Icons.graphic_eq_rounded,
                maxSubtitleLines: 5,
              ),
              UiListTile(
                '4. Zero again',
                subtitle: 'Zero again when you move to a new room or the reading drifts. '
                    'Auto re-zero does this slowly for you.',
                icon: Icons.restart_alt_rounded,
                maxSubtitleLines: 5,
              ),
            ],
          ),
          UiGap(UiSpace.lg),
          UiListGroup(
            header: 'For best results',
            children: [
              UiListTile(
                'Remove magnets',
                subtitle: 'Magnetic phone cases, mounts and wallet clips disturb the sensor. Take them off.',
                icon: Icons.warning_amber_rounded,
                iconStatus: UiStatus.warning,
                maxSubtitleLines: 5,
              ),
              UiListTile(
                'Rotating the phone',
                subtitle: 'Turning the phone changes the reading, even with no metal near. '
                    'Zero it first, then move it without turning.',
                icon: Icons.screen_rotation_rounded,
                maxSubtitleLines: 5,
              ),
              UiListTile(
                'Sensitivity',
                subtitle: 'Low for large things nearby, High for small or deep metal. '
                    'On High, a shaky hand can look like metal.',
                icon: Icons.tune_rounded,
                maxSubtitleLines: 5,
              ),
              UiListTile(
                'Depth',
                subtitle: 'A phone sensor finds iron within a few centimetres, '
                    'and large steel objects a little further. It is not a professional scanner.',
                icon: Icons.straighten_rounded,
                maxSubtitleLines: 5,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
