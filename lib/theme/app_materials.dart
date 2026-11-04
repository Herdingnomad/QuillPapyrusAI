import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Translucent materials, cached cotton/parchment fiber surfaces, and subtle
/// tone-step depth for Quill & Papyrus AI's handmade studio aesthetic.
class FrostedChrome extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color backgroundColor;
  final Border? border;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;

  const FrostedChrome({
    super.key,
    required this.child,
    this.blur = 20.0,
    required this.backgroundColor,
    this.border,
    this.borderRadius,
    this.padding,
    this.margin,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        borderRadius: borderRadius,
      ),
      child: child,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );
  }
}

/// Renders a distinctly textured (default 4% visible) cotton-rag & parchment fiber
/// surface over a background plane. Wrapped in [RepaintBoundary] with `isComplex: true`
/// so the GPU caches the texture once with zero per-keystroke CPU/GPU overhead.
class PaperGrainSurface extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final double intensity;
  final bool isDark;
  final BorderRadius? borderRadius;

  const PaperGrainSurface({
    super.key,
    required this.child,
    this.backgroundColor,
    this.intensity = 0.04,
    required this.isDark,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget stack = Stack(
      fit: StackFit.passthrough,
      children: [
        if (backgroundColor != null)
          Positioned.fill(
            child: ColoredBox(color: backgroundColor!),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: false,
                painter: _CottonParchmentFiberPainter(
                  intensity: intensity,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: stack,
      );
    }
    return stack;
  }
}

class _CottonParchmentFiberPainter extends CustomPainter {
  final double intensity;
  final bool isDark;

  static const double _tileSize = 180.0;
  static final List<Offset> _lightSpecks = _generatePoints(seed: 109, count: 220);
  static final List<Offset> _darkSpecks = _generatePoints(seed: 317, count: 220);
  static final List<_FiberStrand> _strands = _generateStrands(seed: 733, count: 68);

  const _CottonParchmentFiberPainter({
    required this.intensity,
    required this.isDark,
  });

  static List<Offset> _generatePoints({required int seed, required int count}) {
    final rng = math.Random(seed);
    return List.generate(
      count,
      (_) => Offset(rng.nextDouble() * _tileSize, rng.nextDouble() * _tileSize),
      growable: false,
    );
  }

  static List<_FiberStrand> _generateStrands({required int seed, required int count}) {
    final rng = math.Random(seed);
    return List.generate(count, (_) {
      final start = Offset(rng.nextDouble() * _tileSize, rng.nextDouble() * _tileSize);
      final angle = rng.nextDouble() * math.pi * 2;
      final len = 3.0 + rng.nextDouble() * 7.5;
      final bend = (rng.nextDouble() - 0.5) * 2.4;
      final end = Offset(
        start.dx + math.cos(angle) * len,
        start.dy + math.sin(angle) * len,
      );
      final mid = Offset(
        (start.dx + end.dx) * 0.5 - math.sin(angle) * bend,
        (start.dy + end.dy) * 0.5 + math.cos(angle) * bend,
      );
      return _FiberStrand(
        start: start,
        control: mid,
        end: end,
        isLight: rng.nextBool(),
        weightFactor: 0.65 + rng.nextDouble() * 0.65,
      );
    }, growable: false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || intensity <= 0) return;

    final lightAlpha = (intensity * (isDark ? 0.95 : 1.15)).clamp(0.0, 0.25);
    final shadowAlpha = (intensity * (isDark ? 1.25 : 0.95)).clamp(0.0, 0.25);

    final lightGrainPaint = Paint()
      ..color = const Color(0xFFFFF8EB).withValues(alpha: lightAlpha)
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;

    final darkGrainPaint = Paint()
      ..color = const Color(0xFF1A140E).withValues(alpha: shadowAlpha)
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;

    final lightFiberPaint = Paint()
      ..color = const Color(0xFFFFF6E5).withValues(alpha: (lightAlpha * 0.88).clamp(0.0, 0.25))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;

    final darkFiberPaint = Paint()
      ..color = const Color(0xFF231A12).withValues(alpha: (shadowAlpha * 0.88).clamp(0.0, 0.25))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;

    final cols = (size.width / _tileSize).ceil().clamp(1, 24);
    final rows = (size.height / _tileSize).ceil().clamp(1, 24);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final dx = c * _tileSize;
        final dy = r * _tileSize;
        canvas.save();
        canvas.translate(dx, dy);

        canvas.drawPoints(PointMode.points, _lightSpecks, lightGrainPaint);
        canvas.drawPoints(PointMode.points, _darkSpecks, darkGrainPaint);

        for (final s in _strands) {
          final path = Path()
            ..moveTo(s.start.dx, s.start.dy)
            ..quadraticBezierTo(s.control.dx, s.control.dy, s.end.dx, s.end.dy);
          final paint = s.isLight ? lightFiberPaint : darkFiberPaint;
          paint.strokeWidth = 0.65 * s.weightFactor;
          canvas.drawPath(path, paint);
        }

        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CottonParchmentFiberPainter oldDelegate) {
    return oldDelegate.intensity != intensity || oldDelegate.isDark != isDark;
  }
}

class _FiberStrand {
  final Offset start;
  final Offset control;
  final Offset end;
  final bool isLight;
  final double weightFactor;

  const _FiberStrand({
    required this.start,
    required this.control,
    required this.end,
    required this.isLight,
    required this.weightFactor,
  });
}

/// Helper methods for subtle studio highlights, tactile sheet shadows, and tone steps.
class AppMaterials {
  /// Subtle light-catching top highlight on translucent chrome
  static Border subtleTopHighlight(Color accentOrFg) {
    return Border(
      top: BorderSide(
        color: accentOrFg.withValues(alpha: 0.12),
        width: 0.75,
      ),
      bottom: BorderSide(
        color: Colors.black.withValues(alpha: 0.15),
        width: 0.5,
      ),
    );
  }

  /// Subtle tone-step border for panels and floating pills
  static Border toneStepBorder(Color borderTone, {double width = 0.75}) {
    return Border.all(
      color: borderTone.withValues(alpha: 0.48),
      width: width,
    );
  }

  /// Tactile multi-layered paper contact + ambient shadow (no zero-offset neon glow)
  static List<BoxShadow> paperSheetShadows({required bool isDark, double elevationScale = 1.0}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: (isDark ? 0.34 : 0.09) * elevationScale),
        blurRadius: 18 * elevationScale,
        offset: Offset(0, 8 * elevationScale),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: (isDark ? 0.20 : 0.05) * elevationScale),
        blurRadius: 3 * elevationScale,
        offset: Offset(0, 1.5 * elevationScale),
      ),
    ];
  }
}
