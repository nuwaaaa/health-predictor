import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const _orbTeal = Color(0xFF2A9D8F);
const _orbYellow = Color(0xFFE9C46A);
const _orbOrange = Color(0xFFE76F51);

enum SensiaRiskLevel { low, medium, high }

Color _orbColorForLevel(SensiaRiskLevel level) {
  switch (level) {
    case SensiaRiskLevel.low:
      return _orbTeal;
    case SensiaRiskLevel.medium:
      return _orbYellow;
    case SensiaRiskLevel.high:
      return _orbOrange;
  }
}

class SensiaMessageWidget extends StatefulWidget {
  final String message;
  final SensiaRiskLevel riskLevel;

  const SensiaMessageWidget({
    super.key,
    required this.message,
    this.riskLevel = SensiaRiskLevel.low,
  });

  @override
  State<SensiaMessageWidget> createState() => _SensiaMessageWidgetState();
}

class _SensiaMessageWidgetState extends State<SensiaMessageWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbColor = _orbColorForLevel(widget.riskLevel);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: orbColor.withAlpha(45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini orb + Sensia label
          Column(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return SizedBox(
                    width: 24,
                    height: 24,
                    child: CustomPaint(
                      painter: _MiniOrbPainter(
                        color: orbColor,
                        scale: _pulse.value,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 3),
              Text(
                'Sensia',
                style: TextStyle(
                  fontSize: 8,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w600,
                  color: orbColor,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          // Message bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: orbColor.withAlpha(18),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: context.textMainColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 複数アドバイスをSensiaが話しかけるカード形式で表示するウィジェット
class SensiaAdviceCard extends StatefulWidget {
  /// アドバイスのメッセージ文字列リスト
  final List<String> messages;
  final SensiaRiskLevel riskLevel;

  const SensiaAdviceCard({
    super.key,
    required this.messages,
    this.riskLevel = SensiaRiskLevel.low,
  });

  @override
  State<SensiaAdviceCard> createState() => _SensiaAdviceCardState();
}

class _SensiaAdviceCardState extends State<SensiaAdviceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbColor = _orbColorForLevel(widget.riskLevel);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: orbColor.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: mini orb + Sensia ラベル
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return SizedBox(
                    width: 24,
                    height: 24,
                    child: CustomPaint(
                      painter: _MiniOrbPainter(
                        color: orbColor,
                        scale: _pulse.value,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Sensia',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w700,
                  color: orbColor,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Divider(
                  color: orbColor.withAlpha(40),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          // アドバイスバブル（複数）
          ...widget.messages.asMap().entries.map((entry) {
            final isLast = entry.key == widget.messages.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: orbColor.withAlpha(18),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: context.textMainColor,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MiniOrbPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _MiniOrbPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * scale;

    // Outer glow
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..color = color.withAlpha(70);
    canvas.drawCircle(center, radius + 3, glowPaint);

    // Core orb — radial gradient for sphere feel
    final lighter = Color.lerp(color, Colors.white, 0.45)!;
    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.38),
        colors: [
          lighter.withAlpha(235),
          color.withAlpha(210),
          color.withAlpha(130),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, orbPaint);

    // Specular highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(90)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      center + Offset(-radius * 0.22, -radius * 0.22),
      radius * 0.28,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_MiniOrbPainter old) =>
      old.color != color || old.scale != scale;
}
