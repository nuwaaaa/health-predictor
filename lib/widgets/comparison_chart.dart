import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';
import 'chart_7days.dart';

/// 体調×特徴量 比較グラフ（設計書 Section 14.1）
/// 左軸: 体調スコア(1-5), 右軸: 選択した特徴量
/// 全学習特徴量を選択肢として表示（透明性重視）
class ComparisonChart extends StatefulWidget {
  final List<DailyLog> logs;

  const ComparisonChart({super.key, required this.logs});

  @override
  State<ComparisonChart> createState() => _ComparisonChartState();
}

class _ComparisonChartState extends State<ComparisonChart> {
  String _selectedFeature = 'sleep';

  // 設計書 Section 14.1: 全学習特徴量を選択肢として表示
  static const _featureOptions = <String, String>{
    'sleep': '睡眠時間',
    'steps': '歩数',
    'stress': 'ストレス',
    'mood_t1': '前日の体調',
    'ma3': '直近3日の体調傾向',
    'ma7': '直近7日の体調傾向',
    'delta1': '体調の変化',
    'dev14': '普段との体調差',
    'sleep_dev': '普段との睡眠差',
    'steps_dev': '普段との歩数差',
    'day_of_week': '曜日',
    'is_weekend': '休日かどうか',
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
        // 特徴量セレクタ（ドロップダウン）
        DropdownButtonFormField<String>(
          value: _selectedFeature,
          decoration: const InputDecoration(
            labelText: '比較する特徴量',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _featureOptions.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedFeature = v);
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _buildChart(),
        ),
      ],
    );
  }

  /// 選択した特徴量の値リストを計算
  List<double?> _computeFeatureValues(List<DailyLog> logs) {
    switch (_selectedFeature) {
      case 'sleep':
        return logs.map((l) => l.sleep?.durationHours).toList();
      case 'steps':
        return logs.map((l) => l.steps?.toDouble()).toList();
      case 'stress':
        return logs.map((l) => l.stress?.toDouble()).toList();
      case 'mood_t1':
        // 前日の体調（t-1のmoodScore）
        return [
          null,
          ...logs
              .take(logs.length - 1)
              .map((l) => l.moodScore?.toDouble()),
        ];
      case 'ma3':
        return _computeMA(logs, 3);
      case 'ma7':
        return _computeMA(logs, 7);
      case 'delta1':
        return _computeDelta(logs);
      case 'dev14':
        return _computeDeviation(logs, 14);
      case 'sleep_dev':
        return _computeSleepDev(logs);
      case 'steps_dev':
        return _computeStepsDev(logs);
      case 'day_of_week':
        return logs.map((l) {
          final dow = _dayOfWeek(l.dateKey);
          return dow != null ? (dow - 1).toDouble() : null; // 0=月〜6=日
        }).toList();
      case 'is_weekend':
        return logs.map((l) {
          final dow = _dayOfWeek(l.dateKey);
          return dow != null ? (dow >= 6 ? 1.0 : 0.0) : null;
        }).toList();
      default:
        return logs.map((_) => null).toList();
    }
  }

  /// 体調スコアの移動平均（t-1基準、リーク防止）
  List<double?> _computeMA(List<DailyLog> logs, int window) {
    final result = <double?>[];
    for (int i = 0; i < logs.length; i++) {
      final start = (i - window).clamp(0, logs.length);
      final end = i; // t-1まで（当日を含めない）
      if (end <= start) {
        result.add(null);
        continue;
      }
      final scores = <double>[];
      for (int j = start; j < end; j++) {
        if (logs[j].moodScore != null) {
          scores.add(logs[j].moodScore!.toDouble());
        }
      }
      result.add(scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length);
    }
    return result;
  }

  /// 体調変化量 delta1(t-1) = mood(t-1) - mood(t-2)
  List<double?> _computeDelta(List<DailyLog> logs) {
    final result = <double?>[];
    for (int i = 0; i < logs.length; i++) {
      if (i < 2 ||
          logs[i - 1].moodScore == null ||
          logs[i - 2].moodScore == null) {
        result.add(null);
      } else {
        result.add(
            (logs[i - 1].moodScore! - logs[i - 2].moodScore!).toDouble());
      }
    }
    return result;
  }

  /// 14日平均との偏差 dev14(t-1) = mood(t-1) - ma14(t)
  List<double?> _computeDeviation(List<DailyLog> logs, int window) {
    final ma = _computeMA(logs, window);
    final result = <double?>[];
    for (int i = 0; i < logs.length; i++) {
      if (i < 1 || logs[i - 1].moodScore == null || ma[i] == null) {
        result.add(null);
      } else {
        result.add(logs[i - 1].moodScore!.toDouble() - ma[i]!);
      }
    }
    return result;
  }

  /// 睡眠偏差（当日の睡眠 - 全期間平均）
  List<double?> _computeSleepDev(List<DailyLog> logs) {
    final valid = logs
        .where((l) => l.sleep?.durationHours != null)
        .map((l) => l.sleep!.durationHours!)
        .toList();
    if (valid.isEmpty) return logs.map((_) => null).toList();
    final avg = valid.reduce((a, b) => a + b) / valid.length;
    return logs.map((l) {
      final h = l.sleep?.durationHours;
      return h != null ? h - avg : null;
    }).toList();
  }

  /// 歩数偏差（当日の歩数 - 全期間平均）
  List<double?> _computeStepsDev(List<DailyLog> logs) {
    final valid = logs
        .where((l) => l.steps != null)
        .map((l) => l.steps!.toDouble())
        .toList();
    if (valid.isEmpty) return logs.map((_) => null).toList();
    final avg = valid.reduce((a, b) => a + b) / valid.length;
    return logs.map((l) {
      return l.steps != null ? l.steps!.toDouble() - avg : null;
    }).toList();
  }

  /// dateKey → 曜日（1=Mon, 7=Sun）
  int? _dayOfWeek(String dateKey) {
    try {
      final parts = dateKey.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]),
              int.parse(parts[2]))
          .weekday;
    } catch (_) {
      return null;
    }
  }

  /// 右軸ラベルのフォーマット
  String _formatRightAxis(double original) {
    switch (_selectedFeature) {
      case 'steps':
        return '${(original / 1000).toStringAsFixed(0)}k';
      case 'steps_dev':
        final sign = original >= 0 ? '+' : '';
        return '$sign${(original / 1000).toStringAsFixed(1)}k';
      case 'sleep_dev':
        final sign = original >= 0 ? '+' : '';
        return '$sign${original.toStringAsFixed(1)}h';
      case 'delta1':
      case 'dev14':
        final sign = original >= 0 ? '+' : '';
        return '$sign${original.toStringAsFixed(1)}';
      case 'day_of_week':
        const days = ['月', '火', '水', '木', '金', '土', '日'];
        final idx = original.round().clamp(0, 6);
        return days[idx];
      case 'is_weekend':
        return original >= 0.5 ? '休日' : '平日';
      default:
        return original.toStringAsFixed(1);
    }
  }

  Widget _buildChart() {
    final logs = widget.logs;
    final maxX = (logs.length - 1).toDouble();

    // 特徴量の値を計算
    final featureValues = _computeFeatureValues(logs);

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
                  final original =
                      featureMin + (value - 1.0) / 4.0 * featureRange;
                  return Text(_formatRightAxis(original),
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
              color:
                  logs.length > 7 ? Colors.blue.withAlpha(120) : Colors.blue,
              dotData: FlDotData(show: logs.length <= 31),
              spots: [
                for (int i = 0; i < logs.length; i++)
                  FlSpot(
                      i.toDouble(), (logs[i].moodScore ?? 3).toDouble()),
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
