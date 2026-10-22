import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/sync_models.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/sync_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/sync_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class SyncSettingsDialog extends ConsumerStatefulWidget {
  const SyncSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const SyncSettingsDialog(),
    );
  }

  @override
  ConsumerState<SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends ConsumerState<SyncSettingsDialog> {
  bool _isReconciling = false;
  String? _reconcileMessage;

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final activePath = syncState.syncFolderPath;
    final currentWorkspace = ref.watch(workspaceProvider).rootUri;

    final discoveredPaths = syncState.discoveredSyncPaths.isNotEmpty
        ? syncState.discoveredSyncPaths
        : SyncService.instance.getDiscoveredSyncPaths();

    final hasBothPhonePaths = Platform.isAndroid &&
        Directory(SyncService.primaryAndroidSyncPath).existsSync() &&
        Directory(SyncService.fallbackAndroidSyncPath).existsSync();

    return Dialog(
      backgroundColor: GruvboxColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: GruvboxColors.bg3, width: 1.2),
      ),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.cloud_sync, color: GruvboxColors.aqua, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Sync & Storage Management',
                        style: TextStyle(
                          color: GruvboxColors.fg,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Manage OneDrive Journal-Log sync folders & reconciliation',
                        style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    _buildStatusCard(syncState),
                    const SizedBox(height: 16),

                    // Detected / Available Target Folders
                    Text(
                      'Sync Target Folder',
                      style: TextStyle(
                        color: GruvboxColors.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the folder that syncs with OneDrive. On Android, OneSync targets the Autosync folder.',
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                    ),
                    const SizedBox(height: 10),

                    // List of discovered folders
                    ...discoveredPaths.map((path) => _buildFolderOption(
                          path: path,
                          isActive: path == activePath,
                          isWorkspace: path == currentWorkspace,
                          isPrimary: Platform.isAndroid && path == SyncService.primaryAndroidSyncPath,
                          label: _getFolderLabel(path),
                          subtitle: _getFolderSubtitle(path),
                        )),

                    // Browse custom folder button
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GruvboxColors.fg,
                        side: BorderSide(color: GruvboxColors.bg3),
                      ),
                      icon: Icon(Icons.folder_open, size: 16, color: GruvboxColors.yellow),
                      label: const Text('Browse Custom Sync Folder...'),
                      onPressed: () async {
                        final picked = await ref.read(safStorageServiceProvider).pickDirectory(forcePicker: true);
                        if (picked != null) {
                          await ref.read(syncProvider.notifier).setCustomSyncFolder(picked);
                        }
                      },
                    ),

                    // Folder Consolidation / Merge Card (shown when both phone paths exist)
                    if (hasBothPhonePaths) ...[
                      const SizedBox(height: 16),
                      _buildReconcileCard(),
                    ],

                    // Conflicts section if any
                    if (syncState.conflicts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildConflictsSection(syncState.conflicts),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Switch(
                      value: syncState.isAutoSyncEnabled,
                      activeThumbColor: GruvboxColors.green,
                      onChanged: (val) {
                        ref.read(syncProvider.notifier).toggleAutoSync();
                      },
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live File Watcher',
                      style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GruvboxColors.green,
                    foregroundColor: GruvboxColors.bg,
                  ),
                  icon: Icon(
                    syncState.status == SyncStatus.syncing ? Icons.hourglass_top : Icons.sync,
                    size: 16,
                  ),
                  label: Text(syncState.status == SyncStatus.syncing ? 'Syncing...' : 'Sync Now'),
                  onPressed: syncState.status == SyncStatus.syncing
                      ? null
                      : () {
                          ref.read(syncProvider.notifier).triggerSync();
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(SyncState state) {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    switch (state.status) {
      case SyncStatus.synced:
        statusColor = GruvboxColors.green;
        statusIcon = Icons.cloud_done;
        statusTitle = 'Everything Up to Date';
        break;
      case SyncStatus.syncing:
        statusColor = GruvboxColors.aqua;
        statusIcon = Icons.sync;
        statusTitle = 'Synchronizing...';
        break;
      case SyncStatus.conflict:
        statusColor = GruvboxColors.orange;
        statusIcon = Icons.warning_amber;
        statusTitle = '${state.conflicts.length} Conflict(s) Detected';
        break;
      case SyncStatus.error:
        statusColor = GruvboxColors.red;
        statusIcon = Icons.cloud_off;
        statusTitle = 'Sync Error';
        break;
      case SyncStatus.idle:
        statusColor = GruvboxColors.gray;
        statusIcon = Icons.cloud_queue;
        statusTitle = 'Idle';
        break;
    }

    final lastSyncStr = state.lastSyncTime != null
        ? '${state.lastSyncTime!.hour.toString().padLeft(2, '0')}:${state.lastSyncTime!.minute.toString().padLeft(2, '0')}'
        : 'Never';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withAlpha(100), width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Last checked: $lastSyncStr  •  Files scanned: ${state.filesChecked}  •  Synced: ${state.filesSynced}',
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(color: GruvboxColors.red, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderOption({
    required String path,
    required bool isActive,
    required bool isWorkspace,
    required bool isPrimary,
    required String label,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? GruvboxColors.bg2 : GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? GruvboxColors.aqua : GruvboxColors.bg3,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPrimary ? Icons.folder_special : Icons.folder,
            color: isActive ? GruvboxColors.aqua : GruvboxColors.yellow,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: GruvboxColors.fg,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: GruvboxColors.green.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: GruvboxColors.green, width: 0.8),
                        ),
                        child: Text(
                          'OneSync Target',
                          style: TextStyle(color: GruvboxColors.green, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isActive) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: GruvboxColors.aqua.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: GruvboxColors.aqua, width: 0.8),
                        ),
                        child: Text(
                          'Active Sync',
                          style: TextStyle(color: GruvboxColors.aqua, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  path,
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 11, fontFamily: 'monospace'),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (!isActive)
                      ActionChip(
                        label: const Text('Set as Active Sync', style: TextStyle(fontSize: 11)),
                        backgroundColor: GruvboxColors.bg,
                        onPressed: () {
                          ref.read(syncProvider.notifier).setCustomSyncFolder(path);
                        },
                      ),
                    ActionChip(
                      label: Text(
                        isWorkspace ? 'Active Workspace' : 'Open as Workspace',
                        style: TextStyle(
                          fontSize: 11,
                          color: isWorkspace ? GruvboxColors.green : GruvboxColors.fg,
                        ),
                      ),
                      backgroundColor: GruvboxColors.bg,
                      avatar: Icon(
                        isWorkspace ? Icons.check_circle : Icons.folder_open,
                        size: 14,
                        color: isWorkspace ? GruvboxColors.green : GruvboxColors.yellow,
                      ),
                      onPressed: isWorkspace
                          ? null
                          : () {
                              ref.read(workspaceProvider.notifier).loadWorkspace(path);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Switched workspace to $label'),
                                  backgroundColor: GruvboxColors.bg1,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconcileCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GruvboxColors.yellow.withAlpha(120), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.merge_type, color: GruvboxColors.yellow, size: 20),
              const SizedBox(width: 8),
              Text(
                'Consolidate Phone Folders',
                style: TextStyle(
                  color: GruvboxColors.yellow,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Both Documents/Journal-Log and Autosync/Journal-Log exist on your device. Safe merge copies any newer files from Documents into Autosync so that OneSync can sync everything with OneDrive.',
            style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
          ),
          if (_reconcileMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _reconcileMessage!,
              style: TextStyle(color: GruvboxColors.green, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GruvboxColors.yellow,
              foregroundColor: GruvboxColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: _isReconciling
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                  )
                : const Icon(Icons.call_merge, size: 16),
            label: Text(_isReconciling ? 'Merging...' : 'Merge Documents -> Autosync'),
            onPressed: _isReconciling
                ? null
                : () async {
                    setState(() {
                      _isReconciling = true;
                      _reconcileMessage = null;
                    });
                    try {
                      final count = await ref.read(syncProvider.notifier).reconcileDocumentsAndAutosync();
                      setState(() {
                        _isReconciling = false;
                        _reconcileMessage = 'Successfully merged $count file(s) into Autosync/Journal-Log!';
                      });
                    } catch (e) {
                      setState(() {
                        _isReconciling = false;
                        _reconcileMessage = 'Merge error: $e';
                      });
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildConflictsSection(List<SyncConflict> conflicts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GruvboxColors.orange, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: GruvboxColors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Sync Conflicts (${conflicts.length})',
                style: TextStyle(color: GruvboxColors.orange, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                child: const Text('Dismiss All', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  ref.read(syncProvider.notifier).clearConflicts();
                },
              ),
            ],
          ),
          ...conflicts.map((c) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(c.relativePath, style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                subtitle: Text('Conflict copy saved safely', style: TextStyle(color: GruvboxColors.aqua, fontSize: 10)),
                trailing: TextButton(
                  child: const Text('Open'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(editorProvider.notifier).openFile(c.conflictUri, c.relativePath);
                  },
                ),
              )),
        ],
      ),
    );
  }

  String _getFolderLabel(String path) {
    if (path.contains('Autosync')) {
      return 'Autosync / Journal-Log';
    } else if (path.contains('Documents')) {
      return 'Documents / Journal-Log';
    }
    return path.split(RegExp(r'[\\/]')).last;
  }

  String _getFolderSubtitle(String path) {
    if (path.contains('Autosync')) {
      return 'Cloud sync folder managed by OneSync / Autosync app';
    } else if (path.contains('Documents')) {
      return 'Device internal Documents folder';
    }
    return 'Custom sync directory';
  }
}
