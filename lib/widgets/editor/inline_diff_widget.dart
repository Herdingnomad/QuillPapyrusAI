import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/diff_model.dart';
import 'package:quill_papyrus_ai/providers/diff_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class InlineDiffWidget extends ConsumerWidget {
  const InlineDiffWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diffState = ref.watch(diffProvider);
    final proposal = diffState.proposal;

    if (proposal == null) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final maxDiffHeight = (screenHeight * 0.22).clamp(90.0, 150.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: GruvboxColors.aqua, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            decoration: const BoxDecoration(
              color: GruvboxColors.bg2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5.0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high, color: GruvboxColors.aqua, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    proposal.actionTitle,
                    style: const TextStyle(
                      color: GruvboxColors.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text(
                  'Inline Diff',
                  style: TextStyle(
                    color: GruvboxColors.gray,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Diff Content View
          Container(
            padding: const EdgeInsets.all(8.0),
            constraints: BoxConstraints(maxHeight: maxDiffHeight),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                  children: proposal.chunks.map((chunk) {
                    if (chunk.type == DiffType.addition) {
                      return TextSpan(
                        text: chunk.text,
                        style: const TextStyle(
                          backgroundColor: GruvboxColors.additionBg,
                          color: GruvboxColors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    } else if (chunk.type == DiffType.deletion) {
                      return TextSpan(
                        text: chunk.text,
                        style: const TextStyle(
                          backgroundColor: GruvboxColors.deletionBg,
                          color: GruvboxColors.red,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: GruvboxColors.red,
                        ),
                      );
                    } else {
                      return TextSpan(
                        text: chunk.text,
                        style: const TextStyle(
                          color: GruvboxColors.fg,
                        ),
                      );
                    }
                  }).toList(),
                ),
              ),
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: const BoxDecoration(
              color: GruvboxColors.bgHard,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(5.0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GruvboxColors.red,
                    side: const BorderSide(color: GruvboxColors.red),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(60, 26),
                  ),
                  icon: const Icon(Icons.close, size: 13),
                  label: const Text('Reject ✗', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    ref.read(diffProvider.notifier).rejectDiff();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GruvboxColors.green,
                    foregroundColor: GruvboxColors.bgHard,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    minimumSize: const Size(60, 26),
                  ),
                  icon: const Icon(Icons.check, size: 13),
                  label: const Text('Accept ✓', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ref.read(diffProvider.notifier).acceptDiff();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: GruvboxColors.bg1,
                        duration: Duration(seconds: 1),
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
