import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

class Chart7Days extends StatelessWidget {
  final List<DailyLog> logs;

  const Chart7Days({super.key, required this.logs});

  /// 7日移動平均を計算
  static List<FlSpot> calcMovingAverage(List<DailyLog> logs, {int window = 7}) {
    final spots = <FlSpot>[];
    for (int i = window - 1; i < logs.length; i++) {
      double sum = 0;
      int count = 0;
      for (int j = i - window + 1; j <= i; j++) {
        final m = logs[j].moodScore;
        if (m != null) {
          sum += m;
          count++;
        }
      }
      if (count > 0) {
        spots.add(FlSpot(i.toDouble(), sum / count));
      }
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('まだ履歴がありません', style: AppTextStyles.caption),
        ),
      );
    }

    final maxX = (logs.length - 1).toDouble();
    final showMA = logs.length > 7;

    int labelInterval;
    if (logs.length <= 10) {
      labelInterval = 1;
    } else if (logs.length <= 31) {
      labelInterval = 5;
    } else {
      labelInterval = (logs.length / 8).ceil();
    }

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX + 0.6,
            minY: 1,
            maxY: 5,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.chartGrid,
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      spot.y.toStringAsFixed(1),
                      TextStyle(
                        color: spot.bar.color ?? AppColors.chartBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: AppTextStyles.captionSmall,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= logs.length) {
                      return const SizedBox.shrink();
                    }
                    final isFirst = i == 0;
                    final isLast = i == logs.length - 1;
                    if (!isFirst && !isLast && i % labelInterval != 0) {
                      return const SizedBox.shrink();
                    }
                    final dateKey = logs[i].dateKey;
                    final label = logs.length > 60
                        ? dateKey.substring(2, 7)
                        : dateKey.substring(5);

                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label, style: AppTextStyles.captionSmall),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                barWidth: showMA ? 1.5 : 2.5,
                color: showMA
                    ? AppColors.chartBlue.withAlpha(100)
                    : AppColors.chartBlue,
                dotData: FlDotData(
                  show: logs.length <= 31,
                  getDotPainter: (spot, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.chartBlue,
                    strokeWidth: 0,
                  ),
                ),
                spots: [
                  for (int i = 0; i < logs.length; i++)
                    FlSpot(i.toDouble(), (logs[i].moodScore ?? 3).toDouble()),
                ],
              ),
              if (showMA)
                LineChartBarData(
                  isCurved: true,
                  barWidth: 2.5,
                  color: AppColors.chartBlue,
                  dotData: const FlDotData(show: false),
                  spots: calcMovingAverage(logs),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
