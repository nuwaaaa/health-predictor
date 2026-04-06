import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// カレンダーと共通のオーブ3色
const _colorRisk    = Color(0xFFE76F51); // score 1 不調
const _colorCaution = Color(0xFFE9C46A); // score 3 普通
const _colorGood    = Color(0xFF2A9D8F); // score 5 好調

Color _orbColorForScore(int score) {
  final t = (score - 1) / 4.0;
  if (t <= 0.5) {
    return Color.lerp(_colorRisk, _colorCaution, t * 2)!;
  } else {
    return Color.lerp(_colorCaution, _colorGood, (t - 0.5) * 2)!;
  }
}

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

  static const _emojis  = ['😣', '😕', '😐', '🙂', '😄'];
  static const _labels  = ['とても悪い', '悪い', '普通', '良い', 'とても良い'];

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
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _MoodTile({
    required this.value,
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final orbColor = _orbColorForScore(value);

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
            color: isSelected
                ? orbColor.withAlpha(30)
                : context.cardColor,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              color: isSelected ? orbColor : context.dividerColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: context.isDark ? null : AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CustomPaint(
                  painter: _SensiaOrbPainter(
                    color: orbColor,
                    glowStrength: isSelected ? 1.0 : 0.55,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? orbColor : context.textSubColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensiaOrbPainter extends CustomPainter {
  final Color color;
  /// 1.0 = 選択中（フル発光）、0.55 = 非選択（控えめ）
  final double glowStrength;

  const _SensiaOrbPainter({required this.color, this.glowStrength = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 外側グロー
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = color.withAlpha((90 * glowStrength).round()),
    );

    // コアオーブ（放射グラデーション）
    final lighter = Color.lerp(color, Colors.white, 0.45)!;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.38),
          colors: [
            lighter.withAlpha((235 * glowStrength + 120 * (1 - glowStrength)).round()),
            color.withAlpha((210 * glowStrength + 140 * (1 - glowStrength)).round()),
            color.withAlpha((130 * glowStrength + 80  * (1 - glowStrength)).round()),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // スペキュラハイライト
    canvas.drawCircle(
      center + Offset(-radius * 0.22, -radius * 0.22),
      radius * 0.28,
      Paint()
        ..color = Colors.white.withAlpha((90 * glowStrength).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_SensiaOrbPainter old) =>
      old.color != color || old.glowStrength != glowStrength;
}
