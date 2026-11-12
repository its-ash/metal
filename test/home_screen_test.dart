import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metal/core/tone_mapping.dart';
import 'package:metal/main.dart';
import 'package:metal/platform/device_channel.dart';
import 'package:metal/screens/settings_screen.dart';
import 'package:metal/settings/settings_store.dart';
import 'package:theme/theme.dart';

class FakeDevice implements Device {
  final controller = StreamController<FieldSample>();
  final tones = <FeedbackParams>[];
  int stops = 0;
  int vibrations = 0;

  @override
  Stream<FieldSample> field() => controller.stream;

  @override
  Future<void> keepScreenOn(bool on) async {}

  @override
  Future<void> setTone(FeedbackParams p) async => tones.add(p);

  @override
  Future<void> stopTone() async => stops++;

  @override
  Future<void> vibrate(int ms) async => vibrations++;
}

class MissingDevice extends FakeDevice {
  @override
  Stream<FieldSample> field() => Stream.error(const SensorUnavailable('This phone has no magnetometer.'));
}

void main() {
  testWidgets('asks for a zero point first', (tester) async {
    final device = FakeDevice();
    await tester.pumpWidget(MetalApp(settings: SettingsStore.memory(), device: device));
    expect(find.text('Zero'), findsOneWidget);
    expect(find.text('Set the zero point first'), findsOneWidget);
    expect(find.text('Metal'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows a message when there is no magnetometer', (tester) async {
    await tester.pumpWidget(MetalApp(settings: SettingsStore.memory(), device: MissingDevice()));
    await tester.pump();
    expect(find.text('No magnetometer'), findsOneWidget);
    expect(find.text('Zero'), findsNothing);
  });

  testWidgets('settings screen lists the update and developer sections', (tester) async {
    await tester.pumpWidget(UiApp(home: SettingsScreen(settings: SettingsStore.memory())));
    // The update row animates a spinner while it checks, so never settles.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(UiAppearanceSection), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(UiUpdateSection), findsOneWidget);
    expect(find.byType(UiDeveloperSection), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
