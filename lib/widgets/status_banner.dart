import 'package:flutter/material.dart';
import '../models/model_status.dart';
import '../theme/app_theme.dart';

class StatusBanner extends StatelessWidget {
  final ModelStatus status;

  const StatusBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final ready = status.ready;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: context.isDark ? null : AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ready ? Icons.check_circle_outline : Icons.hourglass_top,
                size: 18,
                color: ready ? AppColors.chartGreen : AppColors.chartOrange,
              ),
              const SizedBox(width: 6),
              Text(
                status.statusLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textMainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${status.daysCollected} / ${status.daysRequired} 日記録済み',
            style: AppTextStyles.captionSmall.copyWith(color: context.textSubColor),
          ),
          if (ready) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _infoPill(
                  context,
                  'モデル',
                  status.modelType == 'lightgbm' ? 'LightGBM' : 'ロジスティック',
                ),
                _infoPill(context, '信頼度', status.confidenceLevelLabel),
                if (status.recentMissingRate > 0)
                  _infoPill(
                    context,
                    '欠損率',
                    '${(status.recentMissingRate * 100).round()}%',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.captionSmall.copyWith(color: context.textSubColor),
      ),
    );
  }
}
