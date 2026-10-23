import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';

class QuickOpenDialog extends ConsumerStatefulWidget {
  const QuickOpenDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'QuickOpen',
      barrierColor: Colors.black54,
      transitionDuration: AppMotion.modalEnter,
      pageBuilder: (context, anim1, anim2) => const QuickOpenDialog(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curveValue = AppMotion.snappyEaseOut.transform(anim1.value);
        return Transform.scale(
          scale: 0.96 + (0.04 * curveValue),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<QuickOpenDialog> createState() => _QuickOpenDialogState();
}

class _QuickOpenDialogState extends ConsumerState<QuickOpenDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  List<FileNode> _allFiles = [];
  List<FileNode> _filteredFiles = [];

  @override
  void initState() {
    super.initState();
    _extractFiles();
    _searchController.addListener(_onSearchChanged);
  }

  void _extractFiles() {
    final tree = ref.read(workspaceProvider).fileTree;
    if (tree == null) return;

    final List<FileNode> files = [];
    void collect(FileNode node) {
      if (!node.isDirectory) {
        files.add(node);
      } else {
        for (final child in node.children) {
          collect(child);
        }
      }
    }

    collect(tree);
    _allFiles = files;
    _filteredFiles = List.from(files);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFiles = List.from(_allFiles);
      } else {
        _filteredFiles = _allFiles.where((file) {
          final name = file.name.toLowerCase();
          final path = file.path.toLowerCase();
          return name.contains(query) || path.contains(query);
        }).toList();
      }
      _selectedIndex = 0;
    });
  }

  void _openFile(FileNode node) {
    ref.read(editorProvider.notifier).openFile(node.uri, node.name);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (_filteredFiles.isNotEmpty) {
            setState(() {
              _selectedIndex = (_selectedIndex + 1) % _filteredFiles.length;
            });
          }
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (_filteredFiles.isNotEmpty) {
            setState(() {
              _selectedIndex = (_selectedIndex - 1 + _filteredFiles.length) % _filteredFiles.length;
            });
          }
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (_filteredFiles.isNotEmpty && _selectedIndex < _filteredFiles.length) {
            _openFile(_filteredFiles[_selectedIndex]);
          }
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 460),
          child: FrostedChrome(
            backgroundColor: GruvboxColors.bgGlassElevated,
            blur: 24.0,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GruvboxColors.hairlineBorder, width: 1.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: GruvboxColors.aqua, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: TextStyle(color: GruvboxColors.fg, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search files across workspace (Type to filter, ↵ to open)...',
                            hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg2,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: GruvboxColors.subtleDivider),
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(color: GruvboxColors.gray, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // File Results List
                Flexible(
                  child: _filteredFiles.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.find_in_page_outlined, color: GruvboxColors.gray, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'No matching files found',
                                style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _filteredFiles.length,
                          itemBuilder: (context, index) {
                            final file = _filteredFiles[index];
                            final isSelected = index == _selectedIndex;

                            return TactilePressable(
                              pressedScale: 0.98,
                              onTap: () => _openFile(file),
                              child: MouseRegion(
                                onEnter: (_) {
                                  if (_selectedIndex != index) {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  }
                                },
                                child: Container(
                                  color: isSelected ? GruvboxColors.bg1.withValues(alpha: 0.8) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    children: [

                                    Icon(
                                      file.name.endsWith('.md') ? Icons.description : Icons.insert_drive_file,
                                      size: 16,
                                      color: isSelected ? GruvboxColors.aqua : GruvboxColors.gray,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      file.name,
                                      style: TextStyle(
                                        color: isSelected ? GruvboxColors.fg0 : GruvboxColors.fg,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        file.path,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: GruvboxColors.gray,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Footer hint bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    border: Border(top: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredFiles.length} file${_filteredFiles.length == 1 ? '' : 's'}',
                        style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        '↑↓ to navigate   ↵ to select   esc to cancel',
                        style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                      ),
                    ],
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
