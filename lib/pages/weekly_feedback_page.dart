import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// 週次フィードバックページ
/// 「先週の予報、実際はどうでした？」を1タップで回答
class WeeklyFeedbackPage extends StatefulWidget {
  final FirestoreService service;

  const WeeklyFeedbackPage({super.key, required this.service});

  @override
  State<WeeklyFeedbackPage> createState() => _WeeklyFeedbackPageState();
}

class _WeeklyFeedbackPageState extends State<WeeklyFeedbackPage> {
  bool _submitted = false;
  bool _saving = false;
  String? _alreadySubmittedWeek;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  String get _currentWeekKey {
    final now = DateTime.now();
    // ISO週番号ベースで週キーを生成
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return FirestoreService.dateKey(monday);
  }

  Future<void> _checkExisting() async {
    final latest = await widget.service.getLatestFeedbackWeek();
    if (latest == _currentWeekKey && mounted) {
      setState(() => _alreadySubmittedWeek = latest);
    }
  }

  Future<void> _submit(String result) async {
    setState(() => _saving = true);
    try {
      await widget.service.saveWeeklyFeedback(
        weekKey: _currentWeekKey,
        result: result,
      );
      setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信失敗: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('週次フィードバック')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _submitted || _alreadySubmittedWeek != null
              ? _buildDone()
              : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.feedback_outlined, size: 56, color: Colors.blueAccent),
        const SizedBox(height: 24),
        const Text(
          '先週の予報、\n実際はどうでした？',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          '1タップで教えてください。予測改善に役立ちます。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            Expanded(
              child: _feedbackButton(
                label: '当たった',
                icon: Icons.check_circle_outline,
                color: Colors.green,
                result: 'correct',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _feedbackButton(
                label: '外れた',
                icon: Icons.cancel_outlined,
                color: Colors.red,
                result: 'incorrect',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _feedbackButton(
                label: 'わからない',
                icon: Icons.help_outline,
                color: Colors.grey,
                result: 'unknown',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _feedbackButton({
    required String label,
    required IconData icon,
    required Color color,
    required String result,
  }) {
    return GestureDetector(
      onTap: _saving ? null : () => _submit(result),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
          const SizedBox(height: 20),
          const Text(
            '回答ありがとうございます！',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            '予測モデルの改善に活用します。',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ホームに戻る'),
          ),
        ],
      ),
    );
  }
}
