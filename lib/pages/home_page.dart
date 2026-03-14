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
      debugPrint('体調スコア保存失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました。しばらくしてから再度お試しください')),
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

              // --- (0) 入力促進バナー ---
              _inputProgressBanner(),

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
          Icon(Icons.lock_outline, size: 16, color: context.textSubColor),
          const SizedBox(width: 8),
          Text(message, style: AppTextStyles.captionSmall),
        ],
      ),
    );
  }

  /// 入力促進バナー
  Widget _inputProgressBanner() {
    final log = widget.todayLog;
    final hasMood = log?.moodScore != null;
    final hasSleep = log?.sleep?.durationHours != null;
    final hasSteps = log?.steps != null;
    final hasStress = log?.stress != null;

    final done = [hasMood, hasSleep, hasSteps, hasStress].where((b) => b).length;

    // 全入力済みなら非表示
    if (done == 4) return const SizedBox.shrink();

    // 体調未入力時は目立つCTA
    if (!hasMood) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: GestureDetector(
          onTap: () {}, // MoodSelectorへのスクロールはページ内なので不要
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withAlpha(30), AppColors.primary.withAlpha(10)],
              ),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日の体調を記録しましょう',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textMainColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '下のスコアをタップするだけ',
                        style: AppTextStyles.captionSmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_downward, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    // 体調入力済みだが他が未入力の場合
    final missing = <String>[];
    if (!hasSleep) missing.add('睡眠');
    if (!hasSteps) missing.add('歩数');
    if (!hasStress) missing.add('ストレス');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: _openDailyInput,
        child: AppCard(
          child: Row(
            children: [
              // プログレスインジケーター
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: done / 4,
                      strokeWidth: 3,
                      backgroundColor: context.dividerColor,
                      color: AppColors.chartGreen,
                    ),
                    Text(
                      '$done/4',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.textMainColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${missing.join('・')}も追加しますか？',
                  style: const TextStyle(
                    fontSize: 14,
                    color: context.textMainColor,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: context.textSubColor, size: 20),
            ],
          ),
        ),
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
                    color: context.textMainColor,
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
          Icon(Icons.chevron_right, color: context.textSubColor),
        ],
      ),
    );
  }
}
