import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/sensia_message_widget.dart';
import '../widgets/chart_7days.dart';
import '../widgets/comparison_chart.dart';
import '../widgets/prediction_accuracy_chart.dart';

/// 分析タブ — Calm Blue デザイン
class AnalysisPage extends StatefulWidget {
  final FirestoreService service;
  final List<DailyLog> logs;
  final Prediction? prediction;
  final Prediction? tomorrowPrediction;
  final bool isFallbackPrediction;
  final ModelStatus status;

  const AnalysisPage({
    super.key,
    required this.service,
    required this.logs,
    required this.prediction,
    this.tomorrowPrediction,
    this.isFallbackPrediction = false,
    required this.status,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  // グラフ用
  int _periodDays = 7;
  List<DailyLog>? _allLogs;
  bool _loadingMore = false;
  List<Prediction>? _predictions;

  // フィードバック用
  bool _feedbackSubmitted = false;
  bool _feedbackSaving = false;
  bool _feedbackLoading = true;
  String? _alreadySubmittedWeek;
  List<Advice> _clientAdvices = [];

  List<DailyLog> get _displayLogs => _allLogs ?? widget.logs;

  @override
  void initState() {
    super.initState();
    _fetchPredictions();
    _checkExistingFeedback();
    _computeClientAdvice();
  }

  @override
  void didUpdateWidget(covariant AnalysisPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logs != widget.logs) {
      _allLogs = null;
      _predictions = null;
      _fetchPredictions();
      if (_periodDays != 7) {
        _fetchAllLogs();
      }
    }
  }

  Future<void> _changePeriod(int days) async {
    if (days == _periodDays) return;
    setState(() => _periodDays = days);
    if (_allLogs == null) {
      await _fetchAllLogs();
    }
  }

  Future<void> _fetchAllLogs() async {
    setState(() => _loadingMore = true);
    try {
      final logs = await widget.service.getLastNDays(365);
      if (mounted) setState(() => _allLogs = logs);
    } catch (e) {
      debugPrint('データ読み込み失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データの読み込みに失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _fetchPredictions() async {
    try {
      final preds = await widget.service.getLastNPredictions(90);
      if (mounted) setState(() => _predictions = preds);
    } catch (e) {
      debugPrint('予測データ読み込み失敗: $e');
    }
  }

  String get _currentWeekKey {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return FirestoreService.dateKey(monday);
  }

  Future<void> _checkExistingFeedback() async {
    try {
      final latest = await widget.service.getLatestFeedbackWeek();
      if (latest == _currentWeekKey && mounted) {
        setState(() => _alreadySubmittedWeek = latest);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _feedbackLoading = false);
    }
  }

  Future<void> _computeClientAdvice() async {
    final pred = widget.prediction;
    if (pred != null && pred.advices.isNotEmpty) return;

    try {
      final logs = await widget.service.getLastNDays(90);
      if (logs.length < 14) return;

      final validLogs = logs.where((l) => l.moodScore != null).toList();
      if (validLogs.length < 14) return;

      final meanMood = validLogs
              .map((l) => l.moodScore!)
              .reduce((a, b) => a + b) /
          validLogs.length;

      final goodDays =
          validLogs.where((l) => l.moodScore! >= meanMood + 0.5).toList();
      final badDays =
          validLogs.where((l) => l.moodScore! <= meanMood - 0.5).toList();

      if (goodDays.length < 3 || badDays.length < 3) return;

      final advices = <Advice>[];

      final goodSleep = goodDays
          .where((l) => l.sleep?.durationHours != null)
          .map((l) => l.sleep!.durationHours!)
          .toList();
      final badSleep = badDays
          .where((l) => l.sleep?.durationHours != null)
          .map((l) => l.sleep!.durationHours!)
          .toList();
      if (goodSleep.length >= 3 && badSleep.length >= 3) {
        final avgGood = goodSleep.reduce((a, b) => a + b) / goodSleep.length;
        final avgBad = badSleep.reduce((a, b) => a + b) / badSleep.length;
        if (avgGood - avgBad > 0.3) {
          final recHours = (avgGood * 10).roundToDouble() / 10;
          advices.add(Advice(
            param: 'sleep',
            message: '$recHours時間の睡眠をとった翌日は体調が安定する傾向があります',
          ));
        }
      }

      final goodSteps = goodDays
          .where((l) => l.steps != null)
          .map((l) => l.steps!.toDouble())
          .toList();
      final badSteps = badDays
          .where((l) => l.steps != null)
          .map((l) => l.steps!.toDouble())
          .toList();
      if (goodSteps.length >= 3 && badSteps.length >= 3) {
        final avgGood = goodSteps.reduce((a, b) => a + b) / goodSteps.length;
        final avgBad = badSteps.reduce((a, b) => a + b) / badSteps.length;
        if (avgGood - avgBad > 500) {
          final threshold = (avgGood / 1000).round() * 1000;
          advices.add(Advice(
            param: 'steps',
            message: '$threshold歩以上の日は体調が安定する傾向があります',
          ));
        }
      }

      final goodStress = goodDays
          .where((l) => l.stress != null)
          .map((l) => l.stress!.toDouble())
          .toList();
      final badStress = badDays
          .where((l) => l.stress != null)
          .map((l) => l.stress!.toDouble())
          .toList();
      if (goodStress.length >= 3 && badStress.length >= 3) {
        final avgGoodStr =
            goodStress.reduce((a, b) => a + b) / goodStress.length;
        final avgBadStr =
            badStress.reduce((a, b) => a + b) / badStress.length;
        if (avgBadStr - avgGoodStr > 0.5) {
          final recLevel = avgGoodStr.round();
          advices.add(Advice(
            param: 'stress',
            message: 'ストレスLv$recLevel以下の日は体調が良い傾向があります',
          ));
        }
      }

      if (advices.isNotEmpty && mounted) {
        setState(() {
          _clientAdvices = advices.length > 2 ? advices.sublist(0, 2) : advices;
        });
      }
    } catch (_) {}
  }

  Future<void> _submitFeedback(String result) async {
    if (_feedbackSaving) return;
    setState(() => _feedbackSaving = true);
    try {
      await widget.service.saveWeeklyFeedback(
        weekKey: _currentWeekKey,
        result: result,
      );
      setState(() => _feedbackSubmitted = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ありがとうございます！'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      debugPrint('フィードバック送信失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('送信に失敗しました。しばらくしてから再度お試しください')),
        );
      }
    } finally {
      if (mounted) setState(() => _feedbackSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pred = widget.prediction;
    final status = widget.status;
    final logs = _displayLogs;

    return Scaffold(
      appBar: AppBar(title: const Text('分析')),
      body: !status.ready
          ? _buildNotReady()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // --- 期間切替 ---
                  Row(
                    children: [
                      _periodPill(7, '7日', Icons.swipe, 'スライド'),
                      const SizedBox(width: AppSpacing.sm),
                      _periodPill(30, '30日', Icons.swipe, 'スライド'),
                      const SizedBox(width: AppSpacing.sm),
                      _periodPill(0, '全期間', Icons.fullscreen, '一覧'),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  if (_loadingMore)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    // --- 体調グラフ ---
                    SectionHeader(title: '体調推移'),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: Chart7Days(
                        logs: logs,
                        periodDays: _periodDays,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // --- 体調×特徴量 比較グラフ ---
                    SectionHeader(title: '体調と生活データの比較'),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: ComparisonChart(
                        logs: logs,
                        periodDays: _periodDays,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // --- 予測 vs 実績 ---
                    SectionHeader(title: '予測と実績の振り返り'),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: PredictionAccuracyChart(
                        logs: logs,
                        predictions: _predictions ?? [],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // --- 不調の基準 ---
                    SectionHeader(title: 'あなたの「不調」の基準'),
                    const SizedBox(height: AppSpacing.sm),
                    _unhealthyThresholdCard(),

                    const SizedBox(height: AppSpacing.lg),

                    // --- Sensiaのアドバイス ---
                    SectionHeader(title: 'Sensiaからのアドバイス'),
                    const SizedBox(height: AppSpacing.sm),
                    _sensiaAdviceSection(pred),

                    const SizedBox(height: AppSpacing.lg),

                    // --- 今週のふりかえり ---
                    SectionHeader(title: '今週のふりかえり'),
                    const SizedBox(height: AppSpacing.sm),
                    _feedbackCard(),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _periodPill(int days, String label, IconData icon, String subLabel) {
    final selected = _periodDays == days;
    return AppPill(
      label: label,
      selected: selected,
      icon: icon,
      subLabel: subLabel,
      onTap: () => _changePeriod(days),
    );
  }

  Widget _unhealthyThresholdCard() {
    final status = widget.status;
    final mean14 = status.moodMean14;
    final threshold = status.unhealthyThreshold;

    if (mean14 == null || threshold == null) {
      return const EmptyState(
        icon: Icons.info_outline,
        message: '不調基準はまだ算出されていません',
      );
    }

    final unhealthyCount = status.unhealthyCount;

    return AccentCard(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('普段の体調', '${mean14.toStringAsFixed(1)}（直近14日の平均）'),
          _infoRow('不調の基準', '${threshold.toStringAsFixed(1)} 以下'),
          _infoRow('不調日数', '$unhealthyCount 日（合計）'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'この基準はあなたの入力データから毎日自動で更新されます。',
            style: AppTextStyles.captionSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNotReady() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.model_training, size: 56, color: context.textSubColor),
            const SizedBox(height: AppSpacing.lg),
            const Text('データを集めています', style: AppTextStyles.section),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'あと ${widget.status.remainingDays} 日で予測が始まります',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sensiaAdviceSection(Prediction? pred) {
    final advices = (pred != null && pred.advices.isNotEmpty)
        ? pred.advices
        : _clientAdvices;

    if (advices.isEmpty) {
      return const EmptyState(
        icon: Icons.lightbulb_outline,
        message: 'データが増えるとアドバイスが表示されます',
      );
    }

    final p = pred?.displayPToday;
    final level = p == null
        ? SensiaRiskLevel.low
        : p >= 0.5
            ? SensiaRiskLevel.high
            : p >= 0.3
                ? SensiaRiskLevel.medium
                : SensiaRiskLevel.low;

    return SensiaAdviceCard(
      messages: advices.map((a) => a.message).toList(),
      riskLevel: level,
    );
  }

  Widget _feedbackCard() {
    final alreadyDone = _feedbackSubmitted || _alreadySubmittedWeek != null;

    if (alreadyDone) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: AppColors.chartGreen),
            const SizedBox(width: AppSpacing.sm),
            const Text('今週のふりかえり済み', style: AppTextStyles.caption),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          Text(
            '先週の予報、実際はどうでした？',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textMainColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _fbButton('当たった', Icons.check_circle_outline,
                    AppColors.mood5, 'correct'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _fbButton(
                    '外れた', Icons.cancel_outlined, AppColors.mood1, 'incorrect'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _fbButton('わからない', Icons.help_outline,
                    AppColors.textSub, 'unknown'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fbButton(String label, IconData icon, Color color, String result) {
    return GestureDetector(
      onTap: (_feedbackLoading || _feedbackSaving) ? null : () => _submitFeedback(result),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.colorWithAdaptiveAlpha(color, 20),
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: context.colorWithAdaptiveAlpha(color, 60)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textMainColor)),
        ],
      ),
    );
  }
}
