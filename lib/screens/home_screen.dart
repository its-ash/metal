import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/field_math.dart';
import '../core/tone_mapping.dart';
import '../platform/device_channel.dart';
import '../settings/settings_store.dart';
import '../widgets/deviation_meter.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

/// The detector: reads the magnetometer, shows the deviation and plays tone
/// and vibration feedback. The sensor, tone and screen-on flag are released
/// when the app goes to the background.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.device, required this.settings});

  final Device device;
  final SettingsStore settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// Screen refresh and feedback update interval.
  static const _uiIntervalMs = 40;

  late final DetectorEngine _engine;
  final _clock = Stopwatch()..start();
  StreamSubscription<FieldSample>? _sub;
  Object? _error;

  Reading _reading = Reading.idle;
  bool _uncalibrated = true;
  int _lastUiMs = -1000;
  int _lastVibeMs = -1000;
  FeedbackParams _tone = FeedbackParams.silent;
  bool _toneOn = false;

  Device get _device => widget.device;
  SettingsStore get _settings => widget.settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = DetectorEngine(sensitivity: _settings.sensitivity, autoRezero: _settings.autoRezero);
    _settings.addListener(_onSettings);
    _device.keepScreenOn(true);
    _subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettings);
    _sub?.cancel();
    _stopTone();
    _device.keepScreenOn(false);
    super.dispose();
  }

  void _subscribe() {
    _sub?.cancel();
    _error = null;
    _sub = _device.field().listen(
      _onSample,
      onError: (Object e) {
        if (mounted) setState(() => _error = e);
      },
      cancelOnError: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _sub?.cancel();
      _sub = null;
      _stopTone();
    } else if (state == AppLifecycleState.resumed && _sub == null && _error == null) {
      _subscribe();
    }
  }

  void _onSettings() {
    _engine.sensitivity = _settings.sensitivity;
    _engine.autoRezero = _settings.autoRezero;
    if (!_settings.sound) _stopTone();
    if (mounted) setState(() {});
  }

  void _onSample(FieldSample s) {
    final now = _clock.elapsedMilliseconds;
    final r = _engine.feed(s.field, now);
    _uncalibrated = s.uncalibrated;
    // Phase changes are shown at once; the rest is throttled.
    final phaseChanged = r.phase != _reading.phase;
    if (!phaseChanged && now - _lastUiMs < _uiIntervalMs) return;
    _lastUiMs = now;
    _updateFeedback(r, now);
    if (mounted) setState(() => _reading = r);
  }

  void _updateFeedback(Reading r, int now) {
    final s = _engine.sensitivity;
    final fb = r.phase == DetectorPhase.ready && r.detected
        ? feedbackFor(
            deviation: math.max(r.deviation, s.threshold),
            threshold: s.threshold,
            fullScale: s.fullScale,
          )
        : FeedbackParams.silent;

    if (_settings.sound && fb.active) {
      if (fb != _tone || !_toneOn) {
        _tone = fb;
        _toneOn = true;
        _device.setTone(fb);
      }
    } else {
      _stopTone();
    }

    if (_settings.vibration && fb.active && now - _lastVibeMs >= vibrationPeriodMs(fb)) {
      _lastVibeMs = now;
      _device.vibrate(40);
    }
  }

  void _stopTone() {
    if (!_toneOn) return;
    _toneOn = false;
    _tone = FeedbackParams.silent;
    _device.stopTone();
  }

  void _zero() {
    _engine.zero();
    _stopTone();
    setState(() => _reading = const Reading(
          phase: DetectorPhase.calibrating,
          magnitude: 0,
          deviation: 0,
          level: 0,
          detected: false,
          calibrationProgress: 0,
          unsteady: false,
        ));
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return UiScaffold(
      appBar: UiAppBar(
        title: 'Metal',
        actions: [
          UiIconButton(Icons.help_outline_rounded, tooltip: 'Help', onPressed: () => _open(const HelpScreen())),
          UiIconButton(
            Icons.settings_rounded,
            tooltip: 'Settings',
            onPressed: () => _open(SettingsScreen(settings: _settings)),
          ),
        ],
      ),
      scrollable: _error == null,
      body: _error != null ? _unavailable() : _detector(context),
    );
  }

  Widget _unavailable() {
    final message = _error is SensorUnavailable ? (_error as SensorUnavailable).message : 'The sensor could not be read.';
    return Center(
      child: UiEmptyState(
        icon: Icons.sensors_off_rounded,
        title: 'No magnetometer',
        message: '$message A metal detector needs the magnetic field sensor, so Metal cannot work on this phone.',
      ),
    );
  }

  Widget _status() {
    final r = _reading;
    switch (r.phase) {
      case DetectorPhase.needsZero:
        return const UiAlert(
          'Hold the phone still, away from metal and magnets, then tap Zero.',
          title: 'Set the zero point first',
        );
      case DetectorPhase.calibrating:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiProgressBar(r.calibrationProgress, label: 'Calibrating, hold still'),
            if (r.unsteady) ...[
              const UiGap(UiSpace.sm),
              const UiAlert('The phone moved. Keep it still and away from metal.', status: UiStatus.warning),
            ],
          ],
        );
      case DetectorPhase.ready:
        if (r.unsteady) {
          return const UiAlert(
            'The phone was moving while zeroing, so results may be off. Tap Zero again.',
            status: UiStatus.warning,
          );
        }
        return const SizedBox.shrink();
    }
  }

  Widget _graph(BuildContext context) {
    final s = _settings.sensitivity;
    var values = _engine.history.values;
    if (values.length < 2) values = [0, 0];
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Last 10 seconds', style: context.text.titleSmall),
          const UiGap(UiSpace.sm),
          UiLineChart(
            series: [
              UiChartSeries('Deviation', values),
              UiChartSeries('Threshold', List.filled(values.length, s.threshold)),
            ],
            height: 150,
            curved: false,
            yFormat: (v) => v.toStringAsFixed(0),
            showLegend: true,
          ),
        ],
      ),
    );
  }

  Widget _detector(BuildContext context) {
    final r = _reading;
    final ready = r.phase == DetectorPhase.ready;
    final peak = ready && _engine.history.values.isNotEmpty ? _engine.history.values.reduce(math.max) : 0.0;
    final busy = r.phase == DetectorPhase.calibrating;
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeviationMeter(reading: r, sensitivity: _settings.sensitivity),
          const UiGap(UiSpace.md),
          _status(),
          if (r.phase != DetectorPhase.ready || r.unsteady) const UiGap(UiSpace.md),
          UiButton(
            ready ? 'Zero again' : 'Zero',
            icon: Icons.adjust_rounded,
            expand: true,
            loading: busy,
            onPressed: busy ? null : _zero,
          ),
          const UiGap(UiSpace.lg),
          UiSegmentedControl<Sensitivity>(
            [for (final s in Sensitivity.values) UiSegment(s, label: s.label)],
            value: _settings.sensitivity,
            expand: true,
            onChanged: _settings.setSensitivity,
          ),
          const UiGap(UiSpace.xs),
          Text(
            'Sensitivity. High finds small or distant metal but also reacts to hand movement.',
            style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
          ),
          const UiGap(UiSpace.lg),
          _graph(context),
          const UiGap(UiSpace.lg),
          UiListGroup(
            header: 'Readings',
            children: [
              UiKeyValue('Field strength', r.magnitude > 0 ? '${r.magnitude.toStringAsFixed(1)} µT' : '--'),
              UiKeyValue('Peak deviation', ready ? '${peak.toStringAsFixed(1)} µT' : '--'),
              UiKeyValue('Zero point', ready ? '${_engine.baseline.length.toStringAsFixed(1)} µT' : '--'),
              UiKeyValue('Sensor', _uncalibrated ? 'Raw (best)' : 'Calibrated'),
            ],
          ),
          const UiGap(UiSpace.lg),
          UiListGroup(
            header: 'Feedback',
            children: [
              UiSwitchTile(
                'Sound',
                subtitle: 'Pitch and beep rate rise as you get closer',
                icon: Icons.volume_up_rounded,
                value: _settings.sound,
                onChanged: _settings.setSound,
              ),
              UiSwitchTile(
                'Vibration',
                subtitle: 'Pulses faster near metal',
                icon: Icons.vibration_rounded,
                value: _settings.vibration,
                onChanged: _settings.setVibration,
              ),
              UiSwitchTile(
                'Auto re-zero',
                subtitle: 'Follows slow changes so you do not need to zero again',
                icon: Icons.autorenew_rounded,
                value: _settings.autoRezero,
                onChanged: _settings.setAutoRezero,
              ),
            ],
          ),
          const UiGap(UiSpace.lg),
          const UiAlert(
            'The sensor is usually near the top of the phone. Sweep slowly with the top edge '
            'and keep the phone at the same angle.',
            title: 'Tip',
          ),
        ],
      ),
    );
  }
}
