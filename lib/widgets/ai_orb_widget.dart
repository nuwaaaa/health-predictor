import 'dart:math';
import 'package:flutter/material.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// Orb state / config
// ─────────────────────────────────────────────────────────

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
  if (p < 0.6) return OrbState.caution;
  return OrbState.risk;
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

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
    with TickerProviderStateMixin {
  late final AnimationController _orbController;
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _stateFromPrediction(widget.prediction, widget.status);
    final cfg = _configs[state]!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            // ── Layer 0: 背景グラデーション + グリッド + 回路 (static) ──
            Positioned.fill(
              child: CustomPaint(
                painter: _BackgroundDecorPainter(
                  color1: cfg.color1,
                  color2: cfg.color2,
                ),
              ),
            ),

            // ── Layer 1: 浮遊ドット (animated, isolated repaint) ──
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _dotsController,
                  builder: (_, __) => CustomPaint(
                    painter: _DotsPainter(
                      color2: cfg.color2,
                      t: _dotsController.value * 2 * pi,
                    ),
                  ),
                ),
              ),
            ),

            // ── Layer 2: コンテンツ ──
            Padding(
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
                    animation: _orbController,
                    builder: (context, _) {
                      final t = _orbController.value * 60 * 2 * pi;
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
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Background decor painter — gradient + grid + circuits
// ─────────────────────────────────────────────────────────

class _BackgroundDecorPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _BackgroundDecorPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    _paintGradient(canvas, size);
    _paintCircuits(canvas, size);
  }

  void _paintGradient(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF060A10), Color(0xFF0A1018), Color(0xFF0F1820)],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _paintCircuits(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = color1.withAlpha(51) // opacity 0.20
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // ── Top-left ──
    _lines(canvas, linePaint, [
      Offset(w * 0.04, h * 0.09), Offset(w * 0.22, h * 0.09),
      Offset(w * 0.22, h * 0.09), Offset(w * 0.22, h * 0.25),
      Offset(w * 0.22, h * 0.25), Offset(w * 0.34, h * 0.25),
      Offset(w * 0.13, h * 0.09), Offset(w * 0.13, h * 0.18),
    ]);
    _nodes(canvas, [
      Offset(w * 0.13, h * 0.09),
      Offset(w * 0.22, h * 0.09),
      Offset(w * 0.22, h * 0.25),
    ]);

    // ── Top-right ──
    _lines(canvas, linePaint, [
      Offset(w * 0.96, h * 0.09), Offset(w * 0.78, h * 0.09),
      Offset(w * 0.78, h * 0.09), Offset(w * 0.78, h * 0.25),
      Offset(w * 0.78, h * 0.25), Offset(w * 0.66, h * 0.25),
      Offset(w * 0.87, h * 0.09), Offset(w * 0.87, h * 0.18),
    ]);
    _nodes(canvas, [
      Offset(w * 0.87, h * 0.09),
      Offset(w * 0.78, h * 0.09),
      Offset(w * 0.78, h * 0.25),
    ]);

    // ── Bottom-left ──
    _lines(canvas, linePaint, [
      Offset(w * 0.04, h * 0.88), Offset(w * 0.22, h * 0.88),
      Offset(w * 0.22, h * 0.88), Offset(w * 0.22, h * 0.72),
      Offset(w * 0.22, h * 0.72), Offset(w * 0.34, h * 0.72),
      Offset(w * 0.13, h * 0.88), Offset(w * 0.13, h * 0.80),
    ]);
    _nodes(canvas, [
      Offset(w * 0.13, h * 0.88),
      Offset(w * 0.22, h * 0.88),
      Offset(w * 0.22, h * 0.72),
    ]);

    // ── Bottom-right ──
    _lines(canvas, linePaint, [
      Offset(w * 0.96, h * 0.88), Offset(w * 0.78, h * 0.88),
      Offset(w * 0.78, h * 0.88), Offset(w * 0.78, h * 0.72),
      Offset(w * 0.78, h * 0.72), Offset(w * 0.66, h * 0.72),
      Offset(w * 0.87, h * 0.88), Offset(w * 0.87, h * 0.80),
    ]);
    _nodes(canvas, [
      Offset(w * 0.87, h * 0.88),
      Offset(w * 0.78, h * 0.88),
      Offset(w * 0.78, h * 0.72),
    ]);
  }

  void _lines(Canvas canvas, Paint paint, List<Offset> pairs) {
    for (int i = 0; i < pairs.length; i += 2) {
      canvas.drawLine(pairs[i], pairs[i + 1], paint);
    }
  }

  void _nodes(Canvas canvas, List<Offset> positions) {
    final outerPaint = Paint()
      ..color = color1.withAlpha(89) // opacity 0.35
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final innerPaint = Paint()
      ..color = color2.withAlpha(128) // opacity 0.50
      ..style = PaintingStyle.fill;

    for (final p in positions) {
      canvas.drawCircle(p, 3.8, outerPaint);
      canvas.drawCircle(p, 2.0, innerPaint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundDecorPainter old) =>
      old.color1 != color1 || old.color2 != color2;
}

// ─────────────────────────────────────────────────────────
// Floating dots painter
// ─────────────────────────────────────────────────────────

// 正規化座標 (x, y) — 中央 (0.35–0.65 両軸) を避けて配置
const _dotNx = [
  0.07, 0.17, 0.92, 0.84, 0.10, 0.05, 0.95, 0.88, 0.44, 0.56, 0.24, 0.76, 0.03,
];
const _dotNy = [
  0.14, 0.34, 0.11, 0.29, 0.66, 0.83, 0.70, 0.86, 0.93, 0.06, 0.90, 0.91, 0.49,
];
const _dotPhases = [
  0.0, 1.2, 2.4, 0.8, 3.6, 1.6, 2.8, 0.4, 4.2, 1.0, 3.0, 2.0, 4.8,
];

class _DotsPainter extends CustomPainter {
  final Color color2;
  final double t; // 0 to 2π

  const _DotsPainter({required this.color2, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _dotNx.length; i++) {
      final phase = _dotPhases[i];
      // opacity: 0.10 〜 0.45
      final opacity = 0.275 + 0.175 * sin(t + phase);
      // radius: 1.2 〜 2.4
      final radius = 1.8 + 0.6 * sin(t * 0.7 + phase);

      final x = _dotNx[i] * size.width;
      final y = _dotNy[i] * size.height;

      // Outer glow
      canvas.drawCircle(
        Offset(x, y),
        radius + 2.5,
        Paint()
          ..color = color2.withAlpha((255 * opacity * 0.55).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Inner dot
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color2.withAlpha((255 * opacity).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.color2 != color2 || old.t != t;
}

// ─────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────
// Orb painter (unchanged from original)
// ─────────────────────────────────────────────────────────

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
    final breathe = sin(t / 6) * 3; // ~6秒で1サイクル、振れ幅±3px
    final orbRadius = 36.0 + breathe;

    // Outer glow
    canvas.drawCircle(
      center,
      orbRadius + 40,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
        ..shader = RadialGradient(
          colors: [cfg.color1.withAlpha(50), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: orbRadius + 40)),
    );

    // Rotating dashed ring (inner)
    final ringPaint = Paint()
      ..color = cfg.color1.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    const dashCount = 24;
    const dashAngle = 2 * pi / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: orbRadius + 18),
          i * dashAngle + t * 0.3,
          dashAngle * 0.6,
          false,
          ringPaint,
        );
      }
    }

    // Rotating dashed ring (outer, opposite direction)
    final ringPaint2 = Paint()
      ..color = cfg.color2.withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;
    for (int i = 0; i < dashCount; i++) {
      if (i % 3 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: orbRadius + 28),
          i * dashAngle - t * 0.15,
          dashAngle * 0.4,
          false,
          ringPaint2,
        );
      }
    }

    // Core orb
    canvas.drawCircle(
      center,
      orbRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [
            cfg.color2.withAlpha(200),
            cfg.color1.withAlpha(170),
            cfg.color1.withAlpha(80),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: orbRadius)),
    );

    // Inner highlight
    canvas.drawCircle(
      center + Offset(-orbRadius * 0.25, -orbRadius * 0.25),
      orbRadius * 0.35,
      Paint()
        ..color = cfg.color2.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Orbiting particles
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
