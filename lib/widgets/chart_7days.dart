import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

class Chart7Days extends StatefulWidget {
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
  State<Chart7Days> createState() => _Chart7DaysState();
}

class _Chart7DaysState extends State<Chart7Days> {
  bool _showMA = false;

  /// 日次ログを週単位に集約
  static List<_WeekBucket> _aggregateWeekly(List<DailyLog> logs) {
    final buckets = <_WeekBucket>[];
    for (final log in logs) {
      final date = DateTime.tryParse(log.dateKey);
      if (date == null) continue;
      // 月曜始まりの週キー
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final weekKey =
          '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

      if (buckets.isEmpty || buckets.last.weekKey != weekKey) {
        buckets.add(_WeekBucket(weekKey: weekKey, monday: monday));
      }
      if (log.moodScore != null) {
        buckets.last.scores.add(log.moodScore!.toDouble());
      }
    }
    return buckets.where((b) => b.scores.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.logs;
    if (logs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('まだ履歴がありません', style: AppTextStyles.caption),
        ),
      );
    }

    final useWeekly = logs.length > 31;
    final blueColor = context.chartBlueColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendItem(context, blueColor,
                useWeekly ? '週平均' : '日次スコア', false),
            const Spacer(),
            if (!useWeekly && logs.length > 7)
              GestureDetector(
                onTap: () => setState(() => _showMA = !_showMA),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _showMA
                        ? context.primaryTintColor
                        : context.bgColor,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: _showMA
                          ? context.primaryWithAlpha(80)
                          : context.dividerColor,
                    ),
                  ),
                  child: Text(
                    '移動平均',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _showMA
                          ? AppColors.primary
                          : context.textSubColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 200,
          width: double.infinity,
          child: useWeekly
              ? _buildWeeklyChart(context)
              : _buildDailyChart(context),
        ),
      ],
    );
  }

  /// 日次チャート（〜31日）
  Widget _buildDailyChart(BuildContext context) {
    final logs = widget.logs;
    final maxX = (logs.length - 1).toDouble();
    final gridColor = context.chartGridColor;
    final blueColor = context.chartBlueColor;

    int labelInterval;
    if (logs.length <= 10) {
      labelInterval = 1;
    } else {
      labelInterval = 5;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX + 0.6,
          minY: 1,
          maxY: 5,
          gridData: _gridData(gridColor),
          borderData: FlBorderData(show: false),
          lineTouchData: _touchData(blueColor),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: _leftTitles(),
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
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(logs[i].dateKey.substring(5),
                        style: AppTextStyles.captionSmall),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: _showMA ? 1.5 : 2.5,
              color: _showMA ? blueColor.withAlpha(100) : blueColor,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: blueColor,
                  strokeWidth: 0,
                ),
              ),
              spots: [
                for (int i = 0; i < logs.length; i++)
                  FlSpot(
                      i.toDouble(), (logs[i].moodScore ?? 3).toDouble()),
              ],
            ),
            if (_showMA)
              LineChartBarData(
                isCurved: true,
                barWidth: 2.5,
                color: blueColor,
                dotData: const FlDotData(show: false),
                spots: Chart7Days.calcMovingAverage(logs),
              ),
          ],
        ),
      ),
    );
  }

  /// 週平均チャート（32日〜）
  Widget _buildWeeklyChart(BuildContext context) {
    final buckets = _aggregateWeekly(widget.logs);
    if (buckets.isEmpty) {
      return const Center(
        child: Text('データなし', style: AppTextStyles.caption),
      );
    }

    final maxX = (buckets.length - 1).toDouble();
    final gridColor = context.chartGridColor;
    final blueColor = context.chartBlueColor;

    final labelInterval = buckets.length <= 8
        ? 1
        : (buckets.length / 6).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX + 0.6,
          minY: 1,
          maxY: 5,
          gridData: _gridData(gridColor),
          borderData: FlBorderData(show: false),
          lineTouchData: _touchData(blueColor),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: _leftTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= buckets.length) {
                    return const SizedBox.shrink();
                  }
                  final isFirst = i == 0;
                  final isLast = i == buckets.length - 1;
                  if (!isFirst && !isLast && i % labelInterval != 0) {
                    return const SizedBox.shrink();
                  }
                  final label = buckets[i].weekKey.substring(5);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('$label〜',
                        style: AppTextStyles.captionSmall),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: 2.5,
              color: blueColor,
              dotData: FlDotData(
                show: buckets.length <= 20,
                getDotPainter: (spot, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: blueColor,
                  strokeWidth: 0,
                ),
              ),
              spots: [
                for (int i = 0; i < buckets.length; i++)
                  FlSpot(i.toDouble(), buckets[i].average),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 共通ヘルパー ---

  FlGridData _gridData(Color gridColor) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 1,
      getDrawingHorizontalLine: (_) => FlLine(
        color: gridColor,
        strokeWidth: 0.5,
      ),
    );
  }

  LineTouchData _touchData(Color blueColor) {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            return LineTooltipItem(
              spot.y.toStringAsFixed(1),
              TextStyle(
                color: spot.bar.color ?? blueColor,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList();
        },
      ),
    );
  }

  AxisTitles _leftTitles() {
    return AxisTitles(
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
    );
  }

  static Widget _legendItem(
      BuildContext context, Color color, String label, bool dashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 3,
          child: dashed
              ? CustomPaint(painter: _DashedLinePainter(color: color))
              : Container(color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.captionSmall),
      ],
    );
  }
}

class _WeekBucket {
  final String weekKey;
  final DateTime monday;
  final List<double> scores = [];

  _WeekBucket({required this.weekKey, required this.monday});

  double get average => scores.reduce((a, b) => a + b) / scores.length;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    const dashWidth = 4.0;
    const gapWidth = 2.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dashWidth).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
