import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';
import 'chart_7days.dart';

/// 体調×特徴量 比較グラフ（要件書 Section 2.5）
/// 左軸: 体調スコア(1-5), 右軸: 選択した特徴量
class ComparisonChart extends StatefulWidget {
  final List<DailyLog> logs;

  const ComparisonChart({super.key, required this.logs});

  @override
  State<ComparisonChart> createState() => _ComparisonChartState();
}

class _ComparisonChartState extends State<ComparisonChart> {
  String _selectedFeature = 'sleep';

  static const _featureOptions = {
    'sleep': '睡眠時間',
    'steps': '歩数',
    'stress': 'ストレス',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('まだ履歴がありません')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 特徴量セレクタ
        Row(
          children: _featureOptions.entries.map((e) {
            final selected = _selectedFeature == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _selectedFeature = e.key),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _buildChart(),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final logs = widget.logs;
    final maxX = (logs.length - 1).toDouble();

    // 特徴量の値を取得
    final featureValues = <double?>[];
    for (final log in logs) {
      switch (_selectedFeature) {
        case 'sleep':
          featureValues.add(log.sleep?.durationHours);
          break;
        case 'steps':
          featureValues.add(log.steps?.toDouble());
          break;
        case 'stress':
          featureValues.add(log.stress?.toDouble());
          break;
        default:
          featureValues.add(null);
      }
    }

    // 特徴量のスケール計算
    final validValues = featureValues.whereType<double>().toList();
    if (validValues.isEmpty) {
      return const Center(child: Text('データなし'));
    }
    final featureMin = validValues.reduce((a, b) => a < b ? a : b);
    final featureMax = validValues.reduce((a, b) => a > b ? a : b);
    final featureRange = featureMax - featureMin;

    // 特徴量を1-5スケールに正規化（体調スコアと並べるため）
    double normalize(double v) {
      if (featureRange == 0) return 3.0;
      return 1.0 + (v - featureMin) / featureRange * 4.0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX + 0.6,
          minY: 1,
          maxY: 5,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  // 右軸: 元のスケールに戻す
                  final original = featureMin +
                      (value - 1.0) / 4.0 * featureRange;
                  String text;
                  if (_selectedFeature == 'steps') {
                    text = '${(original / 1000).toStringAsFixed(0)}k';
                  } else {
                    text = original.toStringAsFixed(1);
                  }
                  return Text(text,
                      style: TextStyle(
                          fontSize: 10, color: Colors.orange.shade700));
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
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
                  // 間引き
                  final interval = logs.length <= 10
                      ? 1
                      : logs.length <= 31
                          ? 5
                          : (logs.length / 8).ceil();
                  final isFirst = i == 0;
                  final isLast = i == logs.length - 1;
                  if (!isFirst && !isLast && i % interval != 0) {
                    return const SizedBox.shrink();
                  }
                  final dateKey = logs[i].dateKey;
                  final label = logs.length > 60
                      ? dateKey.substring(2, 7)
                      : dateKey.substring(5);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            // 体調スコア（青）
            LineChartBarData(
              isCurved: true,
              barWidth: logs.length > 7 ? 1.5 : 3,
              color: logs.length > 7 ? Colors.blue.withAlpha(120) : Colors.blue,
              dotData: FlDotData(show: logs.length <= 31),
              spots: [
                for (int i = 0; i < logs.length; i++)
                  FlSpot(i.toDouble(), (logs[i].moodScore ?? 3).toDouble()),
              ],
            ),
            // 7日移動平均（30日以上で体調線に重ねる）
            if (logs.length > 7)
              LineChartBarData(
                isCurved: true,
                barWidth: 3,
                color: Colors.blue.withAlpha(200),
                dotData: const FlDotData(show: false),
                spots: Chart7Days.calcMovingAverage(logs),
              ),
            // 選択した特徴量（オレンジ）
            LineChartBarData(
              isCurved: true,
              barWidth: 2,
              color: Colors.orange,
              dashArray: [5, 3],
              dotData: const FlDotData(show: false),
              spots: [
                for (int i = 0; i < logs.length; i++)
                  if (featureValues[i] != null)
                    FlSpot(i.toDouble(), normalize(featureValues[i]!)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
