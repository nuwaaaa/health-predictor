import 'package:flutter/material.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/sensia_message_widget.dart';

/// 分析タブ — Calm Blue デザイン
class AnalysisPage extends StatefulWidget {
  final FirestoreService service;
  final Prediction? prediction;
  final Prediction? tomorrowPrediction;
  final bool isFallbackPrediction;
  final ModelStatus status;

  const AnalysisPage({
    super.key,
    required this.service,
    required this.prediction,
    this.tomorrowPrediction,
    this.isFallbackPrediction = false,
    required this.status,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _feedbackSubmitted = false;
  bool _feedbackSaving = false;
  bool _feedbackLoading = true;
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
            message:
                '$recHours時間の睡眠をとった翌日は体調が安定する傾向があります',
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

                  // --- Sensiaのアドバイス（要因より前） ---
                  SectionHeader(title: 'Sensiaからのアドバイス'),
                  const SizedBox(height: AppSpacing.sm),
                  _sensiaAdviceSection(pred),

                  const SizedBox(height: AppSpacing.lg),

                  // --- 今日の要因 TOP3 ---
                  SectionHeader(title: '今日の予測に影響した要因 TOP3'),
                  const SizedBox(height: AppSpacing.sm),
                  _contributionsSensiaCard(
                    pred?.contributions ?? [],
                    _riskLevel(pred?.displayPToday),
                    emptyMessage: '予測データがありません',
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // --- 明日の要因 TOP3 ---
                  SectionHeader(title: '明日の予測に影響した要因 TOP3'),
                  const SizedBox(height: AppSpacing.sm),
                  _contributionsSensiaCard(
                    widget.tomorrowPrediction?.contributions ?? [],
                    _riskLevel(widget.tomorrowPrediction?.displayPToday),
                    emptyMessage: '明日の予測データがありません',
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // --- 今週のふりかえり ---
                  SectionHeader(title: '今週のふりかえり'),
                  const SizedBox(height: AppSpacing.sm),
                  _feedbackCard(),

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

  SensiaRiskLevel _riskLevel(double? p) {
    if (p == null) return SensiaRiskLevel.low;
    if (p >= 0.5) return SensiaRiskLevel.high;
    if (p >= 0.3) return SensiaRiskLevel.medium;
    return SensiaRiskLevel.low;
  }

  Widget _contributionsSensiaCard(
    List<FeatureContribution> contributions,
    SensiaRiskLevel level, {
    required String emptyMessage,
  }) {
    if (contributions.isEmpty) {
      return EmptyState(icon: Icons.analytics_outlined, message: emptyMessage);
    }
    final top3 = contributions.length > 3
        ? contributions.sublist(0, 3)
        : contributions;
    return SensiaAdviceCard(
      messages: top3.map(_contributionMessage).toList(),
      riskLevel: level,
    );
  }

  /// 寄与度1件をSensiaの具体的なメッセージに変換
  String _contributionMessage(FeatureContribution c) {
    final bad = c.isRiskIncrease;
    switch (c.feature) {
      case 'sleep_hours_filled':
        return bad
            ? '昨夜の睡眠が少なめで、体調に影響が出やすい状態です。できるだけ早めの就寝を心がけてみてください。'
            : '睡眠がしっかりとれており、体調の安定につながっています。この調子を続けましょう。';
      case 'sleep_dev':
        return bad
            ? '睡眠時間にばらつきがあります。毎日同じ時間に寝起きすると体内リズムが整いやすくなります。'
            : '睡眠時間が安定していて、体内リズムが整っています。';
      case 'steps_filled':
        return bad
            ? '最近の歩数が少なめです。短い散歩でも体を動かすと気分が変わりやすいですよ。'
            : '適度に体を動かせており、体調維持にプラスに働いています。';
      case 'steps_dev':
        return bad
            ? '歩数の波が大きくなっています。毎日少しずつ歩く習慣をつけると安定しやすいです。'
            : '歩数が安定していて、体のリズムが整っています。';
      case 'stress_filled':
        return bad
            ? 'ストレスが高めになっています。今日は無理せず、ゆっくり過ごす時間を意識的に作ってみて。'
            : 'ストレスが落ち着いており、体調を崩しにくい状態です。';
      case 'mood_lag1':
        return bad
            ? '昨日の体調が優れなかった影響が続いているようです。今日は無理せず休養を優先して。'
            : '昨日の体調が良かったことが、今日にも好影響を与えています。';
      case 'mood_ma3':
        return bad
            ? 'ここ3日間、体調が低め傾向が続いています。休養を優先する時期かもしれません。'
            : 'ここ3日間、体調が安定して良い状態が続いています。';
      case 'mood_ma7':
        return bad
            ? 'この1週間、体調が優れない日が多いようです。生活習慣を見直すきっかけにしてみて。'
            : '1週間通して体調の良い流れが続いています。';
      case 'mood_delta1':
        return bad
            ? '体調が昨日より下がっています。今日は無理をせず、ゆっくり過ごしてください。'
            : '体調が上向きになっており、良い流れです。';
      case 'mood_dev14':
        return bad
            ? '体調の波が大きくなっています。規則正しい生活が安定につながりやすいです。'
            : '体調のムラが少なく、安定した状態を保てています。';
      case 'bed_sin':
      case 'bed_cos':
        return bad
            ? '就寝時刻が不規則になっています。毎晩同じ時間に眠ると体内時計が整いやすくなります。'
            : '就寝時刻が規則正しく、睡眠の質が保たれています。';
      case 'wake_sin':
      case 'wake_cos':
        return bad
            ? '起床時刻のばらつきが体調に影響しているかもしれません。できるだけ一定の時間に起きてみて。'
            : '起床時刻が規則正しく、体内時計が整っています。';
      case 'is_weekend':
        return bad
            ? '平日の疲れが出やすいタイミングです。意識的にリフレッシュの時間を作ってみて。'
            : '今日はゆっくり過ごせる日です。しっかり休養をとって体調を整えましょう。';
      case 'day_sin':
      case 'day_cos':
        return bad
            ? '今日は体調が不安定になりやすい曜日の傾向があります。無理は禁物です。'
            : '今日は体調が整いやすい曜日の傾向があります。';
      default:
        return bad
            ? '${c.label}が体調にマイナスの影響を与えています。注意して過ごしてみて。'
            : '${c.label}が体調の安定につながっています。';
    }
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
    final alreadyDone =
        _feedbackSubmitted || _alreadySubmittedWeek != null;

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

  Widget _fbButton(
      String label, IconData icon, Color color, String result) {
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
