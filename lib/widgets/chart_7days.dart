import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

class Chart7Days extends StatefulWidget {
  final List<DailyLog> logs;

  /// 表示ウィンドウ幅（7, 30, 0=全期間）
  final int periodDays;

  const Chart7Days({
    super.key,
    required this.logs,
    this.periodDays = 0,
  });

  /// 7日移動平均を計算
  static List<FlSpot> calcMovingAverage(List<DailyLog> logs,
      {int window = 7}) {
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
  ScrollController? _scrollController;

  static const double _chartHeight = 210;
  static const double _bottomReserved = 30.0;
  static const double _leftAxisWidth = 32.0;
  static const double _minY = 0.8;
  static const double _maxY = 5.3;

  @override
  void initState() {
    super.initState();
    _initScrollController();
  }

  @override
  void didUpdateWidget(covariant Chart7Days oldWidget) {
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

  bool get _isScrollable =>
      widget.periodDays > 0 && widget.logs.length > widget.periodDays;

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
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

    final blueColor = context.chartBlueColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendItem(context, blueColor, '日次スコア', false),
            const Spacer(),
            if (logs.length > 7)
              GestureDetector(
                onTap: () => setState(() => _showMA = !_showMA),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:
                        _showMA ? context.primaryTintColor : context.bgColor,
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
                      color:
                          _showMA ? AppColors.primary : context.textSubColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _chartHeight,
          child: _isScrollable
              ? _buildScrollableLayout(context)
              : _buildChart(context, widget.logs, showLeftAxis: true),
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
    return Row(
      children: [
        // 固定の左Y軸
        SizedBox(
          width: _leftAxisWidth,
          height: _chartHeight,
          child: _buildAxisOnly(context),
        ),
        // スクロール可能なチャート本体
        Expanded(child: _buildScrollableContent(context)),
      ],
    );
  }

  /// Y軸のみ表示する空チャート（スクロール時の固定軸用）
  Widget _buildAxisOnly(BuildContext context) {
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
            child: _buildChart(context, logs, showLeftAxis: false),
          ),
        );
      },
    );
  }

  Widget _buildChart(BuildContext context, List<DailyLog> logs,
      {required bool showLeftAxis}) {
    final maxX = (logs.length - 1).toDouble();
    final gridColor = context.chartGridColor;
    final blueColor = context.chartBlueColor;

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
        right: 14,
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
                  final i = spot.x.round();
                  final dateLabel = (i >= 0 && i < logs.length)
                      ? logs[i].dateKey.substring(5)
                      : '';
                  return LineTooltipItem(
                    '$dateLabel\n${spot.y.toStringAsFixed(1)}',
                    TextStyle(
                      color: spot.bar.color ?? blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
              barWidth: _showMA ? 1.5 : 2.5,
              color: _showMA ? blueColor.withAlpha(100) : blueColor,
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
