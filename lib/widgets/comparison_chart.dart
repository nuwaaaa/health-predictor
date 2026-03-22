import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

/// 体調×特徴量 比較グラフ（設計書 Section 14.1）
class ComparisonChart extends StatefulWidget {
  final List<DailyLog> logs;

  /// 表示ウィンドウ幅（7, 30, 0=全期間）
  final int periodDays;

  const ComparisonChart({
    super.key,
    required this.logs,
    this.periodDays = 0,
  });

  @override
  State<ComparisonChart> createState() => _ComparisonChartState();
}

class _ComparisonChartState extends State<ComparisonChart> {
  String _selectedFeature = 'sleep';
  bool _showAdvanced = false;
  List<double?>? _cachedFeatureValues;
  String? _cachedFeatureKey;
  int? _cachedLogsLength;
  ScrollController? _scrollController;

  static const double _chartHeight = 210;
  static const double _bottomReserved = 30.0;
  static const double _leftAxisWidth = 32.0;
  static const double _rightAxisWidth = 54.0;
  static const double _minY = 0.8;
  static const double _maxY = 5.3;

  List<double?> _getFeatureValues(List<DailyLog> logs) {
    final key = '$_selectedFeature:${logs.length}';
    if (_cachedFeatureKey == key && _cachedLogsLength == logs.length && _cachedFeatureValues != null) {
      return _cachedFeatureValues!;
    }
    _cachedFeatureValues = _computeFeatureValues(logs);
    _cachedFeatureKey = key;
    _cachedLogsLength = logs.length;
    return _cachedFeatureValues!;
  }

  // 基本項目
  static const _basicOptions = <String, String>{
    'sleep': '睡眠時間',
    'steps': '歩数',
    'stress': 'ストレス',
    'mood_t1': '前日の体調',
  };

  // 詳細項目（トレンド + パターン）
  static const _advancedOptions = <String, String>{
    'ma3': '体調の3日平均',
    'ma7': '体調の7日平均',
    'delta1': '体調の前日比',
    'dev14': '普段との体調差',
    'sleep_dev': '普段との睡眠差',
    'steps_dev': '普段との歩数差',
    'is_weekend': '休日かどうか',
  };

  Map<String, String> get _activeOptions {
    if (_showAdvanced) {
      return {..._basicOptions, ..._advancedOptions};
    }
    return _basicOptions;
  }

  bool get _isScrollable =>
      widget.periodDays > 0 && widget.logs.length > widget.periodDays;

  @override
  void initState() {
    super.initState();
    _initScrollController();
  }

  @override
  void didUpdateWidget(covariant ComparisonChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodDays != widget.periodDays ||
        oldWidget.logs.length != widget.logs.length) {
      _initScrollController();
    }
  }

  void _initScrollController() {
    _scrollController?.dispose();
    if (_isScrollable) {
      _scrollController = ScrollController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController != null &&
            _scrollController!.hasClients &&
            _scrollController!.position.maxScrollExtent > 0) {
          _scrollController!
              .jumpTo(_scrollController!.position.maxScrollExtent);
        }
      });
    } else {
      _scrollController = null;
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('まだ履歴がありません', style: AppTextStyles.caption),
        ),
      );
    }

    // 詳細を閉じた際に選択中の項目が基本にない場合、リセット
    if (!_showAdvanced && !_basicOptions.containsKey(_selectedFeature)) {
      _selectedFeature = 'sleep';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedFeature,
                decoration: const InputDecoration(
                  labelText: '比較する生活データ',
                  isDense: true,
                ),
                items: _activeOptions.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedFeature = v);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _showAdvanced ? context.primaryTintColor : context.bgColor,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: _showAdvanced ? context.primaryWithAlpha(80) : context.dividerColor,
                  ),
                ),
                child: Text(
                  _showAdvanced ? '基本のみ' : '詳細',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _showAdvanced ? AppColors.primary : context.textSubColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _legendItem(context.chartBlueColor, '体調スコア', false),
            const SizedBox(width: 16),
            _legendItem(context.chartOrangeColor,
                _activeOptions[_selectedFeature] ?? '', true),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _chartHeight,
          child: _isScrollable
              ? _buildScrollableLayout(context)
              : _buildChart(context, showLeftAxis: true, showRightAxis: true),
        ),
        if (_isScrollable)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: Text(
                '← 左右にスライドして過去のデータを確認 →',
                style: TextStyle(
                  fontSize: 10,
                  color: context.textSubColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 固定Y軸 + スクロール可能チャートのレイアウト
  Widget _buildScrollableLayout(BuildContext context) {
    final logs = widget.logs;
    final featureValues = _getFeatureValues(logs);
    final validValues = featureValues.whereType<double>().toList();

    return Row(
      children: [
        // 固定の左Y軸（体調スコア）
        SizedBox(
          width: _leftAxisWidth,
          height: _chartHeight,
          child: _buildFixedLeftAxis(context),
        ),
        // スクロール可能なチャート本体
        Expanded(child: _buildScrollableContent(context)),
        // 固定の右Y軸（特徴量）
        if (validValues.isNotEmpty)
          SizedBox(
            width: _rightAxisWidth,
            height: _chartHeight,
            child: _buildFixedRightAxis(context, validValues),
          ),
      ],
    );
  }

  /// 左Y軸のみ表示する空チャート
  Widget _buildFixedLeftAxis(BuildContext context) {
    final gridColor = context.chartGridColor;
    return LineChart(
      LineChartData(
        minY: _minY,
        maxY: _maxY,
        minX: 0,
        maxX: 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: gridColor,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [],
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value < 1 || value > 5 || value != value.roundToDouble()) {
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
              reservedSize: _bottomReserved,
              getTitlesWidget: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  /// 右Y軸のみ表示する空チャート
  Widget _buildFixedRightAxis(
      BuildContext context, List<double> validValues) {
    final gridColor = context.chartGridColor;
    final orangeColor = context.chartOrangeColor;
    final featureMin = validValues.reduce((a, b) => a < b ? a : b);
    final featureMax = validValues.reduce((a, b) => a > b ? a : b);
    final featureRange = featureMax - featureMin;

    return LineChart(
      LineChartData(
        minY: _minY,
        maxY: _maxY,
        minX: 0,
        maxX: 1,
        gridData: FlGridData(
          show: false,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: gridColor,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [],
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value < 1 || value > 5 || value != value.roundToDouble()) {
                  return const SizedBox.shrink();
                }
                final original =
                    featureMin + (value - 1.0) / 4.0 * featureRange;
                return Text(
                  _formatRightAxis(original),
                  style: TextStyle(fontSize: 10, color: orangeColor),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _bottomReserved,
              getTitlesWidget: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  /// スクロール可能なチャート本体
  Widget _buildScrollableContent(BuildContext context) {
    final logs = widget.logs;
    final periodDays = widget.periodDays;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final pixelsPerDay = viewportWidth / periodDays;
        final chartWidth = pixelsPerDay * (logs.length - 1 + 0.6);

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth.clamp(viewportWidth, double.infinity),
            height: _chartHeight,
            child: _buildChart(context,
                showLeftAxis: false, showRightAxis: false),
          ),
        );
      },
    );
  }

  List<double?> _computeFeatureValues(List<DailyLog> logs) {
    switch (_selectedFeature) {
      case 'sleep':
        return logs.map((l) => l.sleep?.durationHours).toList();
      case 'steps':
        return logs.map((l) => l.steps?.toDouble()).toList();
      case 'stress':
        return logs.map((l) => l.stress?.toDouble()).toList();
      case 'mood_t1':
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
      case 'is_weekend':
        return logs.map((l) {
          final dow = _dayOfWeek(l.dateKey);
          return dow != null ? (dow >= 6 ? 1.0 : 0.0) : null;
        }).toList();
      default:
        return logs.map((_) => null).toList();
    }
  }

  List<double?> _computeMA(List<DailyLog> logs, int window) {
    final result = <double?>[];
    for (int i = 0; i < logs.length; i++) {
      final start = (i - window).clamp(0, logs.length);
      final end = i;
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
      case 'is_weekend':
        return original >= 0.5 ? '休日' : '平日';
      default:
        return original.toStringAsFixed(1);
    }
  }

  Widget _buildChart(BuildContext context,
      {required bool showLeftAxis, required bool showRightAxis}) {
    final logs = widget.logs;
    final maxX = (logs.length - 1).toDouble();
    final featureValues = _getFeatureValues(logs);
    final validValues = featureValues.whereType<double>().toList();
    if (validValues.isEmpty) {
      return const Center(
        child: Text('データなし', style: AppTextStyles.caption),
      );
    }
    final featureMin = validValues.reduce((a, b) => a < b ? a : b);
    final featureMax = validValues.reduce((a, b) => a > b ? a : b);
    final featureRange = featureMax - featureMin;

    double normalize(double v) {
      if (featureRange == 0) return 3.0;
      return 1.0 + (v - featureMin) / featureRange * 4.0;
    }

    final gridColor = context.chartGridColor;
    final blueColor = context.chartBlueColor;
    final orangeColor = context.chartOrangeColor;

    int labelInterval;
    if (logs.length <= 10) {
      labelInterval = 1;
    } else if (logs.length <= 31) {
      labelInterval = 5;
    } else {
      labelInterval = (logs.length / 8).ceil();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: showLeftAxis ? 14 : 0,
        right: showRightAxis ? 14 : 0,
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX + 0.6,
          minY: _minY,
          maxY: _maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: gridColor,
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
                        final isMood = spot.bar.color == blueColor ||
                            spot.bar.color == blueColor.withAlpha(100);
                        if (isMood) {
                          final i = spot.x.round();
                          final dateLabel = (i >= 0 && i < logs.length)
                              ? logs[i].dateKey.substring(5)
                              : '';
                          return LineTooltipItem(
                            '$dateLabel\n${spot.y.toStringAsFixed(1)}',
                            TextStyle(
                              color: spot.bar.color ?? blueColor,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        } else {
                          final original = featureRange == 0
                              ? featureMin
                              : featureMin +
                                  (spot.y - 1.0) / 4.0 * featureRange;
                          return LineTooltipItem(
                            _formatRightAxis(original),
                            TextStyle(
                              color: orangeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                      }).toList();
                    },
                  ),
                ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: showRightAxis
                ? AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        final original =
                            featureMin + (value - 1.0) / 4.0 * featureRange;
                        return Text(
                          _formatRightAxis(original),
                          style: TextStyle(
                              fontSize: 10, color: orangeColor),
                        );
                      },
                    ),
                  )
                : const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
            leftTitles: showLeftAxis
                ? AxisTitles(
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
                  )
                : const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: _bottomReserved,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= logs.length) {
                    return const SizedBox.shrink();
                  }
                  if (!_isScrollable) {
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
                  } else {
                    if (i % labelInterval != 0) {
                      return const SizedBox.shrink();
                    }
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
              barWidth: 2.5,
              color: blueColor,
              dotData: FlDotData(
                show: widget.periodDays != 0 || logs.length <= 31,
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
            LineChartBarData(
              isCurved: true,
              barWidth: 2,
              color: orangeColor,
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

  int get labelInterval {
    final len = widget.logs.length;
    if (len <= 10) return 1;
    if (len <= 31) return 5;
    return (len / 8).ceil();
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
