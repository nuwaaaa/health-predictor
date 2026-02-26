import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../models/model_status.dart';
import '../theme/app_theme.dart';

/// 予測結果を表示するカード — Calm Blue デザイン
class PredictionCard extends StatelessWidget {
  final Prediction? prediction;
  final bool isFallback;
  final ModelStatus status;
  final VoidCallback? onTap;

  const PredictionCard({
    super.key,
    required this.prediction,
    this.isFallback = false,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!status.ready) return _buildLearningCard();
    if (prediction == null || prediction!.pToday == null) {
      return _buildWaitingCard();
    }
    final card = _buildPredictionCard(context);
    return onTap != null
        ? GestureDetector(onTap: onTap, child: card)
        : card;
  }

  /// 学習中（14日未満）
  Widget _buildLearningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          const Icon(Icons.model_training, size: 40, color: AppColors.textSub),
          const SizedBox(height: AppSpacing.sm),
          const Text('予測モデル学習中', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'あと ${status.remainingDays} 日で予測開始',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: status.daysCollected / status.daysRequired,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${status.daysCollected} / ${status.daysRequired} 日',
            style: AppTextStyles.captionSmall,
          ),
        ],
      ),
    );
  }

  /// バッチ未実行
  Widget _buildWaitingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: const Column(
        children: [
          Icon(Icons.schedule, size: 36, color: AppColors.primary),
          SizedBox(height: AppSpacing.sm),
          Text('予測準備中', style: AppTextStyles.section),
          SizedBox(height: AppSpacing.xs),
          Text('明朝の更新をお待ちください', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  /// 予測結果カード
  Widget _buildPredictionCard(BuildContext context) {
    final pred = prediction!;
    final displayP = pred.displayPToday!;
    final riskColor = _riskColor(displayP);
    final showP3d = pred.p3d != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー: タイトル + 信頼度
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFallback
                          ? '直近の予測（${_formatDateKey(pred.dateKey)}）'
                          : pred.provisional
                              ? '今日の不調リスク（暫定）'
                              : '今日の不調リスク',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    if (pred.provisional && !isFallback)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '翌朝に正式版へ更新されます',
                          style: AppTextStyles.captionSmall,
                        ),
                      ),
                    if (isFallback)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '今日の予測は明朝更新されます',
                          style: AppTextStyles.captionSmall,
                        ),
                      ),
                  ],
                ),
              ),
              _confidenceBadge(pred.confidence),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // メイン: リスクパーセント + ラベル
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pred.riskPercent,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  pred.riskLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),

          // 不調基準の要約
          if (status.unhealthyThreshold != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'あなたの基準: 体調 ${status.unhealthyThreshold!.toStringAsFixed(1)} 以下の日',
              style: AppTextStyles.captionSmall,
            ),
          ],

          // 信頼度注記
          if (pred.confidenceNote != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              pred.confidenceNote!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSub,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // 特徴量寄与度TOP3
          if (pred.contributions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _contributionsSection(pred),
          ],

          // 改善アドバイス
          if (pred.advices.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(color: AppColors.divider, height: 1),
            ),
            _adviceSection(pred),
          ],

          // 3日リスク
          if (showP3d) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(color: AppColors.divider, height: 1),
            ),
            _threeDayRisk(pred),
          ],

          // 3日リスク未開放
          if (!showP3d && status.daysCollected >= 14) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(color: AppColors.divider, height: 1),
            ),
            _threeDayLocked(),
          ],
        ],
      ),
    );
  }

  Widget _threeDayRisk(Prediction pred) {
    final p3d = pred.displayP3d!;
    final color = _riskColor(p3d);
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 16, color: AppColors.textSub),
        const SizedBox(width: 8),
        const Text('3日間リスク', style: AppTextStyles.caption),
        const Spacer(),
        Text(
          pred.risk3dPercent,
          style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: color,
          ),
        ),
      ],
    );
  }

  Widget _threeDayLocked() {
    final need60 = status.daysCollected < 60;
    final needUnhealthy = status.unhealthyCount < 10;
    String message;
    if (need60) {
      message = '3日予測はあと ${60 - status.daysCollected} 日で開放';
    } else if (needUnhealthy) {
      message = '3日予測：準備中';
    } else {
      message = '3日予測：まもなく開放';
    }
    return Row(
      children: [
        const Icon(Icons.lock_outline, size: 16, color: AppColors.textSub),
        const SizedBox(width: 8),
        Text(message, style: AppTextStyles.captionSmall),
      ],
    );
  }

  Widget _confidenceBadge(String confidence) {
    Color bgColor;
    Color textColor;
    String label;
    switch (confidence) {
      case 'high':
        bgColor = const Color(0xFFD4EDDA);
        textColor = const Color(0xFF276749);
        label = '信頼度：高';
        break;
      case 'medium':
        bgColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        label = '信頼度：中';
        break;
      default:
        bgColor = AppColors.background;
        textColor = AppColors.textSub;
        label = '信頼度：低';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Widget _contributionsSection(Prediction pred) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('予測の主な要因', style: AppTextStyles.captionSmall),
        const SizedBox(height: AppSpacing.xs),
        ...pred.contributions.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    c.isRiskIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: c.isRiskIncrease
                        ? Colors.red.shade400
                        : Colors.green.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.isRiskIncrease
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            )),
        Text(
          '※ 因果関係ではなく傾向です',
          style: AppTextStyles.captionSmall.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Widget _adviceSection(Prediction pred) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 16, color: AppColors.chartOrange),
            const SizedBox(width: 6),
            Text(
              '改善アドバイス',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.chartOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...pred.advices.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('・', style: TextStyle(color: AppColors.textSub)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(a.message, style: AppTextStyles.caption.copyWith(color: AppColors.textMain)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  String _formatDateKey(String dateKey) {
    try {
      final parts = dateKey.split('-');
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      return '$month/$day';
    } catch (_) {
      return dateKey;
    }
  }

  Color _riskColor(double p) {
    if (p >= 0.6) return Colors.red.shade700;
    if (p >= 0.4) return Colors.orange.shade700;
    if (p >= 0.2) return Colors.amber.shade700;
    return AppColors.chartGreen;
  }
}
