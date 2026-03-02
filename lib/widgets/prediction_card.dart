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
  final String? titleOverride;
  final bool isP3d;

  const PredictionCard({
    super.key,
    required this.prediction,
    this.isFallback = false,
    required this.status,
    this.onTap,
    this.titleOverride,
    this.isP3d = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!status.ready) return _buildLearningCard();
    final hasData = isP3d
        ? prediction != null && prediction!.p3d != null
        : prediction != null && prediction!.pToday != null;
    if (!hasData) return _buildWaitingCard();
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
    final displayP = isP3d ? pred.displayP3d! : pred.displayPToday!;
    final riskColor = _riskColor(displayP);
    final percentText = isP3d ? pred.risk3dPercent : pred.riskPercent;
    final labelText = isP3d ? pred.risk3dLabel : pred.riskLabel;
    final defaultTitle = isP3d
        ? '3日以内の不調リスク'
        : isFallback
            ? '直近の予測（${_formatDateKey(pred.dateKey)}）'
            : pred.provisional
                ? '今日の不調リスク（暫定）'
                : '今日の不調リスク';

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
                      titleOverride ?? defaultTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    if (!isP3d && titleOverride != null && pred.provisional)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '今日の入力データに基づく予測です',
                          style: AppTextStyles.captionSmall,
                        ),
                      ),
                    if (!isP3d &&
                        titleOverride == null &&
                        pred.provisional &&
                        !isFallback)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '翌朝に正式版へ更新されます',
                          style: AppTextStyles.captionSmall,
                        ),
                      ),
                    if (!isP3d && isFallback && titleOverride == null)
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
                percentText,
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
                  labelText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),

          // 不調基準の要約（明日・3日以内カードでは省略）
          if (!isP3d &&
              titleOverride == null &&
              status.unhealthyThreshold != null) ...[
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
        ],
      ),
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
