import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';
import 'mood_selector.dart';

class DailyList extends StatelessWidget {
  final List<DailyLog> logs;
  final void Function(String dateKey, bool editable)? onTap;

  const DailyList({super.key, required this.logs, this.onTap});

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

  List<DailyLog> _fillMissingEditableDays(List<DailyLog> original) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existingKeys = original.map((l) => l.dateKey).toSet();

    final filled = List<DailyLog>.from(original);
    for (int i = 0; i <= 3; i++) {
      final date = today.subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (!existingKeys.contains(key)) {
        filled.add(DailyLog(dateKey: key));
      }
    }

    filled.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return filled;
  }

  @override
  Widget build(BuildContext context) {
    final filledLogs = _fillMissingEditableDays(logs);
    if (filledLogs.isEmpty) return const SizedBox.shrink();

    final reversed = filledLogs.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: reversed.map((log) {
        final m = log.moodScore ?? 0;
        final isEmpty = log.moodScore == null &&
            log.sleep == null &&
            log.steps == null &&
            log.stress == null;
        final emoji = isEmpty ? '' : MoodSelector.emojiFor(m);
        final sleepText = log.sleep?.durationHours != null
            ? '${log.sleep!.durationHours!.toStringAsFixed(1)}h'
            : '-';
        final stepsText = log.steps != null ? '${log.steps}歩' : '-';
        final editable = isEditable(log.dateKey);

        return GestureDetector(
          onTap: onTap != null ? () => onTap!(log.dateKey, editable) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isEmpty ? context.bgColor : context.cardColor,
              borderRadius: BorderRadius.circular(AppRadii.button),
              border: Border.all(
                color: isEmpty && editable
                    ? AppColors.cautionSoft2
                    : context.dividerColor,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(log.dateKey,
                      style: AppTextStyles.captionSmall.copyWith(color: context.textSubColor)),
                ),
                if (isEmpty)
                  Text(
                    editable ? '未入力' : '-',
                    style: TextStyle(
                      fontSize: 13,
                      color: editable
                          ? AppColors.chartOrange
                          : context.textSubColor,
                    ),
                  )
                else
                  Text('$emoji $m',
                      style: TextStyle(
                          fontSize: 16, color: context.textMainColor)),
                const Spacer(),
                if (!isEmpty) ...[
                  _miniLabel('🛏️', sleepText),
                  const SizedBox(width: 12),
                  _miniLabel('👟', stepsText),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    editable
                        ? Icons.edit_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                    color: editable ? AppColors.primary : context.textSubColor,
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
        Text(text, style: AppTextStyles.captionSmall),
      ],
    );
  }
}
