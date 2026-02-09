import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/daily_log.dart';

class Chart7Days extends StatelessWidget {
  final List<DailyLog> logs;

  const Chart7Days({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('まだ履歴がありません')),
      );
    }

    final maxX = (logs.length - 1).toDouble();

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
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    final mmdd = logs[i].dateKey.substring(5);
                    final isFirst = i == 0;
                    final isLast = i == logs.length - 1;
                    final dx = isFirst ? 10.0 : (isLast ? -10.0 : 0.0);

                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(mmdd, style: const TextStyle(fontSize: 10)),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                barWidth: 3,
                color: Colors.blue,
                dotData: const FlDotData(show: true),
                spots: [
                  for (int i = 0; i < logs.length; i++)
                    FlSpot(i.toDouble(), (logs[i].moodScore ?? 3).toDouble()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
