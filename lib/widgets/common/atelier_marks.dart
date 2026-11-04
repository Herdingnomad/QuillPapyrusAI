import 'package:flutter/material.dart';

/// Custom-authored geometric vector marks for Quill & Papyrus AI's handmade identity.
/// Replaces generic Material robot/note icons with crisp calligraphic & nib geometry.
class FountainNibMark extends StatelessWidget {
  final double size;
  final Color color;

  const FountainNibMark({
    super.key,
    this.size = 18.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FountainNibPainter(color: color),
    );
  }
}

class _FountainNibPainter extends CustomPainter {
  final Color color;
  const _FountainNibPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.085).clamp(1.1, 2.2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Nib shoulders tapering up to a fine iridium tip (tilted 45° like a writing nib)
    final nibPath = Path()
      ..moveTo(s * 0.84, s * 0.16) // Tip
      ..lineTo(s * 0.42, s * 0.28) // Upper shoulder
      ..lineTo(s * 0.22, s * 0.58) // Base collar top
      ..lineTo(s * 0.42, s * 0.78) // Base collar bottom
      ..lineTo(s * 0.72, s * 0.58) // Lower shoulder
      ..close();

    canvas.drawPath(nibPath, stroke);

    // Nib slit from tip to breather hole
    canvas.drawLine(
      Offset(s * 0.82, s * 0.18),
      Offset(s * 0.53, s * 0.47),
      stroke,
    );

    // Breather hole
    canvas.drawCircle(
      Offset(s * 0.50, s * 0.50),
      (s * 0.065).clamp(1.0, 2.5),
      fill,
    );

    // Barrel collar band
    canvas.drawLine(
      Offset(s * 0.15, s * 0.65),
      Offset(s * 0.35, s * 0.85),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _FountainNibPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bespoke Studio Companion mark (nib + 4-point star spark) replacing generic robot icons.
class InkQuillSparkMark extends StatelessWidget {
  final double size;
  final Color color;

  const InkQuillSparkMark({
    super.key,
    this.size = 16.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _InkQuillSparkPainter(color: color),
    );
  }
}

class _InkQuillSparkPainter extends CustomPainter {
  final Color color;
  const _InkQuillSparkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.085).clamp(1.1, 2.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Feather/quill arc
    final quill = Path()
      ..moveTo(s * 0.16, s * 0.84)
      ..quadraticBezierTo(s * 0.24, s * 0.34, s * 0.72, s * 0.20)
      ..quadraticBezierTo(s * 0.62, s * 0.64, s * 0.26, s * 0.74);
    canvas.drawPath(quill, stroke);

    // Spine
    canvas.drawLine(Offset(s * 0.14, s * 0.86), Offset(s * 0.56, s * 0.44), stroke);

    // Subtle 4-point Atelier star in upper-right
    final cx = s * 0.80;
    final cy = s * 0.68;
    final rOuter = s * 0.16;
    final rInner = s * 0.045;
    final star = Path()
      ..moveTo(cx, cy - rOuter)
      ..lineTo(cx + rInner, cy - rInner)
      ..lineTo(cx + rOuter, cy)
      ..lineTo(cx + rInner, cy + rInner)
      ..lineTo(cx, cy + rOuter)
      ..lineTo(cx - rInner, cy + rInner)
      ..lineTo(cx - rOuter, cy)
      ..lineTo(cx - rInner, cy - rInner)
      ..close();
    canvas.drawPath(star, fill);
  }

  @override
  bool shouldRepaint(covariant _InkQuillSparkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Editorial bookmaker's rule with central diamond fleuron.
class AtelierDividerFlourish extends StatelessWidget {
  final Color color;
  final double width;

  const AtelierDividerFlourish({
    super.key,
    required this.color,
    this.width = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 14,
      child: CustomPaint(
        painter: _FlourishPainter(color: color),
      ),
    );
  }
}

class _FlourishPainter extends CustomPainter {
  final Color color;
  const _FlourishPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.40)
      ..strokeWidth = 0.85;

    final diamondPaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, cy), Offset(cx - 12, cy), linePaint);
    canvas.drawLine(Offset(cx + 12, cy), Offset(size.width, cy), linePaint);

    final diamond = Path()
      ..moveTo(cx, cy - 3.5)
      ..lineTo(cx + 3.5, cy)
      ..lineTo(cx, cy + 3.5)
      ..lineTo(cx - 3.5, cy)
      ..close();
    canvas.drawPath(diamond, diamondPaint);
  }

  @override
  bool shouldRepaint(covariant _FlourishPainter oldDelegate) =>
      oldDelegate.color != color;
}
