import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/firestore_service.dart';

class DailyInputPage extends StatefulWidget {
  final FirestoreService service;
  final DailyLog? todayLog;
  final VoidCallback onSaved;

  const DailyInputPage({
    super.key,
    required this.service,
    required this.todayLog,
    required this.onSaved,
  });

  @override
  State<DailyInputPage> createState() => _DailyInputPageState();
}

class _DailyInputPageState extends State<DailyInputPage> {
  TimeOfDay? _bedTime;
  TimeOfDay? _wakeTime;
  final _stepsController = TextEditingController();
  int? _stress;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    final log = widget.todayLog;
    if (log == null) return;

    if (log.sleep?.bedTime != null) {
      _bedTime = _parseTime(log.sleep!.bedTime!);
    }
    if (log.sleep?.wakeTime != null) {
      _wakeTime = _parseTime(log.sleep!.wakeTime!);
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
        if (isBed) {
          _bedTime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
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
        await widget.service.saveSteps(steps);
      }

      // ストレス
      if (_stress != null) {
        await widget.service.saveStress(_stress!);
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
    setState(() => _saving = false);
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

    return Scaffold(
      appBar: AppBar(title: const Text('今日の記録')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 睡眠 ---
              const Text('睡眠',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
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
              const Text('歩数',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _stepsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '例: 8000',
                  suffixText: '歩',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 28),

              // --- ストレス（任意）---
              const Text('ストレス（任意）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (i) {
                  final v = i + 1;
                  final selected = _stress == v;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _stress = selected ? null : v; // タップで解除も可能
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
                              color: selected ? Colors.red : Colors.transparent,
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

              // --- 保存ボタン ---
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
