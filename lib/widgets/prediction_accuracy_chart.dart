import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';
import '../models/prediction.dart';
import '../theme/app_theme.dart';

/// 予測 vs 実績の振り返りグラフ
class PredictionAccuracyChart extends StatelessWidget {
  final List<DailyLog> logs;
  final List<Prediction> predictions;

  const PredictionAccuracyChart({
    super.key,
    required this.logs,
    required this.predictions,
  });

  @override
  Widget build(BuildContext context) {
    // ログと予測を dateKey でマッチング
    final pairs = _buildPairs();

    if (pairs.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('予測データがまだありません', style: AppTextStyles.caption),
        ),
      );
    }

    final blueColor = context.chartBlueColor;
    final orangeColor = context.chartOrangeColor;

    // 直近30件に制限
    final display = pairs.length > 30 ? pairs.sublist(pairs.length - 30) : pairs;
    final maxX = (display.length - 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 凡例
        Row(
          children: [
            _legendItem(blueColor, '体調スコア', false),
            const SizedBox(width: 16),
            _legendItem(orangeColor, '不調リスク(%)', true),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 的中/外れサマリー
        _buildSummary(context, display),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 210,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 14),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX + 0.5,
                minY: 0,
                maxY: 5.5,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.chartGridColor,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final i = spot.x.round();
                        if (i < 0 || i >= display.length) return null;
                        final p = display[i];
                        if (spot.barIndex == 0) {
                          return LineTooltipItem(
                            '${p.dateKey.substring(5)}\n体調: ${p.mood}',
                            TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        } else {
                          return LineTooltipItem(
                            'リスク: ${(p.risk * 100).round()}%',
                            TextStyle(
                              color: orangeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 ||
                            value > 5 ||
                            value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        // 右軸: リスク% (0〜5 → 0%〜100%)
                        return Text(
                          '${(value / 5 * 100).round()}%',
                          style: TextStyle(fontSize: 10, color: orangeColor),
                        );
                      },
                    ),
                  ),
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
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= display.length) {
                          return const SizedBox.shrink();
                        }
                        final interval = display.length <= 10
                            ? 1
                            : (display.length / 5).ceil();
                        final isFirst = i == 0;
                        final isLast = i == display.length - 1;
                        if (!isFirst && !isLast && i % interval != 0) {
                          return const SizedBox.shrink();
                        }
                        if (isLast &&
                            i % interval != 0 &&
                            i % interval < interval ~/ 2) {
                          return const SizedBox.shrink();
                        }
                        final dk = display[i].dateKey;
                        final m = int.parse(dk.substring(5, 7));
                        final d = int.parse(dk.substring(8, 10));
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('$m/$d',
                              style: AppTextStyles.captionSmall),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  // 体調スコア (左軸: 1〜5)
                  LineChartBarData(
                    isCurved: false,
                    barWidth: 2.5,
                    color: blueColor,
                    dotData: FlDotData(
                      show: display.length <= 31,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: blueColor,
                        strokeWidth: 0,
                      ),
                    ),
                    spots: [
                      for (int i = 0; i < display.length; i++)
                        FlSpot(i.toDouble(), display[i].mood.toDouble()),
                    ],
                  ),
                  // 不調リスク (右軸: 0〜100% → 0〜5にスケール)
                  LineChartBarData(
                    isCurved: false,
                    barWidth: 2,
                    color: orangeColor,
                    dashArray: [5, 3],
                    dotData: const FlDotData(show: false),
                    spots: [
                      for (int i = 0; i < display.length; i++)
                        FlSpot(
                            i.toDouble(), display[i].risk * 5),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, List<_Pair> pairs) {
    // 「リスク40%以上の日に実際に不調(≤2)だったか」で的中率を計算
    int highRiskDays = 0;
    int actualBadOnHighRisk = 0;
    for (final p in pairs) {
      if (p.risk >= 0.4) {
        highRiskDays++;
        if (p.mood <= 2) actualBadOnHighRisk++;
      }
    }

    if (highRiskDays == 0) {
      return Text(
        '直近の予測でリスク40%以上の日はありませんでした',
        style: TextStyle(fontSize: 12, color: context.textSubColor),
      );
    }

    final hitRate = (actualBadOnHighRisk / highRiskDays * 100).round();
    return Row(
      children: [
        Icon(Icons.analytics_outlined, size: 16, color: context.textSubColor),
        const SizedBox(width: 4),
        Text(
          'リスク警告 $highRiskDays日中 $actualBadOnHighRisk日的中（的中率 $hitRate%）',
          style: TextStyle(fontSize: 12, color: context.textSubColor),
        ),
      ],
    );
  }

  List<_Pair> _buildPairs() {
    final predMap = <String, Prediction>{};
    for (final p in predictions) {
      if (p.pToday != null) predMap[p.dateKey] = p;
    }

    final pairs = <_Pair>[];
    for (final log in logs) {
      if (log.moodScore == null) continue;
      final pred = predMap[log.dateKey];
      if (pred == null || pred.displayPToday == null) continue;
      pairs.add(_Pair(
        dateKey: log.dateKey,
        mood: log.moodScore!,
        risk: pred.displayPToday!,
      ));
    }
    return pairs;
  }

  Widget _legendItem(Color color, String label, bool dashed) {
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

class _Pair {
  final String dateKey;
  final int mood;
  final double risk;
  _Pair({required this.dateKey, required this.mood, required this.risk});
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
