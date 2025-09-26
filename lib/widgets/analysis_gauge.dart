// lib/widgets/analysis_gauge.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../utils/constants.dart';

class AnalysisGauge extends StatelessWidget {
  final double score;
  const AnalysisGauge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: -4,
          maximum: 4,
          showLabels: false,
          showTicks: false,
          axisLineStyle: const AxisLineStyle(
            thickness: 0.2,
            cornerStyle: CornerStyle.bothCurve,
            color: Colors.grey,
            thicknessUnit: GaugeSizeUnit.factor,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: score,
              cornerStyle: CornerStyle.bothCurve,
              width: 0.2,
              sizeUnit: GaugeSizeUnit.factor,
              gradient: const SweepGradient(
                colors: <Color>[AppColors.sell, AppColors.hold, AppColors.buy],
                stops: <double>[0.25, 0.5, 0.75],
              ),
            ),
            MarkerPointer(
              value: score,
              markerType: MarkerType.triangle,
              color: Colors.white,
              markerHeight: 20,
              markerWidth: 20,
              markerOffset: -0.1,
              offsetUnit: GaugeSizeUnit.factor,
            )
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                _getSignalFromScore(score),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.7,
            )
          ],
        ),
      ],
    );
  }

  String _getSignalFromScore(double score) {
    if (score > 1.5) return 'BUY';
    if (score > 0.5) return 'WEAK BUY';
    if (score < -1.5) return 'SELL';
    if (score < -0.5) return 'WEAK SELL';
    return 'HOLD';
  }
}