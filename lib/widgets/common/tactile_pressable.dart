import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';

/// Tactile pressable widget implementing Emil Kowalski's tactile scale feedback
/// (scale to 0.97 on active/press, 140ms snappy ease-out) and Apple's instant response.
class TactilePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final double pressedScale;
  final String? tooltip;
  final HitTestBehavior behavior;

  const TactilePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.pressedScale = 0.965,
    this.tooltip,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<TactilePressable> createState() => _TactilePressableState();
}

class _TactilePressableState extends State<TactilePressable> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null && widget.onSecondaryTap == null) {
      return;
    }
    setState(() => _isPressed = true);
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget core = AnimatedScale(
      scale: _isPressed ? widget.pressedScale : 1.0,
      duration: AppMotion.pressFeedback,
      curve: AppMotion.snappyEaseOut,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onSecondaryTap,
        child: widget.child,
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: AppMotion.tooltipDelay,
        child: core,
      );
    }
    return core;
  }
}
