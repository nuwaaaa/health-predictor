import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/firestore_service.dart';
import '../services/health_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/mood_selector.dart';

/// 日次データ入力・編集画面
class DailyInputPage extends StatefulWidget {
  final FirestoreService service;
  final DailyLog? todayLog;
  final VoidCallback onSaved;
  final String? dateKey;
  final bool readOnly;

  const DailyInputPage({
    super.key,
    required this.service,
    required this.todayLog,
    required this.onSaved,
    this.dateKey,
    this.readOnly = false,
  });

  @override
  State<DailyInputPage> createState() => _DailyInputPageState();
}

class _DailyInputPageState extends State<DailyInputPage> {
  final _healthService = HealthDataService();

  int? _moodScore;
  TimeOfDay? _bedTime;
  TimeOfDay? _wakeTime;
  final _stepsController = TextEditingController();
  int? _stress;
  bool _saving = false;
  bool _saved = false;
  bool _importingSteps = false;
  bool _importingSleep = false;

  bool _stepsFromAuto = false;
  bool _sleepFromAuto = false;

  /// 追加の睡眠セグメント（仮眠・分割睡眠用）
  final List<_NapEntry> _napEntries = [];
  /// 自動取得した全セグメント（保存時に使用）
  List<SleepSegment>? _autoSegments;

  bool get _isEditingPast => widget.dateKey != null;
  String get _targetDateKey => widget.dateKey ?? FirestoreService.todayKey();

  /// 対象日を DateTime で返す（HealthKit クエリ用）
  DateTime get _targetDate {
    if (widget.dateKey != null) {
      try {
        return DateTime.parse(widget.dateKey!);
      } catch (_) {}
    }
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    final log = widget.todayLog;
    if (log == null) return;

    _moodScore = log.moodScore;

    if (log.sleep?.bedTime != null) {
      _bedTime = _parseTime(log.sleep!.bedTime!);
    }
    if (log.sleep?.wakeTime != null) {
      _wakeTime = _parseTime(log.sleep!.wakeTime!);
    }
    if (log.sleep?.source == 'auto') {
      _sleepFromAuto = true;
    }
    if (log.steps != null) {
      _stepsController.text = log.steps.toString();
    }
    if (log.stepsSource == 'auto') {
      _stepsFromAuto = true;
    }
    _stress = log.stress;

    // 既存の仮眠セグメントを復元（主睡眠以外のセグメント）
    if (log.sleepSegments.length > 1 && log.sleepSummary != null) {
      for (final seg in log.sleepSegments) {
        final segStart = seg.startTime;
        final segEnd = seg.endTime;
        // 主睡眠（最長ブロック）以外を仮眠として追加
        if (segStart != log.sleepSummary!.longestBlockStart ||
            segEnd != log.sleepSummary!.longestBlockEnd) {
          final start = _parseTime(segStart);
          final end = _parseTime(segEnd);
          if (start != null && end != null) {
            _napEntries.add(_NapEntry(start: start, end: end));
          }
        }
      }
    }
  }

  TimeOfDay? _parseTime(String hhmm) {
    try {
      final parts = hhmm.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  double? get _sleepDuration {
    if (_bedTime == null || _wakeTime == null) return null;
    return SleepData.calcDuration(
      _formatTime(_bedTime!),
      _formatTime(_wakeTime!),
    );
  }

  Future<void> _pickTime(bool isBed) async {
    if (widget.readOnly) return;
    final initial = isBed
        ? (_bedTime ?? const TimeOfDay(hour: 23, minute: 0))
        : (_wakeTime ?? const TimeOfDay(hour: 7, minute: 0));

    if (Platform.isAndroid) {
      final picked = await showTimePicker(
        context: context,
        initialTime: initial,
        helpText: isBed ? '就寝時刻' : '起床時刻',
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _sleepFromAuto = false;
          if (isBed) {
            _bedTime = picked;
          } else {
            _wakeTime = picked;
          }
        });
      }
      return;
    }

    // iOS: CupertinoDatePicker
    TimeOfDay temp = initial;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: 260,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGroupedBackground
                      .resolveFrom(context),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFBCBBC1), width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('キャンセル'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(isBed ? '就寝時刻' : '起床時刻',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('完了'),
                      onPressed: () {
                        setState(() {
                          _sleepFromAuto = false;
                          if (isBed) {
                            _bedTime = temp;
                          } else {
                            _wakeTime = temp;
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(
                      2000, 1, 1, initial.hour, initial.minute),
                  onDateTimeChanged: (dt) {
                    temp = TimeOfDay(hour: dt.hour, minute: dt.minute);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importSteps() async {
    setState(() => _importingSteps = true);
    try {
      final granted = await _healthService.requestPermissions();
      if (!granted) {
        _showError('ヘルスケアへのアクセスが許可されていません');
        return;
      }

      final steps = await _healthService.fetchTodaySteps(
        date: _isEditingPast ? _targetDate : null,
      );
      if (steps == null || steps == 0) {
        _showError('歩数データが見つかりませんでした');
        return;
      }

      setState(() {
        _stepsController.text = steps.toString();
        _stepsFromAuto = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$steps 歩を取得しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('歩数取得失敗: $e');
      _showError('歩数の取得に失敗しました');
    } finally {
      if (mounted) setState(() => _importingSteps = false);
    }
  }

  Future<void> _importSleep() async {
    setState(() => _importingSleep = true);
    try {
      final granted = await _healthService.requestPermissions();
      if (!granted) {
        _showError('ヘルスケアへのアクセスが許可されていません');
        return;
      }

      final segments = await _healthService.fetchSleepSegments(
        date: _isEditingPast ? _targetDate : null,
      );
      if (segments.isEmpty) {
        _showError('睡眠データが見つかりませんでした');
        return;
      }

      final summary = SleepSummary.fromSegments(segments);
      if (summary.longestBlockMin <= 0) {
        _showError('睡眠データが見つかりませんでした');
        return;
      }

      setState(() {
        _autoSegments = segments;
        if (summary.longestBlockStart != null) {
          _bedTime = _parseTime(summary.longestBlockStart!);
        }
        if (summary.longestBlockEnd != null) {
          _wakeTime = _parseTime(summary.longestBlockEnd!);
        }
        _sleepFromAuto = true;

        // 仮眠セグメントを復元
        _napEntries.clear();
        if (summary.segmentCount > 1) {
          for (final seg in segments) {
            final segStart = seg.startTime;
            final segEnd = seg.endTime;
            if (segStart != summary.longestBlockStart ||
                segEnd != summary.longestBlockEnd) {
              final start = _parseTime(segStart);
              final end = _parseTime(segEnd);
              if (start != null && end != null) {
                _napEntries.add(_NapEntry(start: start, end: end));
              }
            }
          }
        }
      });

      if (mounted) {
        final totalH = (summary.totalSleepMin / 60.0).toStringAsFixed(1);
        final napInfo = summary.napTotalMin > 0
            ? '（うち仮眠 ${summary.napTotalMin}分）'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('睡眠 ${totalH}h$napInfo を取得しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('睡眠データ取得失敗: $e');
      _showError('睡眠データの取得に失敗しました');
    } finally {
      if (mounted) setState(() => _importingSleep = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final dateKey = _isEditingPast ? _targetDateKey : null;

      if (_isEditingPast && _moodScore != null) {
        await widget.service.saveMoodScoreForDate(_targetDateKey, _moodScore!);
      }

      if (_bedTime != null && _wakeTime != null) {
        final bed = _formatTime(_bedTime!);
        final wake = _formatTime(_wakeTime!);
        final dur = _sleepDuration;
        if (dur != null && dur > 0 && dur <= 24) {
          // セグメントを構築して保存
          final segments = _buildSleepSegments(bed, wake, dur);
          await widget.service.saveSleepSegments(
            segments: segments,
            dateKeyOverride: dateKey,
          );
        } else if (dur != null) {
          _showError('睡眠時間が不正です（0〜24時間）');
          return;
        }
      }

      final stepsText = _stepsController.text.trim();
      if (stepsText.isNotEmpty) {
        final steps = int.tryParse(stepsText);
        if (steps == null || steps < 0 || steps > 200000) {
          _showError('歩数が不正です（0〜200,000）');
          return;
        }
        await widget.service.saveSteps(
          steps,
          source: _stepsFromAuto ? 'auto' : 'manual',
          dateKeyOverride: dateKey,
        );
      }

      if (_stress != null) {
        await widget.service.saveStress(_stress!, dateKeyOverride: dateKey);
      }

      widget.onSaved();
      if (mounted) {
        setState(() => _saved = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('データ保存失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました。しばらくしてから再度お試しください')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 主睡眠 + 仮眠エントリからセグメントリストを構築する
  List<SleepSegment> _buildSleepSegments(String bed, String wake, double dur) {
    // 自動取得された完全なセグメントがある場合はそれを使用
    if (_autoSegments != null && _autoSegments!.isNotEmpty && _sleepFromAuto) {
      return _autoSegments!;
    }

    final now = DateTime.now();
    final segments = <SleepSegment>[];

    // 主睡眠セグメント
    final bedParts = bed.split(':');
    final wakeParts = wake.split(':');
    final bedHour = int.parse(bedParts[0]);
    final bedMin = int.parse(bedParts[1]);
    final wakeHour = int.parse(wakeParts[0]);
    final wakeMin = int.parse(wakeParts[1]);

    // 就寝日を推定（起床が今日なら就寝は昨日or今日）
    var bedDate = DateTime(now.year, now.month, now.day, bedHour, bedMin);
    final wakeDate = DateTime(now.year, now.month, now.day, wakeHour, wakeMin);
    if (bedDate.isAfter(wakeDate)) {
      bedDate = bedDate.subtract(const Duration(days: 1));
    }

    segments.add(SleepSegment(
      start: bedDate.toIso8601String(),
      end: wakeDate.toIso8601String(),
      minutes: (dur * 60).round(),
      source: _sleepFromAuto ? 'auto' : 'manual',
    ));

    // 仮眠セグメント
    for (final nap in _napEntries) {
      final napStart = DateTime(now.year, now.month, now.day, nap.start.hour, nap.start.minute);
      final napEnd = DateTime(now.year, now.month, now.day, nap.end.hour, nap.end.minute);
      final napMinutes = napEnd.difference(napStart).inMinutes;
      if (napMinutes > 0 && napMinutes <= 24 * 60) {
        segments.add(SleepSegment(
          start: napStart.toIso8601String(),
          end: napEnd.toIso8601String(),
          minutes: napMinutes,
          source: 'manual',
        ));
      }
    }

    return segments;
  }

  void _addNap() {
    setState(() {
      _napEntries.add(_NapEntry(
        start: const TimeOfDay(hour: 13, minute: 0),
        end: const TimeOfDay(hour: 13, minute: 30),
      ));
    });
  }

  void _removeNap(int index) {
    setState(() => _napEntries.removeAt(index));
  }

  Future<void> _pickNapTime(int index, bool isStart) async {
    if (widget.readOnly) return;
    final nap = _napEntries[index];
    final initial = isStart ? nap.start : nap.end;

    if (Platform.isAndroid) {
      final picked = await showTimePicker(
        context: context,
        initialTime: initial,
        helpText: isStart ? '仮眠開始' : '仮眠終了',
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          if (isStart) {
            _napEntries[index] = _NapEntry(start: picked, end: nap.end);
          } else {
            _napEntries[index] = _NapEntry(start: nap.start, end: picked);
          }
          _autoSegments = null; // 手動変更されたのでリセット
        });
      }
      return;
    }

    // iOS: CupertinoDatePicker
    TimeOfDay temp = initial;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: 260,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGroupedBackground
                      .resolveFrom(context),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFBCBBC1), width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('キャンセル'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(isStart ? '仮眠開始' : '仮眠終了',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('完了'),
                      onPressed: () {
                        setState(() {
                          if (isStart) {
                            _napEntries[index] =
                                _NapEntry(start: temp, end: nap.end);
                          } else {
                            _napEntries[index] =
                                _NapEntry(start: nap.start, end: temp);
                          }
                          _autoSegments = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime:
                      DateTime(2000, 1, 1, initial.hour, initial.minute),
                  onDateTimeChanged: (dt) {
                    temp = TimeOfDay(hour: dt.hour, minute: dt.minute);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _importingSteps = false;
      _importingSleep = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dur = _sleepDuration;
    final isReadOnly = widget.readOnly;

    final String title;
    if (isReadOnly) {
      title = '$_targetDateKey の記録';
    } else if (_isEditingPast) {
      title = '$_targetDateKey を編集';
    } else {
      title = '今日の記録';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 体調スコア ---
              if (_isEditingPast || isReadOnly) ...[
                Text('体調スコア', style: AppTextStyles.section),
                const SizedBox(height: AppSpacing.sm),
                IgnorePointer(
                  ignoring: isReadOnly,
                  child: Opacity(
                    opacity: isReadOnly ? 0.5 : 1.0,
                    child: MoodSelector(
                      selected: _moodScore,
                      enabled: !isReadOnly,
                      onSelect: (score) => setState(() => _moodScore = score),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // --- 睡眠 ---
              Row(
                children: [
                  Text('睡眠', style: AppTextStyles.section),
                  const Spacer(),
                  if (!isReadOnly)
                    _autoImportButton(
                      label: '自動取得',
                      loading: _importingSleep,
                      onTap: _importingSleep ? null : _importSleep,
                      isAuto: _sleepFromAuto,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              IgnorePointer(
                ignoring: isReadOnly,
                child: Opacity(
                  opacity: isReadOnly ? 0.5 : 1.0,
                  child: Row(
                    children: [
                      Expanded(
                        child: _timeButton(
                          label: '就寝',
                          time: _bedTime,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _timeButton(
                          label: '起床',
                          time: _wakeTime,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (dur != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '睡眠時間：${dur.toStringAsFixed(1)} 時間',
                  style: TextStyle(
                    fontSize: 15,
                    color: dur < 6 ? AppColors.destructive : context.textMainColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // --- 仮眠セグメント ---
              const SizedBox(height: AppSpacing.md),
              ..._napEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final nap = entry.value;
                final napDur = SleepData.calcDuration(
                  _formatTime(nap.start), _formatTime(nap.end));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text('仮眠${index + 1}', style: AppTextStyles.captionSmall),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _timeButton(
                          label: '開始',
                          time: nap.start,
                          onTap: () => _pickNapTime(index, true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _timeButton(
                          label: '終了',
                          time: nap.end,
                          onTap: () => _pickNapTime(index, false),
                        ),
                      ),
                      if (napDur != null) ...[
                        const SizedBox(width: 4),
                        Text('${(napDur * 60).round()}分',
                            style: AppTextStyles.captionSmall),
                      ],
                      if (!isReadOnly)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeNap(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                );
              }),
              if (!isReadOnly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addNap,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('仮眠を追加', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              // --- 歩数 ---
              Row(
                children: [
                  Text('歩数', style: AppTextStyles.section),
                  const Spacer(),
                  if (!isReadOnly)
                    _autoImportButton(
                      label: '自動取得',
                      loading: _importingSteps,
                      onTap: _importingSteps ? null : _importSteps,
                      isAuto: _stepsFromAuto,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              IgnorePointer(
                ignoring: isReadOnly,
                child: Opacity(
                  opacity: isReadOnly ? 0.5 : 1.0,
                  child: TextField(
                    controller: _stepsController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (_stepsFromAuto) {
                        setState(() => _stepsFromAuto = false);
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: '例: 8000',
                      suffixText: '歩',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // --- ストレス ---
              Text('ストレス（任意）', style: AppTextStyles.section),
              const SizedBox(height: AppSpacing.sm),
              IgnorePointer(
                ignoring: isReadOnly,
                child: Opacity(
                  opacity: isReadOnly ? 0.5 : 1.0,
                  child: Row(
                    children: List.generate(5, (i) {
                      final v = i + 1;
                      final selected = _stress == v;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                          child: GestureDetector(
                            onTap: isReadOnly
                                ? null
                                : () => setState(() {
                                      _stress = selected ? null : v;
                                    }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? context.cautionSoftColor
                                    : context.cardColor,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.button),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.chartOrange
                                      : context.dividerColor,
                                  width: selected ? 2 : 1.5,
                                ),
                                boxShadow: context.isDark ? null : AppShadows.card,
                              ),
                              child: Center(
                                child: Text(
                                  '$v',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selected
                                        ? context.textMainColor
                                        : context.textSubColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('低い', style: AppTextStyles.captionSmall),
                  Text('高い', style: AppTextStyles.captionSmall),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // --- 保存 ---
              if (isReadOnly)
                Center(
                  child: Text(
                    '4日以上前のデータは編集できません',
                    style: AppTextStyles.caption,
                  ),
                )
              else if (_saved)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 48, color: AppColors.chartGreen),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('保存しました', style: AppTextStyles.caption),
                    ],
                  ),
                )
              else
                PrimaryButton(
                  label: '保存する',
                  loading: _saving,
                  onPressed: _save,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _autoImportButton({
    required String label,
    required bool loading,
    required VoidCallback? onTap,
    required bool isAuto,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAuto
              ? context.colorWithAdaptiveAlpha(context.chartGreenColor, 30)
              : context.primaryTintColor,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isAuto
                ? context.chartGreenColor
                : context.primaryWithAlpha(80),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (isAuto)
              Icon(Icons.check_circle, size: 14,
                  color: context.autoImportTextColor)
            else
              Icon(Icons.download_rounded, size: 14,
                  color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              isAuto ? '取得済み' : label,
              style: TextStyle(
                fontSize: 12,
                color: isAuto
                    ? context.autoImportTextColor
                    : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeButton({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: context.dividerColor, width: 1.5),
          boxShadow: context.isDark ? null : AppShadows.card,
        ),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.captionSmall.copyWith(color: context.textSubColor)),
            const SizedBox(height: 4),
            Text(
              time != null ? _formatTime(time) : '--:--',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textMainColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 仮眠エントリ（UI用の一時データ）
class _NapEntry {
  final TimeOfDay start;
  final TimeOfDay end;
  _NapEntry({required this.start, required this.end});
}
