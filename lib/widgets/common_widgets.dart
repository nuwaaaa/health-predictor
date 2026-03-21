import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────
// Calm Blue — 再利用コンポーネント
// ─────────────────────────────────────────────

/// 白カード標準
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: context.isDark ? null : AppShadows.card,
      ),
      child: child,
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// 左にPrimaryTintのアクセントバー付きカード
class AccentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? accentColor;

  const AccentCard({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: context.isDark ? null : AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Row(
          children: [
            Container(
              width: 4,
              constraints: const BoxConstraints(minHeight: 60),
              color: accentColor ?? AppColors.primaryTint,
            ),
            Expanded(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ピル型タグ（デフォルトはアウトライン）
class AppPill extends StatelessWidget {
  final String label;
  final bool filled;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? subLabel;

  const AppPill({
    super.key,
    required this.label,
    this.filled = false,
    this.selected = false,
    this.onTap,
    this.icon,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    final mainColor = selected
        ? AppColors.primary
        : filled
            ? Colors.white
            : context.textMainColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryTint
              : filled
                  ? AppColors.primary
                  : context.cardColor,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.primary : context.dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: mainColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: mainColor,
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(width: 3),
              Text(
                subLabel!,
                style: TextStyle(
                  fontSize: 10,
                  color: mainColor.withAlpha(150),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// プライマリボタン
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}

/// セカンダリボタン（アウトライン）
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// 睡眠・歩数・ストレスなどの小チップ行表示
class MetricChipsRow extends StatelessWidget {
  final List<MetricChipData> chips;

  const MetricChipsRow({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: chips.map((c) => _MetricChip(data: c)).toList(),
    );
  }
}

class MetricChipData {
  final String label;
  final String value;
  final bool filled;

  const MetricChipData({
    required this.label,
    required this.value,
    this.filled = true,
  });
}

class _MetricChip extends StatelessWidget {
  final MetricChipData data;

  const _MetricChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: data.filled ? AppColors.primaryTint : context.bgColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              color: data.filled ? AppColors.primary : context.textSubColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: data.filled ? context.textMainColor : context.textSubColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// データ不足時の表示
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;

  const EmptyState({
    super.key,
    this.icon = Icons.hourglass_empty_rounded,
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: context.isDark ? null : AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: context.textSubColor),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.caption.copyWith(color: context.textSubColor),
            textAlign: TextAlign.center,
          ),
          if (subMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subMessage!,
              style: AppTextStyles.captionSmall.copyWith(color: context.textSubColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// セクションヘッダー
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.section),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.primary),
              ],
            ),
          ),
      ],
    );
  }
}
