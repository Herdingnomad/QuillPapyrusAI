import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/sync_models.dart';
import 'package:quill_papyrus_ai/providers/sync_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/editor/sync_settings_dialog.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final status = syncState.status;

    Color iconColor;
    IconData iconData;
    String tooltipText;
    String statusLabel;

    final folderName = syncState.syncFolderPath.contains('Autosync')
        ? 'Autosync/Journal-Log'
        : (syncState.syncFolderPath.contains('Documents') ? 'Documents/Journal-Log' : 'Journal-Log');

    switch (status) {
      case SyncStatus.synced:
        iconColor = GruvboxColors.green;
        iconData = Icons.cloud_done;
        statusLabel = 'In Sync';
        tooltipText = 'Synced with $folderName • Tap for settings';
        break;
      case SyncStatus.syncing:
        iconColor = GruvboxColors.aqua;
        iconData = Icons.sync;
        statusLabel = 'Syncing...';
        tooltipText = 'Synchronizing with $folderName...';
        break;
      case SyncStatus.conflict:
        iconColor = GruvboxColors.orange;
        iconData = Icons.warning_amber;
        statusLabel = 'Conflict';
        tooltipText = '${syncState.conflicts.length} conflict(s) • Tap to resolve';
        break;
      case SyncStatus.error:
        iconColor = GruvboxColors.red;
        iconData = Icons.cloud_off;
        statusLabel = 'Sync Error';
        tooltipText = '${syncState.errorMessage ?? 'Sync error'} • Tap for settings';
        break;
      case SyncStatus.idle:
        iconColor = GruvboxColors.gray;
        iconData = Icons.cloud_queue;
        statusLabel = 'Autosync';
        tooltipText = 'Target: $folderName • Tap for sync & folders';
        break;
    }

    return Tooltip(
      message: tooltipText,
      child: InkWell(
        onTap: () {
          SyncSettingsDialog.show(context);
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: status == SyncStatus.conflict ? GruvboxColors.orange : GruvboxColors.bg3,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
