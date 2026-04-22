import 'dart:math';
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
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _blinkController;
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
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkController.dispose();
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
                animation: Listenable.merge([_controller, _blinkController]),
                builder: (context, _) {
                  return SizedBox(
                    width: 32,
                    height: 32,
                    child: CustomPaint(
                      painter: _MiniOrbPainter(
                        color: orbColor,
                        scale: _pulse.value,
                        riskLevel: widget.riskLevel,
                        t: _blinkController.value * 60 * 2 * pi,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Sensia',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w600,
                  color: orbColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          // Message bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
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
                widget.message,
                style: TextStyle(
                  fontSize: 15,
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
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _blinkController;
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
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkController.dispose();
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
                animation: Listenable.merge([_controller, _blinkController]),
                builder: (context, _) {
                  return SizedBox(
                    width: 32,
                    height: 32,
                    child: CustomPaint(
                      painter: _MiniOrbPainter(
                        color: orbColor,
                        scale: _pulse.value,
                        riskLevel: widget.riskLevel,
                        t: _blinkController.value * 60 * 2 * pi,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Sensia',
                style: TextStyle(
                  fontSize: 13,
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
                    fontSize: 15,
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
  final SensiaRiskLevel riskLevel;
  final double t; // for blink animation

  const _MiniOrbPainter({
    required this.color,
    required this.scale,
    this.riskLevel = SensiaRiskLevel.low,
    this.t = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * scale;

    // Outer glow
    canvas.drawCircle(
      center, radius + 3,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..color = color.withAlpha(70),
    );

    // Core orb — radial gradient for sphere feel
    final lighter = Color.lerp(color, Colors.white, 0.45)!;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.38),
          colors: [
            lighter.withAlpha(235),
            color.withAlpha(210),
            color.withAlpha(130),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Specular highlight
    canvas.drawCircle(
      center + Offset(-radius * 0.22, -radius * 0.22),
      radius * 0.28,
      Paint()
        ..color = Colors.white.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Eyes
    _paintEyes(canvas, center, radius);
  }

  void _paintEyes(Canvas canvas, Offset center, double r) {
    // Map riskLevel to eye parameters (same as ai_orb_widget _eyeConfigs)
    final bool happyArc;
    final double eyeY, eyeSpread, pupilSize, pupilY, squint;

    switch (riskLevel) {
      case SensiaRiskLevel.low:
        happyArc = true;
        eyeY = -0.08; eyeSpread = 0.19;
        pupilSize = 0; pupilY = 0; squint = 1.0;
      case SensiaRiskLevel.medium:
        happyArc = false;
        eyeY = -0.02; eyeSpread = 0.16;
        pupilSize = 0.07; pupilY = 0.0; squint = 0.85;
      case SensiaRiskLevel.high:
        happyArc = false;
        eyeY = 0.06; eyeSpread = 0.12;
        pupilSize = 0.055; pupilY = 0.04; squint = 0.40;
    }

    final blinkVal = sin(t * 0.18);
    final isBlinking = blinkVal > 0.96 && !happyArc;

    final leftEye  = center + Offset(-eyeSpread * r, eyeY * r);
    final rightEye = center + Offset( eyeSpread * r, eyeY * r);

    if (happyArc) {
      _drawHappyArc(canvas, leftEye, r);
      _drawHappyArc(canvas, rightEye, r);
    } else if (isBlinking) {
      _drawClosedEye(canvas, leftEye, r);
      _drawClosedEye(canvas, rightEye, r);
    } else {
      _drawOpenEye(canvas, leftEye, r, eyeSpread, pupilSize, pupilY, squint);
      _drawOpenEye(canvas, rightEye, r, eyeSpread, pupilSize, pupilY, squint);
    }
  }

  void _drawHappyArc(Canvas canvas, Offset eye, double r) {
    final w = r * 0.14;
    final h = r * 0.09;
    final path = Path()
      ..moveTo(eye.dx - w, eye.dy)
      ..quadraticBezierTo(eye.dx, eye.dy - h, eye.dx + w, eye.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withAlpha(220)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawClosedEye(Canvas canvas, Offset eye, double r) {
    final w = r * 0.11;
    final h = r * 0.04;
    final path = Path()
      ..moveTo(eye.dx - w, eye.dy)
      ..quadraticBezierTo(eye.dx, eye.dy + h, eye.dx + w, eye.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withAlpha(170)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawOpenEye(Canvas canvas, Offset eye, double r,
      double eyeSpread, double pupilSize, double pupilY, double squint) {
    final eyeW = r * 0.11;
    final eyeH = r * 0.13 * squint;
    final eyeRect = Rect.fromCenter(center: eye, width: eyeW * 2, height: eyeH * 2);

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(eyeRect, Radius.circular(eyeW)));
    canvas.drawOval(eyeRect, Paint()..color = Colors.white.withAlpha(210));
    if (pupilSize > 0) {
      canvas.drawCircle(
        eye + Offset(0, pupilY * r),
        r * pupilSize,
        Paint()..color = const Color(0xFF0D1117).withAlpha(200),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniOrbPainter old) =>
      old.color != color || old.scale != scale ||
      old.riskLevel != riskLevel || old.t != t;
}
