import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';

class ThreePaneLayout extends ConsumerStatefulWidget {
  final Widget leftPane;
  final Widget centerPane;
  final Widget rightPane;

  const ThreePaneLayout({
    super.key,
    required this.leftPane,
    required this.centerPane,
    required this.rightPane,
  });

  @override
  ConsumerState<ThreePaneLayout> createState() => _ThreePaneLayoutState();
}

class _ThreePaneLayoutState extends ConsumerState<ThreePaneLayout> {
  static const Duration _animationDuration = AppMotion.paneTransition;
  static const Curve _animationCurve = AppMotion.snappyEaseOut;
  static const double _minCenterPx = 280.0;

  bool _isDraggingLeft = false;
  bool _isDraggingRight = false;
  double _dragStartLeftWidth = LayoutNotifier.defaultLeftWidth;
  double _dragDeltaLeft = 0.0;
  double _dragStartRightWidth = LayoutNotifier.defaultRightWidth;
  double _dragDeltaRight = 0.0;
  double _lastOpenLeftWidth = LayoutNotifier.defaultLeftWidth;
  double _lastOpenRightWidth = LayoutNotifier.defaultRightWidth;

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        const minLeftPx = LayoutNotifier.minLeftWidth;
        const minRightPx = LayoutNotifier.minRightWidth;

        final maxLeftPx = (totalWidth * 0.42).clamp(minLeftPx, LayoutNotifier.maxLeftWidth);
        final maxRightPx = (totalWidth * 0.46).clamp(minRightPx, LayoutNotifier.maxRightWidth);

        // Sidebars use fixed logical pixel widths rather than window fractions so
        // expanding the window gives 100% of the new space to the center writing pane.
        double leftWidth = layoutState.isLeftPaneVisible
            ? layoutState.leftPaneWidth.clamp(minLeftPx, maxLeftPx)
            : 0.0;
        double rightWidth = layoutState.isRightPaneVisible
            ? layoutState.rightPaneWidth.clamp(minRightPx, maxRightPx)
            : 0.0;

        final double leftChrome = layoutState.isLeftPaneVisible
            ? 10.0
            : (layoutState.isZenMode ? 0.0 : 24.0);
        final double rightChrome = layoutState.isRightPaneVisible
            ? 10.0
            : (layoutState.isZenMode ? 0.0 : 24.0);
        final double availableForSidebars =
            (totalWidth - leftChrome - rightChrome - _minCenterPx).clamp(0.0, totalWidth);

        // On compact 3-pane screens (e.g. 650–850dp tablets/foldables), compress
        // open sidebars proportionally so the center pane always retains generous space.
        final double combinedSidebars = leftWidth + rightWidth;
        if (combinedSidebars > availableForSidebars && combinedSidebars > 0) {
          final scale = availableForSidebars / combinedSidebars;
          if (leftWidth > 0) {
            leftWidth = (leftWidth * scale).clamp(
              minLeftPx.clamp(0.0, availableForSidebars),
              maxLeftPx,
            );
          }
          if (rightWidth > 0) {
            final remainingForRight = (availableForSidebars - leftWidth).clamp(0.0, maxRightPx);
            rightWidth = (rightWidth * scale).clamp(
              minRightPx.clamp(0.0, remainingForRight),
              remainingForRight,
            );
          }
        }

        if (leftWidth > 0) {
          _lastOpenLeftWidth = leftWidth;
        }
        if (rightWidth > 0) {
          _lastOpenRightWidth = rightWidth;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane (Zero duration when dragging for instant 60/120Hz tracking; smooth when toggling)
            AnimatedContainer(
              duration: _isDraggingLeft ? Duration.zero : _animationDuration,
              curve: _animationCurve,
              width: leftWidth,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: minLeftPx,
                  maxWidth: 1200.0,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: leftWidth > 0 ? leftWidth : _lastOpenLeftWidth.clamp(minLeftPx, 1200.0),
                    child: ColoredBox(
                      color: GruvboxColors.bgHard,
                      child: widget.leftPane,
                    ),
                  ),
                ),
              ),
            ),

            // Left Edge Rail / Expander (Visible when Left Pane is hidden, suppressed in Zen Mode)
            if (!layoutState.isLeftPaneVisible && !layoutState.isZenMode)
              TactilePressable(
                tooltip: 'Show Files Explorer (Ctrl+B) • Click or drag to open',
                onTap: () => ref.read(layoutProvider.notifier).setLeftPaneVisible(true),
                pressedScale: 0.96,
                child: Material(
                  color: GruvboxColors.bgHard,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      if (details.delta.dx > 4) {
                        ref.read(layoutProvider.notifier).setLeftPaneVisible(true);
                      }
                    },
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75)),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_outlined, color: GruvboxColors.fgMuted, size: 14),
                          const SizedBox(height: 5),
                          Icon(Icons.chevron_right_rounded, color: GruvboxColors.fgMuted, size: 15),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Left Ergonomic Resize Divider (10px hit target, quiet architectural seam)
            if (layoutState.isLeftPaneVisible)
              _PaneResizeDivider(
                isDragging: _isDraggingLeft,
                onDoubleTap: () => ref.read(layoutProvider.notifier).resetLeftWidth(),
                onDragStart: (_) {
                  _dragStartLeftWidth = leftWidth;
                  _dragDeltaLeft = 0.0;
                  setState(() => _isDraggingLeft = true);
                },
                onDragUpdate: (details) {
                  _dragDeltaLeft += details.delta.dx;
                  final proposedWidth = _dragStartLeftWidth + _dragDeltaLeft;
                  if (proposedWidth < 85.0) {
                    setState(() => _isDraggingLeft = false);
                    if (_dragStartLeftWidth >= minLeftPx) {
                      ref.read(layoutProvider.notifier).updateLeftWidth(_dragStartLeftWidth);
                    }
                    ref.read(layoutProvider.notifier).setLeftPaneVisible(false);
                    ref.read(layoutProvider.notifier).persistPaneWidths();
                  } else {
                    final maxAllowedLeft =
                        (availableForSidebars - rightWidth).clamp(minLeftPx, maxLeftPx);
                    ref.read(layoutProvider.notifier).updateLeftWidth(
                          proposedWidth.clamp(minLeftPx, maxAllowedLeft),
                        );
                  }
                },
                onDragEnd: (_) {
                  setState(() => _isDraggingLeft = false);
                  ref.read(layoutProvider.notifier).persistPaneWidths();
                },
                onDragCancel: () {
                  setState(() => _isDraggingLeft = false);
                },
              ),

            // Center Editor Pane (Expands dynamically to fill workspace)
            Expanded(
              child: ColoredBox(
                color: GruvboxColors.bg,
                child: widget.centerPane,
              ),
            ),

            // Right Ergonomic Resize Divider
            if (layoutState.isRightPaneVisible)
              _PaneResizeDivider(
                isDragging: _isDraggingRight,
                onDoubleTap: () => ref.read(layoutProvider.notifier).resetRightWidth(),
                onDragStart: (_) {
                  _dragStartRightWidth = rightWidth;
                  _dragDeltaRight = 0.0;
                  setState(() => _isDraggingRight = true);
                },
                onDragUpdate: (details) {
                  _dragDeltaRight -= details.delta.dx;
                  final proposedWidth = _dragStartRightWidth + _dragDeltaRight;
                  if (proposedWidth < 100.0) {
                    setState(() => _isDraggingRight = false);
                    if (_dragStartRightWidth >= minRightPx) {
                      ref.read(layoutProvider.notifier).updateRightWidth(_dragStartRightWidth);
                    }
                    ref.read(layoutProvider.notifier).setRightPaneVisible(false);
                    ref.read(layoutProvider.notifier).persistPaneWidths();
                  } else {
                    final maxAllowedRight =
                        (availableForSidebars - leftWidth).clamp(minRightPx, maxRightPx);
                    ref.read(layoutProvider.notifier).updateRightWidth(
                          proposedWidth.clamp(minRightPx, maxAllowedRight),
                        );
                  }
                },
                onDragEnd: (_) {
                  setState(() => _isDraggingRight = false);
                  ref.read(layoutProvider.notifier).persistPaneWidths();
                },
                onDragCancel: () {
                  setState(() => _isDraggingRight = false);
                },
              ),

            // Right Edge Rail / Expander (Visible when Right Pane is hidden, suppressed in Zen Mode)
            if (!layoutState.isRightPaneVisible && !layoutState.isZenMode)
              TactilePressable(
                tooltip: 'Show AI Assistant & Sidecar (Ctrl+J) • Click or drag to open',
                onTap: () => ref.read(layoutProvider.notifier).setRightPaneVisible(true),
                pressedScale: 0.96,
                child: Material(
                  color: GruvboxColors.bgHard,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      if (details.delta.dx < -4) {
                        ref.read(layoutProvider.notifier).setRightPaneVisible(true);
                      }
                    },
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75)),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkQuillSparkMark(color: GruvboxColors.fgMuted, size: 14),
                          const SizedBox(height: 5),
                          Icon(Icons.chevron_left_rounded, color: GruvboxColors.fgMuted, size: 15),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Right Pane (Zero duration when dragging for instant 60/120Hz tracking; smooth when toggling)
            AnimatedContainer(
              duration: _isDraggingRight ? Duration.zero : _animationDuration,
              curve: _animationCurve,
              width: rightWidth,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: minRightPx,
                  maxWidth: 1200.0,
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: rightWidth > 0 ? rightWidth : _lastOpenRightWidth.clamp(minRightPx, 1200.0),
                    child: ColoredBox(
                      color: GruvboxColors.bgHard,
                      child: widget.rightPane,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Quiet architectural seam between panes. Sits almost invisible at rest as a warm
/// tone-step hairline, revealing a crisp burnished capsule only on hover or drag.
class _PaneResizeDivider extends StatefulWidget {
  final bool isDragging;
  final void Function(DragStartDetails) onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final void Function(DragEndDetails) onDragEnd;
  final VoidCallback onDragCancel;
  final VoidCallback onDoubleTap;

  const _PaneResizeDivider({
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onDoubleTap,
  });

  @override
  State<_PaneResizeDivider> createState() => _PaneResizeDividerState();
}

class _PaneResizeDividerState extends State<_PaneResizeDivider> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _isHovered || widget.isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        onHorizontalDragStart: widget.onDragStart,
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: widget.onDragEnd,
        onHorizontalDragCancel: widget.onDragCancel,
        child: Tooltip(
          message: 'Drag to adjust width • Double-click to reset',
          waitDuration: const Duration(milliseconds: 650),
          child: SizedBox(
            width: 10.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: AppMotion.snappyEaseOut,
                  width: active ? 2.0 : 0.75,
                  color: active ? GruvboxColors.accent : GruvboxColors.subtleDivider,
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: active ? 1.0 : 0.0,
                  child: Container(
                    width: 4.0,
                    height: 32.0,
                    decoration: BoxDecoration(
                      color: GruvboxColors.accent,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
