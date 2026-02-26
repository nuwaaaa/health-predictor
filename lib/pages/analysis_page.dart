import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// 分析タブ — Calm Blue デザイン
class AnalysisPage extends StatefulWidget {
  final FirestoreService service;
  final Prediction? prediction;
  final bool isFallbackPrediction;
  final ModelStatus status;

  const AnalysisPage({
    super.key,
    required this.service,
    required this.prediction,
    this.isFallbackPrediction = false,
    required this.status,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _feedbackSubmitted = false;
  bool _feedbackSaving = false;
  String? _alreadySubmittedWeek;
  List<Advice> _clientAdvices = [];

  @override
  void initState() {
    super.initState();
    _checkExistingFeedback();
    _computeClientAdvice();
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
    } catch (_) {}
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
            message:
                '${recHours}時間の睡眠をとった翌日は体調が安定する傾向があります',
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
            message: '${threshold}歩以上の日は体調が安定する傾向があります',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信失敗: $e')),
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

                  // --- 不調の基準 ---
                  SectionHeader(title: 'あなたの「不調」の基準'),
                  const SizedBox(height: AppSpacing.sm),
                  _unhealthyThresholdCard(),

                  const SizedBox(height: AppSpacing.lg),

                  // --- 要因 TOP3 ---
                  SectionHeader(title: '予測に影響した要因 TOP3'),
                  const SizedBox(height: AppSpacing.sm),
                  if (pred != null && pred.contributions.isNotEmpty)
                    _contributionsCard(pred)
                  else
                    const EmptyState(
                      icon: Icons.analytics_outlined,
                      message: '予測データがありません',
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // --- アドバイス ---
                  SectionHeader(title: '改善アドバイス'),
                  const SizedBox(height: AppSpacing.sm),
                  if (pred != null && pred.advices.isNotEmpty)
                    _adviceCard(pred.advices)
                  else if (_clientAdvices.isNotEmpty)
                    _adviceCard(_clientAdvices)
                  else
                    const EmptyState(
                      icon: Icons.lightbulb_outline,
                      message: 'データが増えるとアドバイスが表示されます',
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // --- 週次フィードバック ---
                  SectionHeader(title: '週次フィードバック'),
                  const SizedBox(height: AppSpacing.sm),
                  _feedbackCard(),

                  const SizedBox(height: AppSpacing.lg),

                  // --- モデル情報 ---
                  SectionHeader(title: 'モデル情報'),
                  const SizedBox(height: AppSpacing.sm),
                  _modelInfoCard(),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
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
          _infoRow('不調ライン', '${threshold.toStringAsFixed(1)} 以下'),
          _infoRow('不調日数', '$unhealthyCount 日（累計）'),
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
            const Icon(Icons.model_training, size: 56, color: AppColors.textSub),
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

  Widget _contributionsCard(Prediction pred) {
    return AppCard(
      child: Column(
        children: [
          ...pred.contributions.map((c) {
            final isUp = c.isRiskIncrease;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isUp
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    child: Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 18,
                      color: isUp
                          ? Colors.red.shade500
                          : Colors.green.shade500,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.label,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain)),
                        Text(
                          isUp ? 'リスク増加方向' : 'リスク低下方向',
                          style: TextStyle(
                            fontSize: 12,
                            color: isUp
                                ? Colors.red.shade400
                                : Colors.green.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '※ 因果関係ではなく、あなたのデータにおける傾向です',
            style: AppTextStyles.captionSmall,
          ),
        ],
      ),
    );
  }

  Widget _adviceCard(List<Advice> advices) {
    return AccentCard(
      accentColor: AppColors.chartOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: advices.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 18, color: AppColors.chartOrange),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    a.message,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _feedbackCard() {
    final alreadyDone =
        _feedbackSubmitted || _alreadySubmittedWeek != null;

    if (alreadyDone) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: AppColors.chartGreen),
            const SizedBox(width: AppSpacing.sm),
            const Text('今週のフィードバック済み', style: AppTextStyles.caption),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          const Text(
            '先週の予報、実際はどうでした？',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _fbButton('当たった', Icons.check_circle_outline,
                    AppColors.chartGreen, 'correct'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _fbButton(
                    '外れた', Icons.cancel_outlined, Colors.red, 'incorrect'),
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

  Widget _fbButton(
      String label, IconData icon, Color color, String result) {
    return GestureDetector(
      onTap: _feedbackSaving ? null : () => _submitFeedback(result),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: color.withAlpha(60)),
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

  Widget _modelInfoCard() {
    final status = widget.status;
    final modelLabel =
        status.modelType == 'lightgbm' ? 'LightGBM' : 'ロジスティック回帰';

    return AppCard(
      child: Column(
        children: [
          _infoRow('使用モデル', modelLabel),
          _infoRow('信頼度', status.confidenceLevelLabel),
          _infoRow('データ日数', '${status.daysCollected}日'),
          _infoRow('不調件数', '${status.unhealthyCount}件'),
          if (status.recentMissingRate > 0)
            _infoRow(
                '直近7日欠損率', '${(status.recentMissingRate * 100).round()}%'),
        ],
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
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain)),
        ],
      ),
    );
  }
}
