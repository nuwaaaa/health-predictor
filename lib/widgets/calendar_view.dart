import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';
import 'mood_selector.dart';

/// カレンダー形式で日次データを表示するウィジェット
class CalendarView extends StatefulWidget {
  final List<DailyLog> logs;
  final void Function(String dateKey, bool editable)? onTap;

  const CalendarView({super.key, required this.logs, this.onTap});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _currentMonth;
  String? _selectedDateKey;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  Map<String, DailyLog> get _logMap {
    final map = <String, DailyLog>{};
    for (final log in widget.logs) {
      map[log.dateKey] = log;
    }
    return map;
  }

  static bool _isEditable(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff =
          today.difference(DateTime(date.year, date.month, date.day)).inDays;
      return diff >= 0 && diff <= 3;
    } catch (_) {
      return false;
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _prevMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDateKey = null;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month + 1))) return;
    setState(() {
      _currentMonth = next;
      _selectedDateKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final logMap = _logMap;
    final selectedLog =
        _selectedDateKey != null ? logMap[_selectedDateKey] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: AppSpacing.sm),
        _buildWeekdayLabels(context),
        const SizedBox(height: AppSpacing.xs),
        _buildCalendarGrid(context, logMap),
        if (_selectedDateKey != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildDetailCard(context, _selectedDateKey!, selectedLog),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year &&
        _currentMonth.month == now.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 24),
          onPressed: _prevMonth,
          color: context.textSubColor,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        Text(
          '${_currentMonth.year}年${_currentMonth.month}月',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textMainColor,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 24),
          onPressed: isCurrentMonth ? null : _nextMonth,
          color: isCurrentMonth
              ? context.dividerColor
              : context.textSubColor,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(BuildContext context) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    return Row(
      children: labels.map((l) {
        return Expanded(
          child: Center(
            child: Text(
              l,
              style: AppTextStyles.captionSmall.copyWith(
                color: context.textSubColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(
      BuildContext context, Map<String, DailyLog> logMap) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Monday = 1 in Dart's weekday
    final firstWeekday = DateTime(year, month, 1).weekday;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cells = <Widget>[];

    // Blank cells before first day
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final key = _dateKey(date);
      final log = logMap[key];
      final isToday = date.isAtSameMomentAs(today);
      final isFuture = date.isAfter(today);
      final isSelected = _selectedDateKey == key;

      cells.add(_buildDayCell(context, day, key, log, isToday, isFuture, isSelected));
    }

    // Build rows of 7
    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      final end = (i + 7).clamp(0, cells.length);
      final rowCells = List<Widget>.from(cells.sublist(i, end));
      while (rowCells.length < 7) {
        rowCells.add(const SizedBox.shrink());
      }
      rows.add(
        Row(
          children:
              rowCells.map((c) => Expanded(child: c)).toList(),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(BuildContext context, int day, String dateKey,
      DailyLog? log, bool isToday, bool isFuture, bool isSelected) {
    final hasMood = log?.moodScore != null;
    final moodScore = log?.moodScore ?? 0;

    Color bgColor;
    Color textColor;
    if (isSelected) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isFuture) {
      bgColor = Colors.transparent;
      textColor = context.dividerColor;
    } else if (hasMood) {
      bgColor = _moodColor(context, moodScore);
      textColor = context.textMainColor;
    } else {
      bgColor = Colors.transparent;
      textColor = context.textSubColor;
    }

    return GestureDetector(
      onTap: isFuture
          ? null
          : () {
              setState(() {
                _selectedDateKey =
                    _selectedDateKey == dateKey ? null : dateKey;
              });
            },
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (hasMood && !isSelected)
              Text(
                MoodSelector.emojiFor(moodScore),
                style: const TextStyle(fontSize: 10),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Color _moodColor(BuildContext context, int score) {
    switch (score) {
      case 1:
        return context.colorWithAdaptiveAlpha(Colors.red, 25);
      case 2:
        return context.colorWithAdaptiveAlpha(AppColors.chartOrange, 30);
      case 3:
        return context.colorWithAdaptiveAlpha(AppColors.primary, 20);
      case 4:
        return context.colorWithAdaptiveAlpha(AppColors.chartGreen, 25);
      case 5:
        return context.colorWithAdaptiveAlpha(AppColors.chartGreen, 40);
      default:
        return Colors.transparent;
    }
  }

  Widget _buildDetailCard(
      BuildContext context, String dateKey, DailyLog? log) {
    final editable = _isEditable(dateKey);
    final isEmpty = log == null ||
        (log.moodScore == null &&
            log.sleep == null &&
            log.steps == null &&
            log.stress == null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateKey,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textMainColor,
                ),
              ),
              const Spacer(),
              if (widget.onTap != null)
                GestureDetector(
                  onTap: () => widget.onTap!(dateKey, editable),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: editable
                          ? AppColors.primaryTint
                          : context.bgColor,
                      borderRadius:
                          BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          editable
                              ? Icons.edit_outlined
                              : Icons.visibility_outlined,
                          size: 14,
                          color: editable
                              ? AppColors.primary
                              : context.textSubColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          editable ? '編集' : '詳細',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: editable
                                ? AppColors.primary
                                : context.textSubColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isEmpty)
            Text(
              editable ? 'まだ入力されていません。タップして入力しましょう' : 'データなし',
              style: TextStyle(
                fontSize: 13,
                color: editable
                    ? AppColors.chartOrange
                    : context.textSubColor,
              ),
            )
          else ...[
            // Mood
            if (log.moodScore != null)
              _detailRow(
                context,
                MoodSelector.emojiFor(log.moodScore!),
                '体調',
                '${log.moodScore}（${_moodLabel(log.moodScore!)}）',
              ),
            // Sleep
            if (log.sleep?.durationHours != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _detailRow(
                context,
                '🛏️',
                '睡眠',
                _sleepText(log),
              ),
            ],
            // Steps
            if (log.steps != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _detailRow(context, '👟', '歩数', '${log.steps}歩'),
            ],
            // Stress
            if (log.stress != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _detailRow(
                  context, '😰', 'ストレス', 'Lv${log.stress}'),
            ],
          ],
        ],
      ),
    );
  }

  String _sleepText(DailyLog log) {
    final sleep = log.sleep!;
    final dur = '${sleep.durationHours!.toStringAsFixed(1)}h';
    if (sleep.bedTime != null && sleep.wakeTime != null) {
      return '$dur（${sleep.bedTime} → ${sleep.wakeTime}）';
    }
    return dur;
  }

  String _moodLabel(int score) {
    const labels = ['', 'とても悪い', '悪い', '普通', '良い', 'とても良い'];
    return score >= 1 && score <= 5 ? labels[score] : '';
  }

  Widget _detailRow(
      BuildContext context, String icon, String label, String value) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: AppTextStyles.captionSmall.copyWith(
              color: context.textSubColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.textMainColor,
            ),
          ),
        ),
      ],
    );
  }
}
