import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/diff_model.dart';
import 'package:quill_papyrus_ai/providers/diff_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';

class InlineDiffWidget extends ConsumerWidget {
  const InlineDiffWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diffState = ref.watch(diffProvider);
    final editorFont = ref.watch(layoutProvider.select((s) => s.editorFont));
    final proposal = diffState.proposal;

    if (proposal == null) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final maxDiffHeight = (screenHeight * 0.24).clamp(96.0, 168.0);
    final isDark = GruvboxColors.activeTheme.isDark;
    final baseDiffStyle = editorFont.editorStyle(
      color: GruvboxColors.fg,
      fontSizeOverride: 13.5,
      heightOverride: 1.52,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 6.0),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(8.0),
        border: Border(
          left: BorderSide(color: GruvboxColors.accent, width: 3.0),
          top: BorderSide(color: GruvboxColors.hairlineBorder, width: 0.75),
          right: BorderSide(color: GruvboxColors.hairlineBorder, width: 0.75),
          bottom: BorderSide(color: GruvboxColors.hairlineBorder, width: 0.75),
        ),
        boxShadow: AppMaterials.paperSheetShadows(isDark: isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Proofreader's Slip Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: GruvboxColors.bgHard.withValues(alpha: 0.75),
              border: Border(
                bottom: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
              ),
            ),
            child: Row(
              children: [
                InkQuillSparkMark(color: GruvboxColors.accent, size: 14),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    proposal.actionTitle,
                    style: AppTypography.uiLabel(
                      GruvboxColors.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'SUGGESTED EDIT',
                  style: AppTypography.uiLabel(
                    GruvboxColors.fgMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ).copyWith(letterSpacing: 0.9),
                ),
              ],
            ),
          ),

          // Editorial Galley Diff Content View
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            constraints: BoxConstraints(maxHeight: maxDiffHeight),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: RichText(
                text: TextSpan(
                  style: baseDiffStyle,
                  children: proposal.chunks.map((chunk) {
                    if (chunk.type == DiffType.addition) {
                      return TextSpan(
                        text: chunk.text,
                        style: baseDiffStyle.copyWith(
                          backgroundColor: GruvboxColors.additionBg,
                          color: GruvboxColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    } else if (chunk.type == DiffType.deletion) {
                      return TextSpan(
                        text: chunk.text,
                        style: baseDiffStyle.copyWith(
                          backgroundColor: GruvboxColors.deletionBg,
                          color: GruvboxColors.red,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: GruvboxColors.red,
                        ),
                      );
                    } else {
                      return TextSpan(
                        text: chunk.text,
                        style: baseDiffStyle,
                      );
                    }
                  }).toList(),
                ),
              ),
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: GruvboxColors.bgHard.withValues(alpha: 0.8),
              border: Border(
                top: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GruvboxColors.fgMuted,
                    side: BorderSide(color: GruvboxColors.subtleDivider),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    minimumSize: const Size(60, 26),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 13),
                  label: const Text('Reject ✗', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    ref.read(diffProvider.notifier).rejectDiff();
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GruvboxColors.fg,
                    side: BorderSide(color: GruvboxColors.accent.withValues(alpha: 0.55)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    minimumSize: const Size(60, 26),
                  ),
                  icon: Icon(Icons.subdirectory_arrow_right_rounded,
                      size: 13, color: GruvboxColors.accent),
                  label: const Text(
                    'Insert Below ↳',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    ref.read(diffProvider.notifier).insertProposedBelow();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GruvboxColors.bg1,
                        duration: const Duration(seconds: 1),
                        content: Text(
                          'Inserted AI generation below selection',
                          style: TextStyle(color: GruvboxColors.accent),
                        ),
                      ),
                    );
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GruvboxColors.accent,
                    foregroundColor: GruvboxColors.bgHard,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
                    minimumSize: const Size(60, 26),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 13),
                  label: const Text(
                    'Accept (Replace) ✓',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    ref.read(diffProvider.notifier).acceptDiff();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GruvboxColors.bg1,
                        duration: const Duration(seconds: 1),
                        content: Text(
                          'Applied AI changes to document',
                          style: TextStyle(color: GruvboxColors.green),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
