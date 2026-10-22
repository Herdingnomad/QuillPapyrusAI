import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

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
  static const Duration _animationDuration = Duration(milliseconds: 220);
  static const Curve _animationCurve = Curves.easeInOutCubic;

  bool _isDraggingLeft = false;
  bool _isDraggingRight = false;

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        final minLeftPx = 140.0;
        final maxLeftPx = (totalWidth * 0.45).clamp(minLeftPx, totalWidth * 0.45);
        final leftWidth = layoutState.isLeftPaneVisible
            ? (totalWidth * layoutState.leftFraction).clamp(minLeftPx, maxLeftPx)
            : 0.0;

        final minRightPx = 180.0;
        final maxRightPx = (totalWidth * 0.50).clamp(minRightPx, totalWidth * 0.50);
        final rightWidth = layoutState.isRightPaneVisible
            ? (totalWidth * layoutState.rightFraction).clamp(minRightPx, maxRightPx)
            : 0.0;

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
                  minWidth: 140.0,
                  maxWidth: 1200.0,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: leftWidth > 0 ? leftWidth : 140.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg,
                        border: Border(right: BorderSide(color: GruvboxColors.bg3, width: 1)),
                      ),
                      child: widget.leftPane,
                    ),
                  ),
                ),
              ),
            ),

            // Left Edge Rail / Expander (Visible when Left Pane is hidden, suppressed in Zen Mode)
            if (!layoutState.isLeftPaneVisible && !layoutState.isZenMode)
              Tooltip(
                message: 'Show Files Explorer (Ctrl+B) • Click or drag to open',
                child: Material(
                  color: GruvboxColors.bgHard,
                  child: InkWell(
                    onTap: () => ref.read(layoutProvider.notifier).setLeftPaneVisible(true),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        if (details.delta.dx > 4) {
                          ref.read(layoutProvider.notifier).setLeftPaneVisible(true);
                          ref.read(layoutProvider.notifier).updateLeftFraction((160.0 + details.delta.dx) / totalWidth);
                          setState(() => _isDraggingLeft = true);
                        }
                      },
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: GruvboxColors.bg3, width: 1)),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_outlined, color: GruvboxColors.yellow, size: 14),
                            const SizedBox(height: 4),
                            Icon(Icons.chevron_right, color: GruvboxColors.gray, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Left Ergonomic Resize Divider (Generous 16px hit target, zero drag latency)
            if (layoutState.isLeftPaneVisible)
              _PaneResizeDivider(
                isDragging: _isDraggingLeft,
                isLeft: true,
                onDoubleTap: () => ref.read(layoutProvider.notifier).resetLeftWidth(),
                onDragStart: (_) {
                  setState(() => _isDraggingLeft = true);
                },
                onDragUpdate: (details) {
                  final newWidth = leftWidth + details.delta.dx;
                  if (newWidth < 80) {
                    ref.read(layoutProvider.notifier).setLeftPaneVisible(false);
                    ref.read(layoutProvider.notifier).persistFractions();
                  } else {
                    ref.read(layoutProvider.notifier).updateLeftFraction(newWidth / totalWidth);
                  }
                },
                onDragEnd: (_) {
                  setState(() => _isDraggingLeft = false);
                  ref.read(layoutProvider.notifier).persistFractions();
                },
                onDragCancel: () {
                  setState(() => _isDraggingLeft = false);
                },
              ),

            // Center Editor Pane (Expands dynamically to fill workspace)
            Expanded(
              child: Container(
                color: GruvboxColors.bg,
                child: widget.centerPane,
              ),
            ),

            // Right Ergonomic Resize Divider (Generous 16px hit target, zero drag latency)
            if (layoutState.isRightPaneVisible)
              _PaneResizeDivider(
                isDragging: _isDraggingRight,
                isLeft: false,
                onDoubleTap: () => ref.read(layoutProvider.notifier).resetRightWidth(),
                onDragStart: (_) {
                  setState(() => _isDraggingRight = true);
                },
                onDragUpdate: (details) {
                  final newWidth = rightWidth - details.delta.dx;
                  if (newWidth < 100) {
                    ref.read(layoutProvider.notifier).setRightPaneVisible(false);
                    ref.read(layoutProvider.notifier).persistFractions();
                  } else {
                    ref.read(layoutProvider.notifier).updateRightFraction(newWidth / totalWidth);
                  }
                },
                onDragEnd: (_) {
                  setState(() => _isDraggingRight = false);
                  ref.read(layoutProvider.notifier).persistFractions();
                },
                onDragCancel: () {
                  setState(() => _isDraggingRight = false);
                },
              ),

            // Right Edge Rail / Expander (Visible when Right Pane is hidden, suppressed in Zen Mode)
            if (!layoutState.isRightPaneVisible && !layoutState.isZenMode)
              Tooltip(
                message: 'Show AI Assistant & Sidecar (Ctrl+J) • Click or drag to open',
                child: Material(
                  color: GruvboxColors.bgHard,
                  child: InkWell(
                    onTap: () => ref.read(layoutProvider.notifier).setRightPaneVisible(true),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        if (details.delta.dx < -4) {
                          ref.read(layoutProvider.notifier).setRightPaneVisible(true);
                          ref.read(layoutProvider.notifier).updateRightFraction((200.0 - details.delta.dx) / totalWidth);
                          setState(() => _isDraggingRight = true);
                        }
                      },
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: GruvboxColors.bg3, width: 1)),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.smart_toy_outlined, color: GruvboxColors.aqua, size: 14),
                            const SizedBox(height: 4),
                            Icon(Icons.chevron_left, color: GruvboxColors.gray, size: 16),
                          ],
                        ),
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
                  minWidth: 180.0,
                  maxWidth: 1200.0,
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: rightWidth > 0 ? rightWidth : 180.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg,
                        border: Border(left: BorderSide(color: GruvboxColors.bg3, width: 1)),
                      ),
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

/// Ergonomic, high-responsiveness divider handle with generous 16px hit target,
/// tactile grab indicator, hover highlights, and double-click reset.
class _PaneResizeDivider extends StatefulWidget {
  final bool isDragging;
  final bool isLeft;
  final void Function(DragStartDetails) onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final void Function(DragEndDetails) onDragEnd;
  final VoidCallback onDragCancel;
  final VoidCallback onDoubleTap;

  const _PaneResizeDivider({
    required this.isDragging,
    required this.isLeft,
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
    final dividerColor = active ? GruvboxColors.accent : GruvboxColors.bg3;
    final handleDotColor = active ? GruvboxColors.bgHard : GruvboxColors.gray.withValues(alpha: 0.5);

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
          waitDuration: const Duration(milliseconds: 600),
          child: Container(
            width: 16.0, // Generous 16px hit-testing region for mouse, trackpad, and touch
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Clean center divider line (expands to 2.5px with accent highlight on hover/drag)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: active ? 2.5 : 1.0,
                  color: dividerColor,
                ),

                // Tactile grab handle capsule with 3 grip dots
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: active ? 6.0 : 4.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: active ? GruvboxColors.accent : GruvboxColors.bg2,
                    borderRadius: BorderRadius.circular(3.0),
                    border: Border.all(
                      color: active ? GruvboxColors.accent : GruvboxColors.bg3,
                      width: 1.0,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: GruvboxColors.accent.withValues(alpha: 0.4),
                              blurRadius: 4.0,
                              spreadRadius: 1.0,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 2.0,
                          height: 2.0,
                          decoration: BoxDecoration(
                            color: handleDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 2.0,
                          height: 2.0,
                          decoration: BoxDecoration(
                            color: handleDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 2.0,
                          height: 2.0,
                          decoration: BoxDecoration(
                            color: handleDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
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
