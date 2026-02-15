import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/firestore_service.dart';
import '../services/health_data_service.dart';
import '../widgets/mood_selector.dart';

/// 日次データ入力・編集画面
///
/// - dateKey == null → 今日の詳細入力（睡眠・歩数・ストレスのみ、体調はホームで入力済み）
/// - dateKey != null → 過去データ編集（体調・睡眠・歩数・ストレス全項目）
/// - readOnly == true → 閲覧のみ（4日以上前）
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
  bool _importingSteps = false;
  bool _importingSleep = false;

  bool _stepsFromAuto = false;
  bool _sleepFromAuto = false;

  bool get _isEditingPast => widget.dateKey != null;
  String get _targetDateKey => widget.dateKey ?? FirestoreService.todayKey();

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
    _stress = log.stress;
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

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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
  }

  /// HealthKit / Health Connect から歩数を自動取得
  Future<void> _importSteps() async {
    setState(() => _importingSteps = true);
    try {
      final granted = await _healthService.requestPermissions();
      if (!granted) {
        _showError('ヘルスケアへのアクセスが許可されていません');
        return;
      }

      final steps = await _healthService.fetchTodaySteps();
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
      _showError('歩数の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _importingSteps = false);
    }
  }

  /// HealthKit / Health Connect から睡眠データを自動取得
  Future<void> _importSleep() async {
    setState(() => _importingSleep = true);
    try {
      final granted = await _healthService.requestPermissions();
      if (!granted) {
        _showError('ヘルスケアへのアクセスが許可されていません');
        return;
      }

      final sleepData = await _healthService.fetchLastNightSleep();
      if (sleepData == null) {
        _showError('睡眠データが見つかりませんでした');
        return;
      }

      final bedStr = sleepData['bedTime'] as String;
      final wakeStr = sleepData['wakeTime'] as String;
      final dur = sleepData['durationHours'] as double;

      setState(() {
        _bedTime = _parseTime(bedStr);
        _wakeTime = _parseTime(wakeStr);
        _sleepFromAuto = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('睡眠 ${dur.toStringAsFixed(1)}h を取得しました'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('睡眠データの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _importingSleep = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final dateKey = _isEditingPast ? _targetDateKey : null;

      // 体調スコア（過去データ編集時のみ）
      if (_isEditingPast && _moodScore != null) {
        await widget.service.saveMoodScoreForDate(_targetDateKey, _moodScore!);
      }

      // 睡眠
      if (_bedTime != null && _wakeTime != null) {
        final bed = _formatTime(_bedTime!);
        final wake = _formatTime(_wakeTime!);
        final dur = _sleepDuration;
        if (dur != null && dur > 0 && dur <= 24) {
          await widget.service.saveSleep(
            bedTime: bed,
            wakeTime: wake,
            durationHours: dur,
            source: _sleepFromAuto ? 'auto' : 'manual',
            dateKeyOverride: dateKey,
          );
        } else if (dur != null) {
          _showError('睡眠時間が不正です（0〜24時間）');
          return;
        }
      }

      // 歩数
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

      // ストレス
      if (_stress != null) {
        await widget.service.saveStress(_stress!, dateKeyOverride: dateKey);
      }

      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('保存しました'), duration: Duration(seconds: 2)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 体調スコア（過去データ編集 or 閲覧時のみ表示）---
              if (_isEditingPast || isReadOnly) ...[
                const Text('体調スコア',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
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
                const SizedBox(height: 28),
              ],

              // --- 睡眠 ---
              Row(
                children: [
                  const Text('睡眠',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (!isReadOnly && !_isEditingPast)
                    _autoImportButton(
                      label: '自動取得',
                      loading: _importingSleep,
                      onTap: _importingSleep ? null : _importSleep,
                      isAuto: _sleepFromAuto,
                    ),
                ],
              ),
              const SizedBox(height: 12),
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
                      const SizedBox(width: 12),
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
                const SizedBox(height: 8),
                Text(
                  '睡眠時間：${dur.toStringAsFixed(1)} 時間',
                  style: TextStyle(
                    fontSize: 15,
                    color: dur < 6 ? Colors.red : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // --- 歩数 ---
              Row(
                children: [
                  const Text('歩数',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (!isReadOnly && !_isEditingPast)
                    _autoImportButton(
                      label: '自動取得',
                      loading: _importingSteps,
                      onTap: _importingSteps ? null : _importSteps,
                      isAuto: _stepsFromAuto,
                    ),
                ],
              ),
              const SizedBox(height: 12),
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
                    decoration: InputDecoration(
                      hintText: '例: 8000',
                      suffixText: '歩',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // --- ストレス（任意）---
              const Text('ストレス（任意）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
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
                                    ? Colors.red.shade100
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      selected ? Colors.red : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$v',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
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
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('低い',
                      style: TextStyle(fontSize: 11, color: Colors.black45)),
                  Text('高い',
                      style: TextStyle(fontSize: 11, color: Colors.black45)),
                ],
              ),

              const SizedBox(height: 36),

              // --- 保存 or 閲覧のみ表示 ---
              if (isReadOnly)
                const Center(
                  child: Text(
                    '4日以上前のデータは編集できません',
                    style: TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('保存する', style: TextStyle(fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 自動取得ボタン
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
          color: isAuto ? Colors.green.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAuto ? Colors.green.shade300 : Colors.blue.shade200,
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
              Icon(Icons.check_circle, size: 14, color: Colors.green.shade600)
            else
              Icon(Icons.download_rounded, size: 14, color: Colors.blue.shade600),
            const SizedBox(width: 4),
            Text(
              isAuto ? '取得済み' : label,
              style: TextStyle(
                fontSize: 12,
                color: isAuto ? Colors.green.shade700 : Colors.blue.shade700,
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              time != null ? _formatTime(time) : '--:--',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
