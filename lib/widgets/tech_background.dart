import 'dart:math';
import 'package:flutter/material.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';

// ─────────────────────────────────────────────────────────
// カラーヘルパー — オーブ状態に連動
// ─────────────────────────────────────────────────────────

Color techBgColor1(Prediction? prediction, ModelStatus status) {
  if (!status.ready || prediction == null) return const Color(0xFF6B7685);
  final p = prediction.displayPToday;
  if (p == null) return const Color(0xFF6B7685);
  if (p < 0.3) return const Color(0xFF2A9D8F);
  if (p < 0.6) return const Color(0xFFE9C46A);
  return const Color(0xFFE76F51);
}

Color techBgColor2(Prediction? prediction, ModelStatus status) {
  if (!status.ready || prediction == null) return const Color(0xFF9BA5B0);
  final p = prediction.displayPToday;
  if (p == null) return const Color(0xFF9BA5B0);
  if (p < 0.3) return const Color(0xFF45B7AA);
  if (p < 0.6) return const Color(0xFFF0D68A);
  return const Color(0xFFF09070);
}

// ─────────────────────────────────────────────────────────
// TechBackground ウィジェット
// ─────────────────────────────────────────────────────────

class TechBackground extends StatefulWidget {
  final Color color1;
  final Color color2;

  const TechBackground({
    super.key,
    required this.color1,
    required this.color2,
  });

  @override
  State<TechBackground> createState() => _TechBackgroundState();
}

class _TechBackgroundState extends State<TechBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 回路パターン（静的、色変化時のみ再描画）
        Positioned.fill(
          child: CustomPaint(
            painter: _ScreenCircuitsPainter(
              color1: widget.color1,
              color2: widget.color2,
            ),
          ),
        ),
        // 浮遊ドット（アニメーション、独立再描画）
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _dotsController,
              builder: (_, __) => CustomPaint(
                painter: _ScreenDotsPainter(
                  color2: widget.color2,
                  t: _dotsController.value * 2 * pi,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// 回路パターン painter（画面スケール）
// ─────────────────────────────────────────────────────────

class _ScreenCircuitsPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _ScreenCircuitsPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = color1.withAlpha(38) // opacity 0.15
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // ── 左上 ──
    _lines(canvas, linePaint, [
      Offset(w * 0.03, h * 0.05), Offset(w * 0.24, h * 0.05),
      Offset(w * 0.24, h * 0.05), Offset(w * 0.24, h * 0.13),
      Offset(w * 0.24, h * 0.13), Offset(w * 0.37, h * 0.13),
      Offset(w * 0.13, h * 0.05), Offset(w * 0.13, h * 0.09),
    ]);
    _nodes(canvas, [
      Offset(w * 0.13, h * 0.05),
      Offset(w * 0.24, h * 0.05),
      Offset(w * 0.24, h * 0.13),
    ]);

    // ── 右上 ──
    _lines(canvas, linePaint, [
      Offset(w * 0.97, h * 0.05), Offset(w * 0.76, h * 0.05),
      Offset(w * 0.76, h * 0.05), Offset(w * 0.76, h * 0.13),
      Offset(w * 0.76, h * 0.13), Offset(w * 0.63, h * 0.13),
      Offset(w * 0.87, h * 0.05), Offset(w * 0.87, h * 0.09),
    ]);
    _nodes(canvas, [
      Offset(w * 0.87, h * 0.05),
      Offset(w * 0.76, h * 0.05),
      Offset(w * 0.76, h * 0.13),
    ]);

    // ── 左中 ──
    _lines(canvas, linePaint, [
      Offset(w * 0.03, h * 0.44), Offset(w * 0.18, h * 0.44),
      Offset(w * 0.18, h * 0.44), Offset(w * 0.18, h * 0.37),
      Offset(w * 0.18, h * 0.37), Offset(w * 0.30, h * 0.37),
    ]);
    _nodes(canvas, [
      Offset(w * 0.18, h * 0.44),
      Offset(w * 0.18, h * 0.37),
    ]);

    // ── 右中 ──
    _lines(canvas, linePaint, [
      Offset(w * 0.97, h * 0.56), Offset(w * 0.82, h * 0.56),
      Offset(w * 0.82, h * 0.56), Offset(w * 0.82, h * 0.63),
      Offset(w * 0.82, h * 0.63), Offset(w * 0.70, h * 0.63),
    ]);
    _nodes(canvas, [
      Offset(w * 0.82, h * 0.56),
      Offset(w * 0.82, h * 0.63),
    ]);

    // ── 左下 ──
    _lines(canvas, linePaint, [
      Offset(w * 0.03, h * 0.93), Offset(w * 0.24, h * 0.93),
      Offset(w * 0.24, h * 0.93), Offset(w * 0.24, h * 0.85),
      Offset(w * 0.24, h * 0.85), Offset(w * 0.37, h * 0.85),
      Offset(w * 0.13, h * 0.93), Offset(w * 0.13, h * 0.89),
    ]);
    _nodes(canvas, [
      Offset(w * 0.13, h * 0.93),
      Offset(w * 0.24, h * 0.93),
      Offset(w * 0.24, h * 0.85),
    ]);

    // ── 右下 ──
    _lines(canvas, linePaint, [
      Offset(w * 0.97, h * 0.93), Offset(w * 0.76, h * 0.93),
      Offset(w * 0.76, h * 0.93), Offset(w * 0.76, h * 0.85),
      Offset(w * 0.76, h * 0.85), Offset(w * 0.63, h * 0.85),
      Offset(w * 0.87, h * 0.93), Offset(w * 0.87, h * 0.89),
    ]);
    _nodes(canvas, [
      Offset(w * 0.87, h * 0.93),
      Offset(w * 0.76, h * 0.93),
      Offset(w * 0.76, h * 0.85),
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
      ..color = color2.withAlpha(89) // opacity 0.35（画面背景は控えめに）
      ..style = PaintingStyle.fill;

    for (final p in positions) {
      canvas.drawCircle(p, 3.5, outerPaint);
      canvas.drawCircle(p, 1.8, innerPaint);
    }
  }

  @override
  bool shouldRepaint(_ScreenCircuitsPainter old) =>
      old.color1 != color1 || old.color2 != color2;
}

// ─────────────────────────────────────────────────────────
// 浮遊ドット painter（画面スケール）
// ─────────────────────────────────────────────────────────

// 正規化座標 — 画面端・コーナー周辺に散らす
const _screenDotNx = [
  0.05, 0.14, 0.93, 0.86, 0.07, 0.04, 0.96, 0.91,
  0.43, 0.57, 0.21, 0.79, 0.02, 0.98, 0.50, 0.33, 0.67, 0.11,
];
const _screenDotNy = [
  0.09, 0.26, 0.07, 0.20, 0.53, 0.70, 0.46, 0.63,
  0.96, 0.02, 0.82, 0.87, 0.40, 0.60, 0.16, 0.94, 0.91, 0.34,
];
const _screenDotPhases = [
  0.0, 1.5, 2.7, 0.7, 3.9, 1.7, 2.3, 0.3,
  4.5, 1.2, 3.3, 2.4, 5.1, 0.9, 3.7, 2.0, 4.3, 1.1,
];

class _ScreenDotsPainter extends CustomPainter {
  final Color color2;
  final double t; // 0 to 2π

  const _ScreenDotsPainter({required this.color2, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _screenDotNx.length; i++) {
      final phase = _screenDotPhases[i];
      // opacity: 0.06 〜 0.28（画面背景なので控えめ）
      final opacity = 0.17 + 0.11 * sin(t + phase);
      // radius: 1.0 〜 2.0
      final radius = 1.5 + 0.5 * sin(t * 0.65 + phase);

      final x = _screenDotNx[i] * size.width;
      final y = _screenDotNy[i] * size.height;

      canvas.drawCircle(
        Offset(x, y),
        radius + 2.5,
        Paint()
          ..color = color2.withAlpha((255 * opacity * 0.5).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color2.withAlpha((255 * opacity).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_ScreenDotsPainter old) =>
      old.color2 != color2 || old.t != t;
}
