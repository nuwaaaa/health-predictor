import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../services/firestore_service.dart';
import '../widgets/mood_selector.dart';
import '../widgets/chart_7days.dart';
import '../widgets/status_banner.dart';
import '../widgets/prediction_card.dart';
import 'daily_input_page.dart';

/// ホームタブ: 予測カード、体調入力、記録サマリー、ステータス、
/// 要因/アドバイス要約、直近7日ミニカード
class HomePage extends StatefulWidget {
  final FirestoreService service;
  final DailyLog? todayLog;
  final ModelStatus status;
  final Prediction? prediction;
  final bool isFallbackPrediction;
  final List<DailyLog> last7;
  final Future<void> Function() onReload;
  final void Function(int tabIndex) onSwitchTab;

  const HomePage({
    super.key,
    required this.service,
    required this.todayLog,
    required this.status,
    required this.prediction,
    this.isFallbackPrediction = false,
    required this.last7,
    required this.onReload,
    required this.onSwitchTab,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _savingMood = false;

  Future<void> _onMoodSelected(int score) async {
    setState(() => _savingMood = true);
    try {
      await widget.service.saveMoodScore(score);
      await widget.onReload();
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
      if (mounted) setState(() => _savingMood = false);
    }
  }

  void _openDailyInput() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyInputPage(
          service: widget.service,
          todayLog: widget.todayLog,
          onSaved: widget.onReload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onReload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),

            // --- (1) 予測カード ---
            PredictionCard(
              prediction: widget.prediction,
              isFallback: widget.isFallbackPrediction,
              status: widget.status,
            ),

            const SizedBox(height: 20),

            // --- (2) 体調入力 ---
            const Text('今日の体調は？',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            MoodSelector(
              selected: widget.todayLog?.moodScore,
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
                  widget.todayLog?.moodScore != null
                      ? 'スコア：${widget.todayLog!.moodScore}'
                      : '未入力',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),

            const SizedBox(height: 16),

            // --- (3) 今日の記録サマリー ---
            _todaySummaryCard(),

            const SizedBox(height: 16),

            // --- (4) ステータスバナー ---
            StatusBanner(status: widget.status),

            const SizedBox(height: 20),

            // --- (5) 要因TOP3・アドバイス（要約） → もっと見る → 分析タブ ---
            if (widget.prediction != null &&
                widget.prediction!.pToday != null &&
                (widget.prediction!.contributions.isNotEmpty ||
                    widget.prediction!.advices.isNotEmpty)) ...[
              _summaryInsights(),
              const SizedBox(height: 20),
            ],

            // --- (6) 直近7日ミニカード → データへ ---
            _mini7DaysSection(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// 要因・アドバイスの要約（ホーム用）
  Widget _summaryInsights() {
    final pred = widget.prediction!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pred.contributions.isNotEmpty) ...[
            const Text('予測の主な要因',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...pred.contributions.take(3).map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                        c.isRiskIncrease
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: c.isRiskIncrease
                            ? Colors.red.shade400
                            : Colors.green.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(c.label, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
          ],
          if (pred.advices.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 14, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pred.advices.first.message,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => widget.onSwitchTab(2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('もっと見る',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.blue.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 直近7日ミニセクション + 「データへ」リンク
  Widget _mini7DaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('直近7日',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: () => widget.onSwitchTab(1),
              child: Row(
                children: [
                  Text('データへ',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.blue.shade700),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Chart7Days(logs: widget.last7),
      ],
    );
  }

  /// 今日の睡眠・歩数・ストレスのサマリーカード
  Widget _todaySummaryCard() {
    final log = widget.todayLog;
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
