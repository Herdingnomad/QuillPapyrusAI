import 'dart:ui';
import 'package:flutter/material.dart';

/// Translucent materials and chrome depth inspired by Apple's human interface guidelines
/// and Anti-Slop frontend architecture (tone-step separation over harsh 1px borders).
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

/// Helper methods for Apple-style subtle hairline highlights and tone steps.
class AppMaterials {
  /// Subtle light-catching top highlight on translucent glass chrome
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
      color: borderTone.withValues(alpha: 0.5),
      width: width,
    );
  }
}
