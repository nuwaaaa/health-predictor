import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/mood_selector.dart';
import '../widgets/chart_7days.dart';
import '../widgets/status_banner.dart';
import '../widgets/prediction_card.dart';
import 'daily_input_page.dart';

/// ホームタブ — Calm Blue デザイン
class HomePage extends StatefulWidget {
  final FirestoreService service;
  final DailyLog? todayLog;
  final ModelStatus status;
  final Prediction? prediction;
  final Prediction? tomorrowPrediction;
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
    this.tomorrowPrediction,
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
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: RefreshIndicator(
        onRefresh: widget.onReload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // --- (1) 今日の予測カード ---
              PredictionCard(
                prediction: widget.prediction,
                isFallback: widget.isFallbackPrediction,
                status: widget.status,
                onTap: () => widget.onSwitchTab(2),
              ),

              // --- (1b) 明日の予測カード ---
              if (widget.tomorrowPrediction != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PredictionCard(
                  prediction: widget.tomorrowPrediction,
                  isFallback: false,
                  status: widget.status,
                  titleOverride: '明日の不調リスク',
                  onTap: () => widget.onSwitchTab(2),
                ),
              ],

              // --- (1c) 3日以内リスクカード ---
              if (widget.prediction != null &&
                  widget.status.ready) ...[
                if (widget.prediction!.p3d != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PredictionCard(
                    prediction: widget.prediction,
                    isFallback: false,
                    status: widget.status,
                    isP3d: true,
                    onTap: () => widget.onSwitchTab(2),
                  ),
                ] else if (widget.status.daysCollected >= 14) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _threeDayLockedCard(),
                ],
              ],

              const SizedBox(height: AppSpacing.lg),

              // --- (2) 体調入力 ---
              Text('今日の体調は？', style: AppTextStyles.section),
              const SizedBox(height: AppSpacing.sm),
              MoodSelector(
                selected: widget.todayLog?.moodScore,
                enabled: !_savingMood,
                onSelect: _onMoodSelected,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_savingMood)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
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
                    style: AppTextStyles.caption,
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // --- (3) 今日の記録サマリー ---
              _todaySummaryCard(),

              const SizedBox(height: AppSpacing.md),

              // --- (4) ステータスバナー ---
              StatusBanner(status: widget.status),

              const SizedBox(height: AppSpacing.lg),

              // --- (5) 直近7日ミニカード → データへ ---
              _mini7DaysSection(),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  /// 直近7日ミニセクション
  Widget _mini7DaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '直近7日',
          actionLabel: 'データへ',
          onAction: () => widget.onSwitchTab(1),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Chart7Days(logs: widget.last7),
        ),
      ],
    );
  }

  /// 3日以内リスク未開放カード
  Widget _threeDayLockedCard() {
    final need60 = widget.status.daysCollected < 60;
    String message;
    if (need60) {
      message = '3日以内予測はあと ${60 - widget.status.daysCollected} 日で開放';
    } else if (widget.status.unhealthyCount < 10) {
      message = '3日以内予測：準備中';
    } else {
      message = '3日以内予測：まもなく開放';
    }
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: AppColors.textSub),
          const SizedBox(width: 8),
          Text(message, style: AppTextStyles.captionSmall),
        ],
      ),
    );
  }

  /// 今日の記録サマリー
  Widget _todaySummaryCard() {
    final log = widget.todayLog;
    final hasSleep = log?.sleep?.durationHours != null;
    final hasSteps = log?.steps != null;
    final hasStress = log?.stress != null;

    return AppCard(
      onTap: _openDailyInput,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日の記録',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MetricChipsRow(
                  chips: [
                    MetricChipData(
                      label: '睡眠',
                      value: hasSleep
                          ? '${log!.sleep!.durationHours!.toStringAsFixed(1)}h'
                          : '未入力',
                      filled: hasSleep,
                    ),
                    MetricChipData(
                      label: '歩数',
                      value: hasSteps ? '${log!.steps}歩' : '未入力',
                      filled: hasSteps,
                    ),
                    MetricChipData(
                      label: 'ストレス',
                      value: hasStress ? 'Lv${log!.stress}' : '未入力',
                      filled: hasStress,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSub),
        ],
      ),
    );
  }
}
