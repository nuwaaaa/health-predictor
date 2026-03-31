import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

/// 週別×曜日の体調ヒートマップ
class MoodHeatmap extends StatelessWidget {
  final List<DailyLog> logs;

  const MoodHeatmap({super.key, required this.logs});

  static const _dayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('まだ履歴がありません', style: AppTextStyles.caption),
        ),
      );
    }

    // dateKey → moodScore マップを作成
    final moodMap = <String, int>{};
    for (final log in logs) {
      if (log.moodScore != null) {
        moodMap[log.dateKey] = log.moodScore!;
      }
    }

    // 最古の日付を月曜始まりの週頭にアライン
    final firstDate = _parseDate(logs.first.dateKey);
    final lastDate = _parseDate(logs.last.dateKey);
    if (firstDate == null || lastDate == null) {
      return const SizedBox.shrink();
    }

    // 月曜始まりにアライン（weekday: 1=月曜）
    final startMonday =
        firstDate.subtract(Duration(days: firstDate.weekday - 1));
    final endSunday =
        lastDate.add(Duration(days: 7 - lastDate.weekday));

    // 週数を計算
    final totalDays = endSunday.difference(startMonday).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    // 週ラベル（月の変わり目を表示）
    final weekLabels = <String>[];
    for (int w = 0; w < totalWeeks; w++) {
      final weekStart = startMonday.add(Duration(days: w * 7));
      // 週の開始が月の1〜7日なら月名を表示
      if (weekStart.day <= 7) {
        weekLabels.add('${weekStart.month}月');
      } else {
        weekLabels.add('');
      }
    }

    final cellSize = _calcCellSize(context, totalWeeks);
    final gap = (cellSize * 0.15).clamp(1.0, 3.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 凡例
        _buildLegend(context),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 曜日ラベル列
              Column(
                children: [
                  SizedBox(height: cellSize + gap), // 月ラベル行の高さ
                  for (int d = 0; d < 7; d++)
                    Container(
                      height: cellSize + gap,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 18,
                        child: Text(
                          _dayLabels[d],
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textSubColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // ヒートマップ本体
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 月ラベル行
                  Row(
                    children: [
                      for (int w = 0; w < totalWeeks; w++)
                        SizedBox(
                          width: cellSize + gap,
                          height: cellSize + gap,
                          child: weekLabels[w].isNotEmpty
                              ? Text(
                                  weekLabels[w],
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: context.textSubColor,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
                  // セルグリッド
                  for (int d = 0; d < 7; d++)
                    Row(
                      children: [
                        for (int w = 0; w < totalWeeks; w++)
                          _buildCell(
                            context,
                            startMonday.add(Duration(days: w * 7 + d)),
                            moodMap,
                            cellSize,
                            gap,
                            lastDate,
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calcCellSize(BuildContext context, int totalWeeks) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 左マージン(16) + カード内パディング(32) + 曜日ラベル(18) + 余白
    final available = screenWidth - 16 * 2 - 32 - 18 - 8;
    final size = available / totalWeeks - 2;
    return size.clamp(10.0, 18.0);
  }

  Widget _buildCell(
    BuildContext context,
    DateTime date,
    Map<String, int> moodMap,
    double size,
    double gap,
    DateTime lastDate,
  ) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final mood = moodMap[key];

    // 未来の日付は空白
    if (date.isAfter(lastDate)) {
      return SizedBox(width: size + gap, height: size + gap);
    }

    Color cellColor;
    if (mood == null) {
      cellColor = context.isDark
          ? Colors.white.withAlpha(15)
          : Colors.grey.withAlpha(30);
    } else {
      cellColor = _moodColor(context, mood);
    }

    return Padding(
      padding: EdgeInsets.all(gap / 2),
      child: Tooltip(
        message: mood != null ? '$key: 体調 $mood' : '$key: 未記録',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Color _moodColor(BuildContext context, int mood) {
    return context.moodColor(mood);
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      children: [
        Text('不調', style: TextStyle(fontSize: 10, color: context.textSubColor)),
        const SizedBox(width: 4),
        for (int m = 1; m <= 5; m++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _moodColor(context, m),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 4),
        Text('好調', style: TextStyle(fontSize: 10, color: context.textSubColor)),
        const Spacer(),
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: context.isDark
                ? Colors.white.withAlpha(15)
                : Colors.grey.withAlpha(30),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text('未記録', style: TextStyle(fontSize: 10, color: context.textSubColor)),
      ],
    );
  }

  DateTime? _parseDate(String dateKey) {
    try {
      final parts = dateKey.split('-');
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }
}
