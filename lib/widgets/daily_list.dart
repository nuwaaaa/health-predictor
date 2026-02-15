import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import 'mood_selector.dart';

class DailyList extends StatelessWidget {
  final List<DailyLog> logs;

  /// 行タップ時のコールバック。(dateKey, editable) を渡す。
  final void Function(String dateKey, bool editable)? onTap;

  const DailyList({super.key, required this.logs, this.onTap});

  /// 直近3日以内（今日含む）なら編集可能
  static bool isEditable(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(DateTime(date.year, date.month, date.day)).inDays;
      return diff >= 0 && diff <= 3;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();

    final reversed = logs.reversed.toList(); // 新→古

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: reversed.map((log) {
        final m = log.moodScore ?? 0;
        final emoji = MoodSelector.emojiFor(m);
        final sleepText = log.sleep?.durationHours != null
            ? '${log.sleep!.durationHours!.toStringAsFixed(1)}h'
            : '-';
        final stepsText = log.steps != null ? '${log.steps}歩' : '-';
        final editable = isEditable(log.dateKey);

        return GestureDetector(
          onTap: onTap != null ? () => onTap!(log.dateKey, editable) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                // 日付
                SizedBox(
                  width: 90,
                  child: Text(log.dateKey,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54)),
                ),
                // 体調
                Text('$emoji $m', style: const TextStyle(fontSize: 16)),
                const Spacer(),
                // 睡眠
                _miniLabel('🛏️', sleepText),
                const SizedBox(width: 12),
                // 歩数
                _miniLabel('👟', stepsText),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    editable ? Icons.edit_outlined : Icons.visibility_outlined,
                    size: 16,
                    color: editable ? Colors.blue.shade400 : Colors.black26,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _miniLabel(String icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}
