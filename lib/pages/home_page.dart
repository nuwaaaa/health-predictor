import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/mood_selector.dart';
import '../widgets/chart_7days.dart';
import '../widgets/daily_list.dart';
import '../widgets/status_banner.dart';
import '../widgets/prediction_card.dart';
import '../widgets/comparison_chart.dart';
import '../widgets/sleep_pattern_chart.dart';
import 'daily_input_page.dart';
import 'weekly_feedback_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  late final FirestoreService _service;

  bool _loading = true;
  bool _savingMood = false;

  DailyLog? _todayLog;
  ModelStatus _status = ModelStatus();
  Prediction? _prediction;
  List<DailyLog> _last7 = [];

  @override
  void initState() {
    super.initState();
    final uid = _authService.uid;
    if (uid == null) return;
    _service = FirestoreService(uid: uid);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getTodayLog(),
        _service.getModelStatus(),
        _service.getLastNDays(7),
        _service.getTodayPrediction(),
      ]);
      setState(() {
        _todayLog = results[0] as DailyLog?;
        _status = results[1] as ModelStatus;
        _last7 = results[2] as List<DailyLog>;
        _prediction = results[3] as Prediction?;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('読み込み失敗: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onMoodSelected(int score) async {
    setState(() => _savingMood = true);
    try {
      await _service.saveMoodScore(score);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('保存しました'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    } finally {
      setState(() => _savingMood = false);
    }
  }

  void _openDailyInput() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyInputPage(
          service: _service,
          todayLog: _todayLog,
          onSaved: _loadAll,
        ),
      ),
    );
  }

  /// 日次リストの行タップ → 過去データ編集/閲覧画面を開く
  void _openDailyEdit(String dateKey, bool editable) async {
    // 対象日のログを取得
    final log = await _service.getLogForDate(dateKey);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyInputPage(
          service: _service,
          todayLog: log,
          onSaved: _loadAll,
          dateKey: dateKey,
          readOnly: !editable,
        ),
      ),
    );
  }

  void _openWeeklyFeedback() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklyFeedbackPage(service: _service),
      ),
    );
  }

  Future<void> _showSeedDialog() async {
    final days = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('テストデータ作成'),
        children: [
          _seedOption(context, 7, '7日（学習中）'),
          _seedOption(context, 30, '30日（今日リスクのみ）'),
          _seedOption(context, 100, '100日（3日リスクも表示）'),
        ],
      ),
    );
    if (days != null) await _seedTestData(days);
  }

  Widget _seedOption(BuildContext context, int days, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, days),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _seedTestData(int days) async {
    setState(() => _savingMood = true);
    try {
      await _service.seedTestData(totalDays: days);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${days}日分のテストデータを作成しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成失敗: $e')),
        );
      }
    } finally {
      setState(() => _savingMood = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('体調予測'),
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined),
            tooltip: '週次フィードバック',
            onPressed: _openWeeklyFeedback,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'テストデータ作成',
            onPressed: _savingMood ? null : _showSeedDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),

                      // --- 予測カード ---
                      PredictionCard(
                        prediction: _prediction,
                        status: _status,
                      ),

                      const SizedBox(height: 20),

                      // --- 体調入力 ---
                      const Text('今日の体調は？',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      MoodSelector(
                        selected: _todayLog?.moodScore,
                        enabled: !_savingMood,
                        onSelect: _onMoodSelected,
                      ),
                      const SizedBox(height: 10),
                      if (_savingMood)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Text(
                            _todayLog?.moodScore != null
                                ? 'スコア：${_todayLog!.moodScore}'
                                : '未入力',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black54),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // --- 睡眠・歩数・ストレス入力ボタン ---
                      _todaySummaryCard(),

                      const SizedBox(height: 16),

                      // --- ステータス ---
                      StatusBanner(status: _status),

                      const SizedBox(height: 24),

                      // --- 直近7日 ---
                      const Text('直近7日',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Chart7Days(logs: _last7),
                      const SizedBox(height: 14),
                      DailyList(
                        logs: _last7,
                        onTap: _openDailyEdit,
                      ),

                      const SizedBox(height: 24),

                      // --- 体調×特徴量 比較グラフ ---
                      const Text('体調と生活データの比較',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ComparisonChart(logs: _last7),

                      const SizedBox(height: 24),

                      // --- 睡眠パターン ---
                      const Text('睡眠パターン',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SleepPatternChart(logs: _last7),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 今日の睡眠・歩数・ストレスのサマリーカード
  Widget _todaySummaryCard() {
    final log = _todayLog;
    final hasSleep = log?.sleep?.durationHours != null;
    final hasSteps = log?.steps != null;
    final hasStress = log?.stress != null;

    return GestureDetector(
      onTap: _openDailyInput,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('今日の記録',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _summaryChip(
                        '睡眠',
                        hasSleep
                            ? '${log!.sleep!.durationHours!.toStringAsFixed(1)}h'
                            : '未入力',
                        hasSleep,
                      ),
                      const SizedBox(width: 14),
                      _summaryChip(
                        '歩数',
                        hasSteps ? '${log!.steps}歩' : '未入力',
                        hasSteps,
                      ),
                      const SizedBox(width: 14),
                      _summaryChip(
                        'ストレス',
                        hasStress ? 'Lv${log!.stress}' : '未入力',
                        hasStress,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String text, bool filled) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: filled ? Colors.black54 : Colors.black26,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: filled ? Colors.black87 : Colors.black38,
          ),
        ),
      ],
    );
  }
}
