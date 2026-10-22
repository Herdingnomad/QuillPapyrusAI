import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/diff_model.dart';
import 'package:quill_papyrus_ai/models/scene_snapshot.dart';
import 'package:quill_papyrus_ai/providers/snapshot_provider.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class SnapshotManagerDialog extends ConsumerStatefulWidget {
  final String fileUri;
  final String fileName;
  final String currentContent;

  const SnapshotManagerDialog({
    super.key,
    required this.fileUri,
    required this.fileName,
    required this.currentContent,
  });

  static Future<void> show(
    BuildContext context, {
    required String fileUri,
    required String fileName,
    required String currentContent,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => SnapshotManagerDialog(
        fileUri: fileUri,
        fileName: fileName,
        currentContent: currentContent,
      ),
    );
  }

  @override
  ConsumerState<SnapshotManagerDialog> createState() => _SnapshotManagerDialogState();
}

class _SnapshotManagerDialogState extends ConsumerState<SnapshotManagerDialog> {
  SceneSnapshot? _selectedSnapshot;
  List<DiffChunk> _diffSegments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(snapshotProvider.notifier).loadSnapshots(widget.fileUri);
    });
  }

  void _computeDiff(SceneSnapshot snap) {
    setState(() {
      _selectedSnapshot = snap;
      _diffSegments = DiffService.computeLineDiff(snap.content, widget.currentContent);
    });
  }

  Future<void> _promptNewSnapshot() async {
    final noteController = TextEditingController();
    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GruvboxColors.bg,
        title: Text('Take Scene Snapshot', style: TextStyle(color: GruvboxColors.fg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Save an immutable checkpoint of "${widget.fileName}" before making major changes.',
              style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              style: TextStyle(color: GruvboxColors.fg),
              cursorColor: GruvboxColors.yellow,
              decoration: InputDecoration(
                hintText: 'Note (e.g. "Pre-rewrite of dialog in Scriptorium")',
                hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                filled: true,
                fillColor: GruvboxColors.bg1,
                border: OutlineInputBorder(borderSide: BorderSide(color: GruvboxColors.bg3)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GruvboxColors.yellow,
              foregroundColor: GruvboxColors.bg,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save Snapshot'),
          ),
        ],
      ),
    );

    if (shouldCreate == true) {
      final snap = await ref.read(snapshotProvider.notifier).takeSnapshot(
            fileUri: widget.fileUri,
            title: widget.fileName,
            content: widget.currentContent,
            note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          );
      _computeDiff(snap);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapState = ref.watch(snapshotProvider);
    final snapshots = snapState.snapshots;

    return Dialog(
      backgroundColor: GruvboxColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: GruvboxColors.bg3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.history, color: GruvboxColors.yellow, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scene Snapshots: ${widget.fileName}',
                      style: TextStyle(
                        color: GruvboxColors.fg,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GruvboxColors.yellow,
                      foregroundColor: GruvboxColors.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Take Snapshot Now'),
                    onPressed: _promptNewSnapshot,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Body: Split view (Timeline on Left, Diff on Right)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Timeline
                    SizedBox(
                      width: 280,
                      child: Container(
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg1,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GruvboxColors.bg3),
                        ),
                        child: snapshots.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No snapshots saved yet.\nClick "Take Snapshot Now" to checkpoint this scene.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: snapshots.length,
                                itemBuilder: (context, index) {
                                  final snap = snapshots[index];
                                  final isSelected = _selectedSnapshot?.id == snap.id;
                                  return _buildSnapshotItem(snap, isSelected);
                                },
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Right Diff / Preview Pane
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg1,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GruvboxColors.bg3),
                        ),
                        child: _selectedSnapshot == null
                            ? Center(
                                child: Text(
                                  'Select a snapshot on the left to inspect differences',
                                  style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                                ),
                              )
                            : _buildDiffView(_selectedSnapshot!),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnapshotItem(SceneSnapshot snap, bool isSelected) {
    final timeStr = '${snap.timestamp.month}/${snap.timestamp.day} ${snap.timestamp.hour.toString().padLeft(2, '0')}:${snap.timestamp.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => _computeDiff(snap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? GruvboxColors.bg2 : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: GruvboxColors.bg3, width: 0.5),
            left: BorderSide(
              color: isSelected ? GruvboxColors.yellow : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark_outline, size: 14, color: isSelected ? GruvboxColors.yellow : GruvboxColors.gray),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isSelected ? GruvboxColors.fg : GruvboxColors.gray,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${snap.wordCount} words',
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                ),
              ],
            ),
            if (snap.note != null && snap.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                snap.note!,
                style: TextStyle(color: GruvboxColors.aqua, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiffView(SceneSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: GruvboxColors.bg3)),
          ),
          child: Row(
            children: [
              Text(
                'Comparing Snapshot with Current Editor',
                style: TextStyle(
                  color: GruvboxColors.fg,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy Snapshot Text'),
                style: TextButton.styleFrom(
                  foregroundColor: GruvboxColors.aqua,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: snap.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Snapshot copied to clipboard')),
                  );
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GruvboxColors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.restore, size: 15),
                label: const Text('Restore This Version'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: GruvboxColors.bg,
                      title: Text('Restore Snapshot?', style: TextStyle(color: GruvboxColors.fg)),
                      content: Text(
                        'This will replace your current editor content with this checkpoint version.',
                        style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GruvboxColors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Confirm Restore'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(snapshotProvider.notifier).restoreSnapshot(snap);
                    if (mounted) Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),

        // Diff content viewer
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _diffSegments.isEmpty
                ? SelectableText(
                    snap.content,
                    style: TextStyle(
                      color: GruvboxColors.fg,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      children: _diffSegments.map((seg) {
                        Color? bgColor;
                        Color textColor = GruvboxColors.fg;
                        TextDecoration? deco;

                        switch (seg.type) {
                          case DiffType.addition:
                            bgColor = GruvboxColors.additionBg;
                            textColor = GruvboxColors.green;
                            break;
                          case DiffType.deletion:
                            bgColor = GruvboxColors.deletionBg;
                            textColor = GruvboxColors.red;
                            deco = TextDecoration.lineThrough;
                            break;
                          case DiffType.equal:
                            bgColor = Colors.transparent;
                            textColor = GruvboxColors.fg;
                            break;
                        }

                        return TextSpan(
                          text: seg.text,
                          style: TextStyle(
                            backgroundColor: bgColor,
                            color: textColor,
                            decoration: deco,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.5,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
