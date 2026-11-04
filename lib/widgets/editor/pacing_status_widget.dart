import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/pacing_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/pacing_dialog.dart';

class PacingStatusWidget extends ConsumerWidget {
  const PacingStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pacing = ref.watch(pacingProvider);
    final target = pacing.target;
    final todayNet = pacing.todayNetWords;
    final dailyProg = pacing.dailyProgress;
    final totalWords = pacing.totalManuscriptWords;
    final msProg = pacing.manuscriptProgress;

    // Check if active file or selected folder has a folder goal
    final workspaceState = ref.watch(workspaceProvider);
    final activeFileUri = ref.watch(editorProvider).activeFileUri;
    String? folderUriWithGoal;
    String? folderNameWithGoal;

    if (activeFileUri != null) {
      // Find parent directory of active file
      final parent = p.dirname(activeFileUri);
      if (pacing.folderTargets.containsKey(parent)) {
        folderUriWithGoal = parent;
        folderNameWithGoal = p.basename(parent);
      }
    }
    if (folderUriWithGoal == null && workspaceState.selectedFolderUri != null) {
      if (pacing.folderTargets.containsKey(workspaceState.selectedFolderUri)) {
        folderUriWithGoal = workspaceState.selectedFolderUri;
        folderNameWithGoal = p.basename(workspaceState.selectedFolderUri!);
      }
    }

    final folderTarget = folderUriWithGoal != null ? pacing.folderTargets[folderUriWithGoal] : null;
    final folderWords = folderUriWithGoal != null ? pacing.wordsForFolder(folderUriWithGoal) : 0;
    final folderProg = folderUriWithGoal != null ? pacing.progressForFolder(folderUriWithGoal) : 0.0;

    return InkWell(
      onTap: () => PacingDialog.show(
        context,
        folderUri: folderUriWithGoal,
        folderName: folderNameWithGoal,
      ),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GruvboxColors.bg1,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: GruvboxColors.bg3, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Daily ring
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                value: dailyProg,
                strokeWidth: 2.2,
                backgroundColor: GruvboxColors.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  dailyProg >= 1.0 ? GruvboxColors.green : GruvboxColors.yellow,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Today: $todayNet / ${target.targetDailyWords}w',
              style: TextStyle(
                color: dailyProg >= 1.0 ? GruvboxColors.green : GruvboxColors.fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (folderTarget != null) ...[
              const SizedBox(width: 8),
              Container(width: 1, height: 12, color: GruvboxColors.bg3),
              const SizedBox(width: 8),
              Icon(Icons.track_changes_rounded, size: 13, color: GruvboxColors.yellow),
              const SizedBox(width: 4),
              Text(
                '$folderNameWithGoal: $folderWords / ${folderTarget.targetManuscriptWords}w (${(folderProg * 100).toInt()}%)',
                style: TextStyle(
                  color: folderProg >= 1.0 ? GruvboxColors.green : GruvboxColors.fg2,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Container(width: 1, height: 12, color: GruvboxColors.bg3),
            const SizedBox(width: 8),
            // Manuscript total
            Icon(Icons.auto_stories, size: 13, color: GruvboxColors.aqua),
            const SizedBox(width: 4),
            Text(
              '${(msProg * 100).toStringAsFixed(1)}% ($totalWords / ${target.targetManuscriptWords}w)',
              style: TextStyle(
                color: GruvboxColors.gray,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
