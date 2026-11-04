import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/pacing_quota.dart';
import 'package:quill_papyrus_ai/providers/pacing_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class PacingDialog extends ConsumerStatefulWidget {
  final String? initialFolderUri;
  final String? initialFolderName;

  const PacingDialog({
    super.key,
    this.initialFolderUri,
    this.initialFolderName,
  });

  static Future<void> show(
    BuildContext context, {
    String? folderUri,
    String? folderName,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => PacingDialog(
        initialFolderUri: folderUri,
        initialFolderName: folderName,
      ),
    );
  }

  @override
  ConsumerState<PacingDialog> createState() => _PacingDialogState();
}

class _PacingDialogState extends ConsumerState<PacingDialog> {
  late String _selectedScope; // 'manuscript' or folderUri
  late TextEditingController _targetWordsController;
  late TextEditingController _dailyWordsController;

  @override
  void initState() {
    super.initState();
    _selectedScope = widget.initialFolderUri ?? 'manuscript';
    final pacing = ref.read(pacingProvider);

    if (_selectedScope == 'manuscript') {
      _targetWordsController = TextEditingController(
        text: pacing.target.targetManuscriptWords.toString(),
      );
      _dailyWordsController = TextEditingController(
        text: pacing.target.targetDailyWords.toString(),
      );
    } else {
      final folderTarget = pacing.folderTargets[_selectedScope];
      _targetWordsController = TextEditingController(
        text: (folderTarget?.targetManuscriptWords ?? 3000).toString(),
      );
      _dailyWordsController = TextEditingController(
        text: (folderTarget?.targetDailyWords ?? 500).toString(),
      );
    }
  }

  @override
  void dispose() {
    _targetWordsController.dispose();
    _dailyWordsController.dispose();
    super.dispose();
  }

  void _onScopeChanged(String newScope) {
    setState(() {
      _selectedScope = newScope;
      final pacing = ref.read(pacingProvider);
      if (newScope == 'manuscript') {
        _targetWordsController.text = pacing.target.targetManuscriptWords.toString();
        _dailyWordsController.text = pacing.target.targetDailyWords.toString();
      } else {
        final folderTarget = pacing.folderTargets[newScope];
        _targetWordsController.text = (folderTarget?.targetManuscriptWords ?? 3000).toString();
        _dailyWordsController.text = (folderTarget?.targetDailyWords ?? 500).toString();
      }
    });
  }

  Future<void> _saveTargets() async {
    final targetWords = int.tryParse(_targetWordsController.text.trim()) ?? 3000;
    final dailyWords = int.tryParse(_dailyWordsController.text.trim()) ?? 500;

    if (_selectedScope == 'manuscript') {
      await ref.read(pacingProvider.notifier).updateTarget(
            manuscriptWords: targetWords,
            dailyWords: dailyWords,
          );
    } else {
      await ref.read(pacingProvider.notifier).setFolderTarget(
            folderUri: _selectedScope,
            targetWords: targetWords,
            dailyWords: dailyWords,
          );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _removeFolderGoal() async {
    if (_selectedScope != 'manuscript') {
      await ref.read(pacingProvider.notifier).removeFolderTarget(_selectedScope);
      if (mounted) Navigator.of(context).pop();
    }
  }

  List<FileNode> _getAllFolders(FileNode? root) {
    if (root == null) return [];
    final List<FileNode> folders = [];
    void collect(FileNode node) {
      if (node.isDirectory) {
        folders.add(node);
        for (final child in node.children) {
          collect(child);
        }
      }
    }

    collect(root);
    return folders;
  }

  @override
  Widget build(BuildContext context) {
    final pacing = ref.watch(pacingProvider);
    final workspace = ref.watch(workspaceProvider);
    final allFolders = _getAllFolders(workspace.fileTree);
    final isFolder = _selectedScope != 'manuscript';

    // Metrics calculation
    final currentTarget = isFolder
        ? (pacing.folderTargets[_selectedScope] ??
            ManuscriptTarget(id: _selectedScope, targetManuscriptWords: 3000, updatedAt: DateTime.now()))
        : pacing.target;

    final currentWords = isFolder
        ? pacing.wordsForFolder(_selectedScope)
        : pacing.totalManuscriptWords;

    final progressFraction = currentTarget.progressFraction(currentWords);
    final readingHours = currentTarget.estimatedReadingHours(currentWords);

    String scopeTitle = 'Entire Manuscript';
    if (isFolder) {
      final matching = allFolders.where((f) => f.uri == _selectedScope).firstOrNull;
      scopeTitle = matching != null ? matching.name : widget.initialFolderName ?? p.basename(_selectedScope);
    }

    return Dialog(
      backgroundColor: GruvboxColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: GruvboxColors.bg3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.track_changes_rounded, color: GruvboxColors.yellow, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Writing Quotas & Folder Goals',
                    style: TextStyle(
                      color: GruvboxColors.fg0,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scope Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: GruvboxColors.bg1,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GruvboxColors.bg3),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFolder ? Icons.folder_outlined : Icons.auto_stories,
                      size: 16,
                      color: isFolder ? GruvboxColors.accent : GruvboxColors.aqua,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Goal Scope:',
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedScope,
                          isExpanded: true,
                          dropdownColor: GruvboxColors.bg1,
                          style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                          onChanged: (val) {
                            if (val != null) _onScopeChanged(val);
                          },
                          items: [
                            DropdownMenuItem<String>(
                              value: 'manuscript',
                              child: Text('📚 Overall Manuscript (${pacing.totalManuscriptWords} words)'),
                            ),
                            ...allFolders.map((folder) {
                              final words = pacing.wordsForFolder(folder.uri);
                              final hasGoal = pacing.folderTargets.containsKey(folder.uri);
                              final goalTxt = hasGoal ? ' • Target: ${pacing.folderTargets[folder.uri]!.targetManuscriptWords}w' : '';
                              return DropdownMenuItem<String>(
                                value: folder.uri,
                                child: Text('📁 ${folder.name} ($words words$goalTxt)'),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Overview Cards for the Selected Scope
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: isFolder ? 'Folder Words' : 'Total Manuscript',
                      value: '$currentWords words',
                      subvalue: '${(progressFraction * 100).toStringAsFixed(1)}% of goal',
                      color: progressFraction >= 1.0 ? GruvboxColors.green : GruvboxColors.aqua,
                      progress: progressFraction,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: "Today's Net Gain",
                      value: '${pacing.todayNetWords} words',
                      subvalue: '${(pacing.dailyProgress * 100).toStringAsFixed(1)}% of daily quota',
                      color: pacing.dailyProgress >= 1.0 ? GruvboxColors.green : GruvboxColors.yellow,
                      progress: pacing.dailyProgress,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Estimated Reading',
                      value: '${readingHours.toStringAsFixed(1)} hrs',
                      subvalue: 'At 250 wpm',
                      color: GruvboxColors.purple,
                      progress: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Target Inputs for Selected Scope
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFolder ? 'Folder Target Words ($scopeTitle)' : 'Manuscript Target Words',
                          style: TextStyle(color: GruvboxColors.gray, fontSize: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg1,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GruvboxColors.bg3),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _targetWordsController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                            cursorColor: GruvboxColors.yellow,
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Session Target Words', style: TextStyle(color: GruvboxColors.gray, fontSize: 11.5)),
                        const SizedBox(height: 4),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg1,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GruvboxColors.bg3),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _dailyWordsController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                            cursorColor: GruvboxColors.yellow,
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GruvboxColors.yellow,
                            foregroundColor: GruvboxColors.bg,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onPressed: _saveTargets,
                          child: Text(isFolder ? 'Set Folder Goal' : 'Save Goals'),
                        ),
                        if (isFolder && pacing.folderTargets.containsKey(_selectedScope)) ...[
                          const SizedBox(width: 6),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: GruvboxColors.red,
                              side: BorderSide(color: GruvboxColors.red.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onPressed: _removeFolderGoal,
                            child: const Text('Clear'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Folder Goals Breakdown
              if (pacing.folderTargets.isNotEmpty) ...[
                Text(
                  'Active Folder Goals',
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 110),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg1,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GruvboxColors.bg3),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: pacing.folderTargets.entries.map((entry) {
                      final fUri = entry.key;
                      final fTarget = entry.value;
                      final words = pacing.wordsForFolder(fUri);
                      final pct = (pacing.progressForFolder(fUri) * 100).toInt();
                      final isMet = words >= fTarget.targetManuscriptWords;
                      final fNode = allFolders.where((f) => f.uri == fUri).firstOrNull;
                      final name = fNode?.name ?? p.basename(fUri);

                      return InkWell(
                        onTap: () => _onScopeChanged(fUri),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: Row(
                            children: [
                              Icon(
                                isMet ? Icons.check_circle_rounded : Icons.track_changes_rounded,
                                size: 14,
                                color: isMet ? GruvboxColors.green : GruvboxColors.yellow,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(color: GruvboxColors.fg, fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$words / ${fTarget.targetManuscriptWords} words ($pct%)',
                                style: TextStyle(
                                  color: isMet ? GruvboxColors.green : GruvboxColors.gray,
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Recent Writing History
              Text(
                'Recent Writing History (Daily Net Words)',
                style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg1,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GruvboxColors.bg3),
                  ),
                  child: pacing.recentHistory.isEmpty
                      ? Center(
                          child: Text(
                            'Start writing today to track your daily progress logs!',
                            style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                          ),
                        )
                      : ListView.separated(
                          itemCount: pacing.recentHistory.length,
                          separatorBuilder: (ctx, i) => Divider(color: GruvboxColors.bg2, height: 1),
                          itemBuilder: (context, index) {
                            final session = pacing.recentHistory[index];
                            final isMet = session.netWords >= currentTarget.targetDailyWords;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                              child: Row(
                                children: [
                                  Icon(
                                    isMet ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 15,
                                    color: isMet ? GruvboxColors.green : GruvboxColors.yellow,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    session.date,
                                    style: TextStyle(
                                      color: GruvboxColors.fg,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '+${session.wordsWritten} / -${session.wordsDeleted}',
                                    style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Net: ${session.netWords} words',
                                    style: TextStyle(
                                      color: session.netWords >= 0 ? GruvboxColors.green : GruvboxColors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subvalue,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GruvboxColors.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: GruvboxColors.gray, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(subvalue, style: TextStyle(color: GruvboxColors.gray, fontSize: 10)),
        ],
      ),
    );
  }
}
