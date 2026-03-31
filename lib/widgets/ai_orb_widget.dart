import 'dart:math';
import 'package:flutter/material.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../theme/app_theme.dart';

enum OrbState { good, caution, risk, learning }

class _OrbConfig {
  final Color color1;
  final Color color2;
  final String label;
  final int particleCount;
  final double orbitSpeed;

  const _OrbConfig({
    required this.color1,
    required this.color2,
    required this.label,
    required this.particleCount,
    required this.orbitSpeed,
  });
}

const _configs = {
  OrbState.good: _OrbConfig(
    color1: Color(0xFF2A9D8F),
    color2: Color(0xFF45B7AA),
    label: '好調の見込みです',
    particleCount: 6,
    orbitSpeed: 0.008,
  ),
  OrbState.caution: _OrbConfig(
    color1: Color(0xFFE9C46A),
    color2: Color(0xFFF0D68A),
    label: '少し気をつけましょう',
    particleCount: 8,
    orbitSpeed: 0.012,
  ),
  OrbState.risk: _OrbConfig(
    color1: Color(0xFFE76F51),
    color2: Color(0xFFF09070),
    label: '無理せず過ごしましょう',
    particleCount: 10,
    orbitSpeed: 0.016,
  ),
  OrbState.learning: _OrbConfig(
    color1: Color(0xFF6B7685),
    color2: Color(0xFF9BA5B0),
    label: '学習中...',
    particleCount: 4,
    orbitSpeed: 0.005,
  ),
};

OrbState _stateFromPrediction(Prediction? prediction, ModelStatus status) {
  if (!status.ready || prediction == null) return OrbState.learning;
  final p = prediction.displayPToday;
  if (p == null) return OrbState.learning;
  if (p < 0.3) return OrbState.good;
  if (p < 0.5) return OrbState.caution;
  return OrbState.risk;
}

class AiOrbWidget extends StatefulWidget {
  final Prediction? prediction;
  final ModelStatus status;

  const AiOrbWidget({
    super.key,
    required this.prediction,
    required this.status,
  });

  @override
  State<AiOrbWidget> createState() => _AiOrbWidgetState();
}

class _AiOrbWidgetState extends State<AiOrbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _stateFromPrediction(widget.prediction, widget.status);
    final cfg = _configs[state]!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E14),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'AI HEALTH MONITOR',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                fontFamily: 'Courier',
                color: cfg.color2.withAlpha(178),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 60 * 2 * pi;
              return SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _OrbPainter(state: state, cfg: cfg, t: t),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            cfg.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cfg.color2,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final OrbState state;
  final _OrbConfig cfg;
  final double t;

  const _OrbPainter({
    required this.state,
    required this.cfg,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final breathe = sin(t * 0.03) * 8;
    final orbRadius = 36.0 + breathe;

    // Outer glow
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
      ..shader = RadialGradient(
        colors: [cfg.color1.withAlpha(50), Colors.transparent],
      ).createShader(
        Rect.fromCircle(center: center, radius: orbRadius + 40),
      );
    canvas.drawCircle(center, orbRadius + 40, glowPaint);

    // Rotating dashed ring
    final ringPaint = Paint()
      ..color = cfg.color1.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    const dashCount = 24;
    const dashAngle = 2 * pi / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        final startAngle = i * dashAngle + t * 0.3;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: orbRadius + 18),
          startAngle,
          dashAngle * 0.6,
          false,
          ringPaint,
        );
      }
    }

    // Outer dashed ring (slower, opposite direction)
    final ringPaint2 = Paint()
      ..color = cfg.color2.withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;
    for (int i = 0; i < dashCount; i++) {
      if (i % 3 == 0) {
        final startAngle = i * dashAngle - t * 0.15;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: orbRadius + 28),
          startAngle,
          dashAngle * 0.4,
          false,
          ringPaint2,
        );
      }
    }

    // Core orb
    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [
          cfg.color2.withAlpha(200),
          cfg.color1.withAlpha(170),
          cfg.color1.withAlpha(80),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: orbRadius),
      );
    canvas.drawCircle(center, orbRadius, orbPaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..color = cfg.color2.withAlpha(60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      center + Offset(-orbRadius * 0.25, -orbRadius * 0.25),
      orbRadius * 0.35,
      highlightPaint,
    );

    // Particles
    final n = cfg.particleCount;
    final orbitRadius = orbRadius + 22;
    final particlePaint = Paint();
    for (int i = 0; i < n; i++) {
      final angle = 2 * pi * i / n + t * cfg.orbitSpeed;
      final px = center.dx + cos(angle) * orbitRadius;
      final py = center.dy + sin(angle) * orbitRadius;
      final pSize = 1.5 + sin(t * 0.05 + i * 1.2) * 0.8;
      final alpha = (102 + (sin(t * 0.03 + i) * 76)).round().clamp(0, 255);
      particlePaint
        ..color = cfg.color2.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(px, py), pSize, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t || old.state != state;
}
