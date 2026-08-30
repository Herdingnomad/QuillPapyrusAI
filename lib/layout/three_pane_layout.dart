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

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftWidth = layoutState.isLeftPaneVisible ? (totalWidth * layoutState.leftFraction).clamp(160.0, totalWidth * 0.40) : 0.0;
        final rightWidth = layoutState.isRightPaneVisible ? (totalWidth * layoutState.rightFraction).clamp(180.0, totalWidth * 0.45) : 0.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane (Smooth Sliding & Collapsible)
            AnimatedContainer(
              duration: _animationDuration,
              curve: _animationCurve,
              width: leftWidth,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: 160.0,
                  maxWidth: 600.0,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: leftWidth > 0 ? leftWidth : 160.0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: GruvboxColors.bg,
                        border: Border(right: BorderSide(color: GruvboxColors.bg3, width: 1)),
                      ),
                      child: widget.leftPane,
                    ),
                  ),
                ),
              ),
            ),

            // Left Edge Rail / Expander (Visible when Left Pane is hidden)
            if (!layoutState.isLeftPaneVisible)
              Tooltip(
                message: 'Show Files Explorer (Ctrl+B)',
                child: Material(
                  color: GruvboxColors.bgHard,
                  child: InkWell(
                    onTap: () => ref.read(layoutProvider.notifier).setLeftPaneVisible(true),
                    child: Container(
                      width: 24,
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: GruvboxColors.bg3, width: 1)),
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_outlined, color: GruvboxColors.yellow, size: 14),
                          SizedBox(height: 4),
                          Icon(Icons.chevron_right, color: GruvboxColors.gray, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Left Resize & Slide-to-Close Divider
            if (layoutState.isLeftPaneVisible)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  final newWidth = leftWidth + details.delta.dx;
                  if (newWidth < 110) {
                    // Snap slide closed
                    ref.read(layoutProvider.notifier).setLeftPaneVisible(false);
                  } else {
                    ref.read(layoutProvider.notifier).updateLeftFraction(newWidth / totalWidth);
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    width: 5,
                    color: GruvboxColors.bg3,
                    child: Center(
                      child: Container(
                        width: 1,
                        color: GruvboxColors.gray.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),

            // Center Editor Pane (Expands to fill available space)
            Expanded(
              child: Container(
                color: GruvboxColors.bg,
                child: widget.centerPane,
              ),
            ),

            // Right Resize & Slide-to-Close Divider
            if (layoutState.isRightPaneVisible)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  final newWidth = rightWidth - details.delta.dx;
                  if (newWidth < 110) {
                    // Snap slide closed
                    ref.read(layoutProvider.notifier).setRightPaneVisible(false);
                  } else {
                    ref.read(layoutProvider.notifier).updateRightFraction(newWidth / totalWidth);
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    width: 5,
                    color: GruvboxColors.bg3,
                    child: Center(
                      child: Container(
                        width: 1,
                        color: GruvboxColors.gray.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),

            // Right Edge Rail / Expander (Visible when Right Pane is hidden)
            if (!layoutState.isRightPaneVisible)
              Tooltip(
                message: 'Show AI Assistant (Ctrl+J)',
                child: Material(
                  color: GruvboxColors.bgHard,
                  child: InkWell(
                    onTap: () => ref.read(layoutProvider.notifier).setRightPaneVisible(true),
                    child: Container(
                      width: 24,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: GruvboxColors.bg3, width: 1)),
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.smart_toy_outlined, color: GruvboxColors.aqua, size: 14),
                          SizedBox(height: 4),
                          Icon(Icons.chevron_left, color: GruvboxColors.gray, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Right Pane (Smooth Sliding & Collapsible)
            AnimatedContainer(
              duration: _animationDuration,
              curve: _animationCurve,
              width: rightWidth,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: 180.0,
                  maxWidth: 600.0,
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: rightWidth > 0 ? rightWidth : 180.0,
                    child: Container(
                      decoration: const BoxDecoration(
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
