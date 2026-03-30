import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

/// 相関散布図（特徴量 vs 翌日の体調）
class CorrelationScatter extends StatefulWidget {
  final List<DailyLog> logs;

  const CorrelationScatter({super.key, required this.logs});

  @override
  State<CorrelationScatter> createState() => _CorrelationScatterState();
}

class _CorrelationScatterState extends State<CorrelationScatter> {
  String _selectedFeature = 'sleep';

  static const _featureOptions = <String, String>{
    'sleep': '睡眠時間',
    'steps': '歩数',
    'stress': 'ストレス',
  };

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    final blueColor = context.chartBlueColor;
    final orangeColor = context.chartOrangeColor;

    if (points.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('データが不足しています', style: AppTextStyles.caption),
        ),
      );
    }

    // X軸の範囲を計算
    final xValues = points.map((p) => p.x).toList();
    final xMin = xValues.reduce((a, b) => a < b ? a : b);
    final xMax = xValues.reduce((a, b) => a > b ? a : b);
    final xRange = xMax - xMin;
    final xPadding = xRange * 0.1;

    // 平均線を計算
    final avgX = xValues.reduce((a, b) => a + b) / xValues.length;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 特徴量選択
        Wrap(
          spacing: AppSpacing.sm,
          children: _featureOptions.entries.map((e) {
            final selected = _selectedFeature == e.key;
            return GestureDetector(
              onTap: () => setState(() => _selectedFeature = e.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? context.primaryTintColor
                      : context.bgColor,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: selected
                        ? context.primaryWithAlpha(80)
                        : context.dividerColor,
                  ),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.primary : context.textSubColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        // 相関の要約
        _buildCorrelationSummary(context, points, avgX),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 14),
            child: ScatterChart(
              ScatterChartData(
                minX: xMin - xPadding,
                maxX: xMax + xPadding,
                minY: 0.5,
                maxY: 5.5,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.chartGridColor,
                    strokeWidth: 0.5,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: context.chartGridColor,
                    strokeWidth: 0.3,
                  ),
                ),
                borderData: FlBorderData(show: false),
                scatterTouchData: ScatterTouchData(
                  touchTooltipData: ScatterTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spot) {
                      return ScatterTooltipItem(
                        '${_featureOptions[_selectedFeature]}: ${_formatX(spot.x)}\n翌日の体調: ${spot.y.round()}',
                        textStyle: TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value < 1 ||
                            value > 5 ||
                            value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: AppTextStyles.captionSmall,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(
                      _featureOptions[_selectedFeature] ?? '',
                      style: TextStyle(
                          fontSize: 11, color: context.textSubColor),
                    ),
                    axisNameSize: 20,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _formatX(value),
                            style: AppTextStyles.captionSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                scatterSpots: [
                  for (final p in points)
                    ScatterSpot(
                      p.x,
                      p.y,
                      dotPainter: FlDotCirclePainter(
                        radius: 4,
                        color: _spotColor(context, p.y, blueColor, orangeColor),
                        strokeWidth: 0,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorrelationSummary(
      BuildContext context, List<_Point> points, double avgX) {
    // 平均X以上/未満で体調平均を比較
    final above = points.where((p) => p.x >= avgX).toList();
    final below = points.where((p) => p.x < avgX).toList();

    if (above.isEmpty || below.isEmpty) {
      return const SizedBox.shrink();
    }

    final avgAbove =
        above.map((p) => p.y).reduce((a, b) => a + b) / above.length;
    final avgBelow =
        below.map((p) => p.y).reduce((a, b) => a + b) / below.length;
    final diff = avgAbove - avgBelow;
    final featureName = _featureOptions[_selectedFeature] ?? '';

    String message;
    if (diff.abs() < 0.2) {
      message = '$featureNameと翌日の体調に明確な傾向は見られません';
    } else if (diff > 0) {
      message =
          '$featureName多め → 翌日の体調が平均+${diff.toStringAsFixed(1)}良い傾向';
    } else {
      message =
          '$featureName多め → 翌日の体調が平均${diff.toStringAsFixed(1)}低い傾向';
    }

    return Row(
      children: [
        Icon(Icons.insights, size: 16, color: context.textSubColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            message,
            style: TextStyle(fontSize: 12, color: context.textSubColor),
          ),
        ),
      ],
    );
  }

  Color _spotColor(
      BuildContext context, double mood, Color blue, Color orange) {
    if (mood <= 2) return orange;
    if (mood >= 4) return context.chartGreenColor;
    return blue;
  }

  String _formatX(double value) {
    switch (_selectedFeature) {
      case 'steps':
        return '${(value / 1000).toStringAsFixed(0)}k';
      case 'sleep':
        return '${value.toStringAsFixed(1)}h';
      case 'stress':
        return value.round().toString();
      default:
        return value.toStringAsFixed(1);
    }
  }

  List<_Point> _buildPoints() {
    final logs = widget.logs;
    final points = <_Point>[];

    for (int i = 0; i < logs.length - 1; i++) {
      final today = logs[i];
      final tomorrow = logs[i + 1];
      if (tomorrow.moodScore == null) continue;

      double? x;
      switch (_selectedFeature) {
        case 'sleep':
          x = today.sleep?.durationHours;
          break;
        case 'steps':
          x = today.steps?.toDouble();
          break;
        case 'stress':
          x = today.stress?.toDouble();
          break;
      }

      if (x == null) continue;

      points.add(_Point(x: x, y: tomorrow.moodScore!.toDouble()));
    }

    return points;
  }
}

class _Point {
  final double x;
  final double y;
  _Point({required this.x, required this.y});
}
