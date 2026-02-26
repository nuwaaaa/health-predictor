import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

/// 睡眠パターン専用グラフ（要件書 Section 2.5）
class SleepPatternChart extends StatelessWidget {
  final List<DailyLog> logs;
  final double recommendedHours;

  const SleepPatternChart({
    super.key,
    required this.logs,
    this.recommendedHours = 7.0,
  });

  @override
  Widget build(BuildContext context) {
    final logsWithSleep =
        logs.where((l) => l.sleep?.durationHours != null).toList();

    if (logsWithSleep.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: Text('睡眠データなし', style: AppTextStyles.caption),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(AppColors.chartGreen,
                '${recommendedHours.toStringAsFixed(0)}h以上'),
            const SizedBox(width: 16),
            _legendDot(AppColors.chartOrange,
                '${recommendedHours.toStringAsFixed(0)}h未満'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...logsWithSleep.map((log) => _sleepBar(log)),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.captionSmall),
      ],
    );
  }

  Widget _sleepBar(DailyLog log) {
    final sleep = log.sleep!;
    final dur = sleep.durationHours!;
    final isGood = dur >= recommendedHours;
    final color = isGood ? AppColors.chartGreen : AppColors.chartOrange;
    final barFraction = (dur / 12.0).clamp(0.0, 1.0);
    final bedStr = sleep.bedTime ?? '--:--';
    final wakeStr = sleep.wakeTime ?? '--:--';
    final mmdd = log.dateKey.substring(5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(mmdd, style: AppTextStyles.captionSmall),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 20,
                      width: constraints.maxWidth * barFraction,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '$bedStr → $wakeStr',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              '${dur.toStringAsFixed(1)}h',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isGood
                    ? const Color(0xFF276749)
                    : const Color(0xFF9C4221),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
