import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class MoodSelector extends StatelessWidget {
  final int? selected;
  final bool enabled;
  final ValueChanged<int> onSelect;

  const MoodSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.enabled = true,
  });

  static const _emojis = ['😣', '😕', '😐', '🙂', '😄'];
  static const _labels = ['とても悪い', '悪い', '普通', '良い', 'とても良い'];

  static String emojiFor(int score) {
    if (score < 1 || score > 5) return '❓';
    return _emojis[score - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final value = i + 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: _MoodTile(
              value: value,
              emoji: _emojis[i],
              label: _labels[i],
              isSelected: selected == value,
              enabled: enabled,
              onTap: () => onSelect(value),
            ),
          ),
        );
      }),
    );
  }
}

class _MoodTile extends StatelessWidget {
  final int value;
  final String emoji;
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _MoodTile({
    required this.value,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label、$value点',
      button: true,
      selected: isSelected,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryTint : context.bgColor,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 2),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : context.textSubColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
