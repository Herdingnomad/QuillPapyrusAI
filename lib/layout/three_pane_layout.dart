import 'package:flutter/material.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class ThreePaneLayout extends StatefulWidget {
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
  State<ThreePaneLayout> createState() => _ThreePaneLayoutState();
}

class _ThreePaneLayoutState extends State<ThreePaneLayout> {
  double _leftFraction = 0.25;
  double _centerFraction = 0.50;
  double _rightFraction = 0.25;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final minLeft = 180 / totalWidth;
        final minRight = 180 / totalWidth;
        final minCenter = 250 / totalWidth;

        return Row(
          children: [
            // Left Pane
            SizedBox(
              width: totalWidth * _leftFraction,
              child: Container(
                decoration: const BoxDecoration(
                  color: GruvboxColors.bg,
                  border: Border(right: BorderSide(color: GruvboxColors.bg3, width: 1)),
                ),
                child: widget.leftPane,
              ),
            ),

            // Left Divider
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  final deltaFraction = details.delta.dx / totalWidth;
                  double newLeft = _leftFraction + deltaFraction;
                  if (newLeft < minLeft) newLeft = minLeft;

                  double newCenter = _centerFraction - (newLeft - _leftFraction);
                  if (newCenter < minCenter) {
                    newCenter = minCenter;
                    newLeft = _leftFraction + (_centerFraction - newCenter);
                  }

                  _leftFraction = newLeft;
                  _centerFraction = newCenter;
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Container(
                  width: 4,
                  color: GruvboxColors.bg3,
                ),
              ),
            ),

            // Center Pane
            Expanded(
              child: Container(
                color: GruvboxColors.bg,
                child: widget.centerPane,
              ),
            ),

            // Right Divider
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  final deltaFraction = details.delta.dx / totalWidth;
                  double newRight = _rightFraction - deltaFraction;
                  if (newRight < minRight) newRight = minRight;

                  double newCenter = _centerFraction - (newRight - _rightFraction);
                  if (newCenter < minCenter) {
                    newCenter = minCenter;
                    newRight = _rightFraction + (_centerFraction - newCenter);
                  }

                  _rightFraction = newRight;
                  _centerFraction = newCenter;
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Container(
                  width: 4,
                  color: GruvboxColors.bg3,
                ),
              ),
            ),

            // Right Pane
            SizedBox(
              width: totalWidth * _rightFraction,
              child: Container(
                decoration: const BoxDecoration(
                  color: GruvboxColors.bg,
                  border: Border(left: BorderSide(color: GruvboxColors.bg3, width: 1)),
                ),
                child: widget.rightPane,
              ),
            ),
          ],
        );
      },
    );
  }
}
