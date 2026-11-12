import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/field_math.dart';

/// The big deviation number with a bar and a threshold line.
class DeviationMeter extends StatelessWidget {
  const DeviationMeter({super.key, required this.reading, required this.sensitivity});

  final Reading reading;
  final Sensitivity sensitivity;

  @override
  Widget build(BuildContext context) {
    final ready = reading.phase == DetectorPhase.ready;
    final detected = ready && reading.detected;
    final status = detected ? UiStatus.warning : UiStatus.accent;
    final thresholdAt = (sensitivity.threshold / sensitivity.fullScale).clamp(0.0, 1.0);
    final value = ready ? reading.deviation.toStringAsFixed(1) : '--';

    return UiCard(
      semanticLabel: ready ? 'Deviation $value microtesla' : 'Not zeroed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: context.text.displayMedium?.copyWith(fontWeight: FontWeight.w700)),
              const UiGap(UiSpace.xs),
              Text('µT', style: context.text.titleMedium?.copyWith(color: context.colors.textMuted)),
              const Spacer(),
              UiStatusPill(
                detected ? 'Metal detected' : (ready ? 'Clear' : 'Not zeroed'),
                status: detected ? UiStatus.warning : (ready ? UiStatus.success : UiStatus.neutral),
              ),
            ],
          ),
          const UiGap(UiSpace.xs),
          Text(
            'Deviation from the zero point',
            style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
          ),
          const UiGap(UiSpace.md),
          LayoutBuilder(
            builder: (context, box) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                UiProgressBar(ready ? reading.level : 0, status: status, height: 12),
                Positioned(
                  left: (box.maxWidth * thresholdAt - 1).clamp(0.0, box.maxWidth),
                  child: Container(width: 2, height: 20, color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          const UiGap(UiSpace.xs),
          Text(
            'Line = detection threshold (${sensitivity.threshold.toStringAsFixed(1)} µT)',
            style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}
