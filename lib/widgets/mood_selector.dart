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
                    score: value,
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
  final int score; // 1–5 for eyes

  const _SensiaOrbPainter({required this.color, this.glowStrength = 1.0, this.score = 0});

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

    // Eyes
    _paintMiniEyes(canvas, size);
  }

  void _paintMiniEyes(Canvas canvas, Size size) {
    if (score < 1 || score > 5) return;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Per-score parameters (index 0 = score 1)
    const spreads = [0.24, 0.28, 0.30, 0.33, 0.36];
    const eyeYs   = [0.10, 0.04, -0.03, -0.09, -0.13];
    const squints  = [0.28, 0.52, 0.72, 0.88, 1.0];

    final idx    = score - 1;
    final spread = spreads[idx] * r;
    final yOff   = eyeYs[idx] * r;
    final sq     = squints[idx];

    final leftEye  = Offset(center.dx - spread, center.dy + yOff);
    final rightEye = Offset(center.dx + spread, center.dy + yOff);

    if (score == 5) {
      _miniHappyArc(canvas, leftEye, r);
      _miniHappyArc(canvas, rightEye, r);
    } else {
      _miniOpenEye(canvas, leftEye, r, sq);
      _miniOpenEye(canvas, rightEye, r, sq);
    }
  }

  void _miniHappyArc(Canvas canvas, Offset eye, double r) {
    final w = r * 0.20;
    final h = r * 0.12;
    final path = Path()
      ..moveTo(eye.dx - w, eye.dy)
      ..quadraticBezierTo(eye.dx, eye.dy - h, eye.dx + w, eye.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _miniOpenEye(Canvas canvas, Offset eye, double r, double squint) {
    final eyeW = r * 0.14;
    final eyeH = r * 0.16 * squint;
    if (eyeH < 0.8) {
      // Extreme squint: just a thin line
      canvas.drawLine(
        Offset(eye.dx - eyeW, eye.dy),
        Offset(eye.dx + eyeW, eye.dy),
        Paint()
          ..color = Colors.white.withAlpha(180)
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    final eyeRect = Rect.fromCenter(center: eye, width: eyeW * 2, height: eyeH * 2);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(eyeRect, Radius.circular(eyeW)));
    canvas.drawOval(eyeRect, Paint()..color = Colors.white.withAlpha(200));
    canvas.drawCircle(eye, r * 0.06, Paint()..color = const Color(0xFF0D1117).withAlpha(180));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SensiaOrbPainter old) =>
      old.color != color || old.glowStrength != glowStrength || old.score != score;
}
