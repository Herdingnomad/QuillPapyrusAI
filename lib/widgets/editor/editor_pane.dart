import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/editor_tab.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/find_replace_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/services/widget_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/compiler_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/global_search_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/pdf_viewer_dialog.dart';
import 'package:quill_papyrus_ai/services/document_scanner_service.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/quick_open_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/snapshot_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/theme_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/editor/code_editor_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/inline_diff_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/pacing_status_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/sync_settings_dialog.dart';
import 'package:quill_papyrus_ai/widgets/editor/sync_status_indicator.dart';
import 'package:quill_papyrus_ai/widgets/pdf/pdf_viewer_widget.dart';
import 'package:quill_papyrus_ai/widgets/preview/markdown_preview.dart';

class EditorPane extends ConsumerWidget {
  const EditorPane({super.key});

  List<FileNode> _collectRecentMarkdownFiles(FileNode? root, {int limit = 3}) {
    if (root == null) return const [];
    final files = <FileNode>[];
    void walk(FileNode node) {
      if (!node.isDirectory) {
        final lower = node.name.toLowerCase();
        if (lower.endsWith('.md') || lower.endsWith('.markdown') || lower.endsWith('.txt')) {
          files.add(node);
        }
        return;
      }
      for (final child in node.children) {
        walk(child);
      }
    }

    walk(root);
    files.sort((a, b) {
      final aTime = a.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return files.take(limit).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final workspaceState = ref.watch(workspaceProvider);
    final layoutState = ref.watch(layoutProvider);
    final activeTab = editorState.activeTab;
    final tabs = editorState.tabs;
    final isDark = GruvboxColors.activeTheme.isDark;

    if (tabs.isEmpty) {
      final recentFiles = _collectRecentMarkdownFiles(workspaceState.fileTree);

      return PaperGrainSurface(
        intensity: 0.04,
        backgroundColor: GruvboxColors.bg,
        isDark: isDark,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handcrafted Nib Seal
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg1.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: GruvboxColors.accent.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: FountainNibMark(
                      size: 26,
                      color: GruvboxColors.accent,
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'Quill & Papyrus',
                    textAlign: TextAlign.center,
                    style: AppTypography.folioDisplay(
                      GruvboxColors.fg,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  AtelierDividerFlourish(
                    color: GruvboxColors.accent,
                    width: 148,
                  ),
                  const SizedBox(height: 24),

                  // Letterpress Action Rows / Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 420;
                      final actionCards = [
                        if (workspaceState.fileTree != null)
                          _EmptyStateActionCard(
                            icon: Icons.note_add_outlined,
                            title: 'New File',
                            isPrimary: true,
                            onTap: () => _showCreateFileDialog(
                              context,
                              ref,
                              workspaceState.selectedFolderUri ?? workspaceState.fileTree!.uri,
                            ),
                          ),
                        _EmptyStateActionCard(
                          icon: Icons.edit_outlined,
                          title: 'Quick Note',
                          isPrimary: workspaceState.fileTree == null,
                          onTap: () => ref.read(quickNoteServiceProvider).createQuickNote(),
                        ),
                        _EmptyStateActionCard(
                          icon: Icons.search_rounded,
                          title: 'Quick Open',
                          onTap: () => QuickOpenDialog.show(context),
                        ),
                        _EmptyStateActionCard(
                          icon: Icons.document_scanner_outlined,
                          title: 'Scan to PDF',
                          onTap: () => ref.read(documentScannerServiceProvider).scanAndSave(context),
                        ),
                      ];

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: actionCards
                              .map(
                                (card) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: card,
                                ),
                              )
                              .toList(),
                        );
                      }

                      return Row(
                        children: actionCards
                            .map(
                              (card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: card,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),

                  // Recent Manuscripts Folio List (when workspace has files)
                  if (recentFiles.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'RECENT DOCUMENTS',
                          style: AppTypography.uiLabel(
                            GruvboxColors.fgMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ).copyWith(letterSpacing: 1.2),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: GruvboxColors.bgHard.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < recentFiles.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 0.6,
                                color: GruvboxColors.subtleDivider,
                              ),
                            _RecentManuscriptRow(
                              file: recentFiles[i],
                              onTap: () => ref
                                  .read(editorProvider.notifier)
                                  .openFile(recentFiles[i].uri, recentFiles[i].name),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Quiet Shortcut Footer
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _ShortcutHint(keyCombo: 'Ctrl P', label: 'Quick Open'),
                      _ShortcutHint(keyCombo: 'Ctrl B', label: 'Files'),
                      _ShortcutHint(keyCombo: 'Ctrl J', label: 'Tools'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isDirty = activeTab?.isDirty ?? false;

    if (layoutState.isZenMode) {
      return ColoredBox(
        color: GruvboxColors.bgHard,
        child: LayoutBuilder(
          builder: (context, zenConstraints) {
            final screenWidth = zenConstraints.maxWidth;
            final isWideScreen = screenWidth >= 650;
            final double maxZenSheetWidth =
                layoutState.isReadableLineLength ? 860.0 : double.infinity;

            return Stack(
              children: [
                // Cotton-Rag Manuscript Sheet on Desk Mat (expands with window unless Centered Measure is enabled)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxZenSheetWidth),
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: isWideScreen ? 32.0 : 8.0,
                        vertical: isWideScreen ? 20.0 : 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg,
                        borderRadius: BorderRadius.circular(isWideScreen ? 10 : 6),
                        border: Border.all(
                          color: isWideScreen
                              ? GruvboxColors.hairlineBorder
                              : Colors.transparent,
                          width: 0.75,
                        ),
                        boxShadow: isWideScreen
                            ? AppMaterials.paperSheetShadows(isDark: isDark)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isWideScreen ? 10 : 6),
                        child: PaperGrainSurface(
                          intensity: 0.04,
                          backgroundColor: GruvboxColors.bg,
                          isDark: isDark,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWideScreen ? 28.0 : 12.0,
                              vertical: isWideScreen ? 24.0 : 12.0,
                            ),
                            child: Column(
                              children: [
                                const InlineDiffWidget(),
                                Expanded(
                                  child: (activeTab != null && activeTab.isPdf)
                                      ? PdfViewerWidget(
                                          filePath: activeTab.uri,
                                          fileName: activeTab.fileName,
                                        )
                                      : ((editorState.viewMode == EditorViewMode.preview)
                                          ? const MarkdownPreview()
                                          : const CodeEditorWidget()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Auto-receding Floating Minimal Zen HUD Pill
                Positioned(
                  top: 14,
                  right: 18,
                  child: _ZenFloatingHud(
                    wordCount: editorState.wordCount,
                    isDirty: isDirty,
                    editorFont: layoutState.editorFont,
                    onSelectFont: (font) =>
                        ref.read(layoutProvider.notifier).setEditorFont(font),
                    onSave: () async {
                      await ref.read(editorProvider.notifier).saveActiveFile();
                      final tab = ref.read(editorProvider).activeTab;
                      if (context.mounted && tab != null) {
                        ref.read(widgetServiceProvider).updateWidgetData(
                              title: tab.fileName,
                              snippet: tab.content.trim().split('\n').take(2).join(' '),
                            );
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: GruvboxColors.bg1,
                            duration: const Duration(seconds: 1),
                            content: Text(
                              'Saved ${tab.fileName}',
                              style: TextStyle(color: GruvboxColors.green),
                            ),
                          ),
                        );
                      }
                    },
                    onExitZen: () => ref.read(layoutProvider.notifier).exitZenMode(),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return ColoredBox(
      color: GruvboxColors.bg,
      child: Column(
        children: [
          // Seamless Book-Spine Sheet Tab Bar & Editor Header
          Container(
            height: 39,
            decoration: BoxDecoration(
              color: GruvboxColors.bgHard,
              border: Border(
                bottom: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final headerWidth = headerConstraints.maxWidth;
                final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                final isCompact = isMobile || headerWidth < 680;

                return Row(
                  children: [
                    // Scrollable book-spine sheet tabs
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: tabs.length,
                        itemBuilder: (context, index) {
                          final tab = tabs[index];
                          final isActive = index == editorState.activeTabIndex;

                          return TactilePressable(
                            tooltip: tab.fileName,
                            pressedScale: 0.985,
                            onTap: () => ref.read(editorProvider.notifier).switchTab(index),
                            onSecondaryTap: () {
                              final RenderBox? box = context.findRenderObject() as RenderBox?;
                              final pos = box != null ? box.localToGlobal(Offset.zero) : Offset.zero;
                              _showTabContextMenu(context, ref, index, pos + const Offset(40, 30));
                            },
                            child: AnimatedContainer(
                              duration: AppMotion.fastTransition,
                              curve: AppMotion.snappyEaseOut,
                              constraints: const BoxConstraints(minWidth: 88, maxWidth: 188),
                              padding: const EdgeInsets.only(left: 11, right: 7),
                              decoration: BoxDecoration(
                                color: isActive ? GruvboxColors.bg : GruvboxColors.bgHard,
                                border: Border(
                                  top: BorderSide(
                                    color: isActive ? GruvboxColors.accent : Colors.transparent,
                                    width: 1.75,
                                  ),
                                  right: BorderSide(
                                    color: GruvboxColors.subtleDivider,
                                    width: 0.75,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tab.isPdf
                                        ? Icons.picture_as_pdf_outlined
                                        : (tab.fileName.endsWith('.md')
                                            ? Icons.article_outlined
                                            : Icons.insert_drive_file_outlined),
                                    color: tab.isPdf
                                        ? GruvboxColors.red
                                        : (isActive ? GruvboxColors.accent : GruvboxColors.fgMuted),
                                    size: 13.5,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tab.fileName,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: AppTypography.uiLabel(
                                        isActive ? GruvboxColors.fg : GruvboxColors.fgMuted,
                                        fontSize: 12.0,
                                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (tab.isDirty) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      width: 5.5,
                                      height: 5.5,
                                      decoration: BoxDecoration(
                                        color: GruvboxColors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  TactilePressable(
                                    pressedScale: 0.85,
                                    onTap: () => ref.read(editorProvider.notifier).closeTab(index),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: isActive
                                            ? GruvboxColors.fgMuted
                                            : GruvboxColors.fgMuted.withValues(alpha: 0.65),
                                        size: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Quick New File button
                    if (workspaceState.fileTree != null)
                      TactilePressable(
                        tooltip: 'New File',
                        onTap: () => _showCreateFileDialog(
                          context,
                          ref,
                          workspaceState.selectedFolderUri ?? workspaceState.fileTree!.uri,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Icon(Icons.add_rounded, color: GruvboxColors.fgMuted, size: 17),
                        ),
                      ),

                    // All Open Tabs Dropdown Menu
                    if (tabs.length > 1)
                      PopupMenuButton<int>(
                        icon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.layers_outlined, size: 12.5, color: GruvboxColors.fgMuted),
                              const SizedBox(width: 3),
                              Text(
                                '${tabs.length}',
                                style: AppTypography.tabularMetric(
                                  GruvboxColors.fg,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        tooltip: 'All Open Tabs (${tabs.length})',
                        padding: EdgeInsets.zero,
                        color: GruvboxColors.bg1,
                        onSelected: (selectedIndex) {
                          if (selectedIndex == -2) {
                            final activeIdx = editorState.activeTabIndex;
                            for (var i = tabs.length - 1; i >= 0; i--) {
                              if (i != activeIdx) {
                                ref.read(editorProvider.notifier).closeTab(i);
                              }
                            }
                          } else if (selectedIndex >= 0) {
                            ref.read(editorProvider.notifier).switchTab(selectedIndex);
                          }
                        },
                        itemBuilder: (ctx) => [
                          ...tabs.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final t = entry.value;
                            final isCurrent = idx == editorState.activeTabIndex;
                            return PopupMenuItem<int>(
                              value: idx,
                              height: 34,
                              child: Row(
                                children: [
                                  Icon(
                                    isCurrent
                                        ? Icons.check_rounded
                                        : (t.isPdf
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons.article_outlined),
                                    size: 14,
                                    color: isCurrent
                                        ? GruvboxColors.accent
                                        : (t.isPdf ? GruvboxColors.red : GruvboxColors.fgMuted),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.fileName,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.uiLabel(
                                        isCurrent ? GruvboxColors.accent : GruvboxColors.fg,
                                        fontSize: 12.5,
                                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (t.isDirty)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: GruvboxColors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          const PopupMenuDivider(),
                          PopupMenuItem<int>(
                            value: -2,
                            height: 30,
                            child: Row(
                              children: [
                                Icon(Icons.close_fullscreen_rounded, size: 14, color: GruvboxColors.fgMuted),
                                const SizedBox(width: 8),
                                Text(
                                  'Close Other Tabs',
                                  style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(width: 4),
                    Container(width: 1, height: 15, color: GruvboxColors.subtleDivider),
                    const SizedBox(width: 4),

                    // Segmented View Mode Toggles (preserves exact tooltips for tests)
                    Container(
                      padding: const EdgeInsets.all(2),
                      margin: const EdgeInsets.symmetric(horizontal: 2.0),
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: GruvboxColors.subtleDivider, width: 0.6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ViewModeButton(
                            icon: Icons.notes_rounded,
                            tooltip: 'Source View',
                            isActive: editorState.viewMode == EditorViewMode.source,
                            onTap: () =>
                                ref.read(editorProvider.notifier).setViewMode(EditorViewMode.source),
                          ),
                          _ViewModeButton(
                            icon: Icons.vertical_split_outlined,
                            tooltip: 'Split View',
                            isActive: editorState.viewMode == EditorViewMode.split,
                            onTap: () =>
                                ref.read(editorProvider.notifier).setViewMode(EditorViewMode.split),
                          ),
                          _ViewModeButton(
                            icon: Icons.auto_stories_outlined,
                            tooltip: 'Preview View',
                            isActive: editorState.viewMode == EditorViewMode.preview,
                            onTap: () =>
                                ref.read(editorProvider.notifier).setViewMode(EditorViewMode.preview),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 4),
                    Container(width: 1, height: 15, color: GruvboxColors.subtleDivider),
                    const SizedBox(width: 4),

                    if (isCompact) ...[
                      _buildCompactStudioMenuButton(context, ref, activeTab, layoutState),
                    ] else ...[
                      // View Menu Dropdown
                      _buildTopBarMenuButton(
                        icon: Icons.view_quilt_outlined,
                        label: 'View',
                        tooltip: 'View Options (Focus, Zen, Readable Width)',
                        onSelected: (val) {
                          if (val == 'focus') {
                            ref.read(layoutProvider.notifier).toggleFocusMode();
                          } else if (val == 'zen') {
                            ref.read(layoutProvider.notifier).toggleZenMode();
                          } else if (val == 'readable') {
                            ref.read(layoutProvider.notifier).toggleReadableLineLength();
                          }
                        },
                        items: [
                          PopupMenuItem(
                            value: 'focus',
                            child: Row(
                              children: [
                                Icon(
                                  layoutState.isFocusMode ? Icons.fullscreen_exit : Icons.fullscreen,
                                  size: 16,
                                  color: layoutState.isFocusMode
                                      ? GruvboxColors.accent
                                      : GruvboxColors.fgMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    layoutState.isFocusMode
                                        ? 'Exit Focus Mode'
                                        : 'Focus Mode (Hide Sidebars)',
                                    style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'zen',
                            child: Row(
                              children: [
                                Icon(Icons.self_improvement_outlined,
                                    size: 16, color: GruvboxColors.fg2),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Focus Mode (Canvas)',
                                    style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'readable',
                            child: Row(
                              children: [
                                Icon(
                                  layoutState.isReadableLineLength
                                      ? Icons.format_align_justify
                                      : Icons.format_align_center,
                                  size: 16,
                                  color: layoutState.isReadableLineLength
                                      ? GruvboxColors.accent
                                      : GruvboxColors.fgMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    layoutState.isReadableLineLength
                                        ? 'Expand to Full Pane Width'
                                        : 'Centered Line Measure',
                                    style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Search Menu Dropdown
                      _buildTopBarMenuButton(
                        icon: Icons.search_rounded,
                        label: 'Search',
                        tooltip: 'Find & Replace / Global Search',
                        onSelected: (val) {
                          if (val == 'find') {
                            ref.read(findReplaceProvider.notifier).openFind(
                                  replaceMode: false,
                                  currentBuffer: activeTab?.content,
                                );
                          } else if (val == 'global') {
                            GlobalSearchDialog.show(context);
                          }
                        },
                        items: [
                          PopupMenuItem(
                            value: 'find',
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 16, color: GruvboxColors.fg2),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Find & Replace (Ctrl+F)',
                                      style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'global',
                            child: Row(
                              children: [
                                Icon(Icons.manage_search_rounded,
                                    size: 16, color: GruvboxColors.fg2),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Search Workspace (Ctrl+Shift+F)',
                                      style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Tools Menu Dropdown
                      _buildTopBarMenuButton(
                        icon: Icons.tune_rounded,
                        label: 'Tools',
                        tooltip: 'Publish, Snapshots & Settings',
                        onSelected: (val) {
                          if (val == 'compile') {
                            CompilerDialog.show(context);
                          } else if (val == 'snapshots') {
                            if (activeTab != null) {
                              SnapshotManagerDialog.show(
                                context,
                                fileUri: activeTab.uri,
                                fileName: activeTab.fileName,
                                currentContent: activeTab.content,
                              );
                            }
                          } else if (val == 'view_pdf') {
                            PdfViewerDialog.pickAndOpenPdf(context);
                          } else if (val == 'scan_to_pdf') {
                            ref.read(documentScannerServiceProvider).scanAndSave(context);
                          } else if (val == 'themes') {
                            showThemeManagerDialog(context, ref);
                          } else if (val == 'sync') {
                            SyncSettingsDialog.show(context);
                          }
                        },
                        items: [
                          PopupMenuItem(
                            value: 'view_pdf',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf_outlined,
                                    size: 16, color: GruvboxColors.fg2),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('View PDF Document...',
                                      style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'scan_to_pdf',
                            child: Row(
                              children: [
                                Icon(Icons.document_scanner_outlined,
                                    size: 16, color: GruvboxColors.aqua),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Scan Document to PDF...',
                                      style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'compile',
                            child: Row(
                              children: [
                                Icon(Icons.print_outlined, size: 16, color: GruvboxColors.fg2),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Export Document (EPUB/PDF/DOCX)',
                                      style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          if (activeTab != null)
                            PopupMenuItem(
                              value: 'snapshots',
                              child: Row(
                                children: [
                                  Icon(Icons.camera_alt_outlined,
                                      size: 16, color: GruvboxColors.fg2),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Snapshots (Ctrl+Shift+S)',
                                        style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'themes',
                            child: Row(
                              children: [
                                Icon(Icons.palette_outlined,
                                    size: 16, color: GruvboxColors.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Color Themes',
                                      style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'sync',
                            child: Row(
                              children: [
                                Icon(Icons.sync_rounded, size: 16, color: GruvboxColors.fg2),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Cloud Folder Sync Settings',
                                      style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 6),
                  ],
                );
              },
            ),
          ),

          // Active Inline Diff view if proposal is present
          const InlineDiffWidget(),

          // Content area with optional Readable Line Length centering
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (activeTab != null && activeTab.isPdf) {
                  return PdfViewerWidget(
                    filePath: activeTab.uri,
                    fileName: activeTab.fileName,
                    showAppBar: false,
                  );
                }

                final useReadableWidth =
                    layoutState.isReadableLineLength &&
                    editorState.viewMode != EditorViewMode.split &&
                    constraints.maxWidth >= 960;
                final Widget editorRow = Row(
                  children: [
                    if (editorState.viewMode == EditorViewMode.source ||
                        editorState.viewMode == EditorViewMode.split)
                      const Expanded(child: CodeEditorWidget()),
                    if (editorState.viewMode == EditorViewMode.split)
                      Container(width: 1, color: GruvboxColors.subtleDivider),
                    if (editorState.viewMode == EditorViewMode.preview ||
                        editorState.viewMode == EditorViewMode.split)
                      const Expanded(child: MarkdownPreview()),
                  ],
                );

                if (!useReadableWidth) {
                  return editorRow;
                }

                return ColoredBox(
                  color: GruvboxColors.bgHard.withValues(alpha: 0.45),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Container(
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg,
                          border: Border.symmetric(
                            vertical: BorderSide(
                              color: GruvboxColors.subtleDivider,
                              width: 0.75,
                            ),
                          ),
                        ),
                        child: editorRow,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Quiet Colophon Status Bar
          Container(
            height: 26,
            decoration: BoxDecoration(
              color: GruvboxColors.bgHard,
              border: Border(
                top: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showPacing = constraints.maxWidth >= 720;
                final showTypeface = constraints.maxWidth >= 460;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ln ${editorState.cursorLine}, Col ${editorState.cursorColumn}',
                              maxLines: 1,
                              style: AppTypography.tabularMetric(
                                GruvboxColors.fgMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (showTypeface) ...[
                              const SizedBox(width: 10),
                              TactilePressable(
                                tooltip: 'Cycle Editor Font (${layoutState.editorFont.label})',
                                onTap: () => ref.read(layoutProvider.notifier).cycleEditorFont(),
                                child: Text(
                                  layoutState.editorFont.label,
                                  maxLines: 1,
                                  style: AppTypography.uiLabel(
                                    GruvboxColors.fgMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            const SyncStatusIndicator(),
                            if (showPacing) ...[
                              const SizedBox(width: 8),
                              const PacingStatusWidget(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (constraints.maxWidth * 0.42).clamp(90.0, 280.0),
                      ),
                      child: Text(
                        '${isDirty ? "● Unsaved" : "Saved"}  •  ${editorState.wordCount} words',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTypography.tabularMetric(
                          isDirty ? GruvboxColors.orange : GruvboxColors.fgMuted,
                          fontSize: 11,
                          fontWeight: isDirty ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFileDialog(BuildContext context, WidgetRef ref, String parentUri) {
    final controller = TextEditingController(text: 'Note.md');
    final workspaceState = ref.read(workspaceProvider);
    final isRoot = parentUri == workspaceState.rootUri;
    final parentLabel = isRoot ? 'Workspace Root' : p.basename(parentUri);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New Document',
              style: AppTypography.sectionTitle(GruvboxColors.fg, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 13.5, color: GruvboxColors.accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'in $parentLabel',
                    style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: GruvboxColors.fg),
          decoration: InputDecoration(
            hintText: 'File name (e.g. notes.md)',
            hintStyle: TextStyle(color: GruvboxColors.fgMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: GruvboxColors.fgMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GruvboxColors.accent,
              foregroundColor: GruvboxColors.bgHard,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final newUri = await ref.read(workspaceProvider.notifier).createFile(parentUri, name);
                if (newUri != null) {
                  ref.read(editorProvider.notifier).openFile(newUri, name);
                }
                ref.read(workspaceProvider.notifier).expandDirectory(parentUri);
              }
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Create & Open'),
          ),
        ],
      ),
    );
  }

  void _showTabContextMenu(BuildContext context, WidgetRef ref, int index, Offset position) {
    final editorState = ref.read(editorProvider);
    if (index < 0 || index >= editorState.tabs.length) return;
    final tab = editorState.tabs[index];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: GruvboxColors.bg1,
      items: [
        PopupMenuItem(
          value: 'close',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.close_rounded, size: 14, color: GruvboxColors.fgMuted),
              const SizedBox(width: 8),
              Text('Close Tab (Ctrl+W)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
        if (editorState.tabs.length > 1) ...[
          PopupMenuItem(
            value: 'close_others',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.close_fullscreen_rounded, size: 14, color: GruvboxColors.fgMuted),
                const SizedBox(width: 8),
                Text('Close Other Tabs', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
              ],
            ),
          ),
          if (index < editorState.tabs.length - 1)
            PopupMenuItem(
              value: 'close_right',
              height: 32,
              child: Row(
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 14, color: GruvboxColors.fgMuted),
                  const SizedBox(width: 8),
                  Text('Close Tabs to the Right', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                ],
              ),
            ),
        ],
        PopupMenuItem(
          value: 'copy_path',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 14, color: GruvboxColors.fgMuted),
              const SizedBox(width: 8),
              Text('Copy File Path', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (!context.mounted) return;
      if (choice == 'close') {
        ref.read(editorProvider.notifier).closeTab(index);
      } else if (choice == 'close_others') {
        ref.read(editorProvider.notifier).closeOtherTabs(index);
      } else if (choice == 'close_right') {
        ref.read(editorProvider.notifier).closeTabsToTheRight(index);
      } else if (choice == 'copy_path') {
        Clipboard.setData(ClipboardData(text: tab.uri));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            duration: const Duration(seconds: 1),
            content: Text('Copied path: ${tab.fileName}', style: TextStyle(color: GruvboxColors.green)),
          ),
        );
      }
    });
  }

  Widget _buildCompactStudioMenuButton(
    BuildContext context,
    WidgetRef ref,
    EditorTab? activeTab,
    LayoutState layoutState,
  ) {
    return TactilePressable(
      tooltip: 'Studio & Editor Options',
      pressedScale: 0.94,
      onTap: () {
        final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        if (isMobile || MediaQuery.of(context).size.width < 700) {
          _showStudioBottomSheet(context, ref, activeTab, layoutState);
        } else {
          _showStudioPopupMenu(context, ref, activeTab, layoutState);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GruvboxColors.bg.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(5.0),
          border: Border.all(color: GruvboxColors.subtleDivider, width: 0.65),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 13, color: GruvboxColors.fg2),
            const SizedBox(width: 4),
            Text(
              'Studio',
              style: AppTypography.uiLabel(
                GruvboxColors.fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudioPopupMenu(
    BuildContext context,
    WidgetRef ref,
    EditorTab? activeTab,
    LayoutState layoutState,
  ) {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = button != null
        ? RelativeRect.fromRect(
            Rect.fromPoints(
              button.localToGlobal(Offset.zero, ancestor: overlay),
              button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
            ),
            Offset.zero & overlay.size,
          )
        : const RelativeRect.fromLTRB(100, 100, 0, 0);

    showMenu<String>(
      context: context,
      position: position,
      color: GruvboxColors.bg1,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: GruvboxColors.hairlineBorder),
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          height: 24,
          child: Text('VIEW & CANVAS', style: TextStyle(color: GruvboxColors.fgMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        PopupMenuItem(
          value: 'focus',
          child: Row(
            children: [
              Icon(layoutState.isFocusMode ? Icons.fullscreen_exit : Icons.fullscreen, size: 16, color: layoutState.isFocusMode ? GruvboxColors.accent : GruvboxColors.fgMuted),
              const SizedBox(width: 8),
              Text(layoutState.isFocusMode ? 'Exit Focus Mode' : 'Focus Mode (Hide Sidebars)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'zen',
          child: Row(
            children: [
              Icon(Icons.self_improvement_outlined, size: 16, color: GruvboxColors.fg2),
              const SizedBox(width: 8),
              Text('Focus Mode (Canvas)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'readable',
          child: Row(
            children: [
              Icon(
                layoutState.isReadableLineLength
                    ? Icons.format_align_justify
                    : Icons.format_align_center,
                size: 16,
                color: layoutState.isReadableLineLength ? GruvboxColors.accent : GruvboxColors.fg2,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  layoutState.isReadableLineLength
                      ? 'Expand to Full Pane Width'
                      : 'Centered Line Measure',
                  style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          height: 24,
          child: Text('SEARCH', style: TextStyle(color: GruvboxColors.fgMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        PopupMenuItem(
          value: 'find',
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 16, color: GruvboxColors.fg2),
              const SizedBox(width: 8),
              Text('Find & Replace (Ctrl+F)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'global',
          child: Row(
            children: [
              Icon(Icons.manage_search_rounded, size: 16, color: GruvboxColors.fg2),
              const SizedBox(width: 8),
              Text('Search Workspace (Ctrl+Shift+F)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          height: 24,
          child: Text('DOCUMENT TOOLS', style: TextStyle(color: GruvboxColors.fgMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        PopupMenuItem(
          value: 'compile',
          child: Row(
            children: [
              Icon(Icons.print_outlined, size: 16, color: GruvboxColors.fg2),
              const SizedBox(width: 8),
              Text('Export Document', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
        if (activeTab != null)
          PopupMenuItem(
            value: 'snapshots',
            child: Row(
              children: [
                Icon(Icons.camera_alt_outlined, size: 16, color: GruvboxColors.fg2),
                const SizedBox(width: 8),
                Text('Snapshots (Ctrl+Shift+S)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'themes',
          child: Row(
            children: [
              Icon(Icons.palette_outlined, size: 16, color: GruvboxColors.accent),
              const SizedBox(width: 8),
              Text('Color Themes', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sync',
          child: Row(
            children: [
              Icon(Icons.sync_rounded, size: 16, color: GruvboxColors.fg2),
              const SizedBox(width: 8),
              Text('Cloud Folder Sync Settings', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
            ],
          ),
        ),
      ],
    ).then((val) {
      if (val == null || !context.mounted) return;
      if (val == 'focus') {
        ref.read(layoutProvider.notifier).toggleFocusMode();
      } else if (val == 'zen') {
        ref.read(layoutProvider.notifier).toggleZenMode();
      } else if (val == 'readable') {
        ref.read(layoutProvider.notifier).toggleReadableLineLength();
      } else if (val == 'find') {
        ref.read(findReplaceProvider.notifier).openFind(
              replaceMode: false,
              currentBuffer: activeTab?.content,
            );
      } else if (val == 'global') {
        GlobalSearchDialog.show(context);
      } else if (val == 'compile') {
        CompilerDialog.show(context);
      } else if (val == 'snapshots') {
        if (activeTab != null) {
          SnapshotManagerDialog.show(
            context,
            fileUri: activeTab.uri,
            fileName: activeTab.fileName,
            currentContent: activeTab.content,
          );
        }
      } else if (val == 'themes') {
        showThemeManagerDialog(context, ref);
      } else if (val == 'sync') {
        SyncSettingsDialog.show(context);
      }
    });
  }

  void _showStudioBottomSheet(
    BuildContext context,
    WidgetRef ref,
    EditorTab? activeTab,
    LayoutState layoutState,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return Container(
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(
              top: BorderSide(color: GruvboxColors.hairlineBorder, width: 1),
              left: BorderSide(color: GruvboxColors.hairlineBorder, width: 1),
              right: BorderSide(color: GruvboxColors.hairlineBorder, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: GruvboxColors.fgMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      FountainNibMark(size: 16, color: GruvboxColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Workspace Options',
                          style: AppTypography.sectionTitle(GruvboxColors.fg, fontSize: 15),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: GruvboxColors.fgMuted),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildSheetSectionHeader('EDITOR FONT'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: EditorFontFamily.values.map((font) {
                        final isSelected = font == layoutState.editorFont;
                        return TactilePressable(
                          onTap: () {
                            ref.read(layoutProvider.notifier).setEditorFont(font);
                            Navigator.of(modalCtx).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? GruvboxColors.accent.withValues(alpha: 0.14)
                                  : GruvboxColors.bg,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: isSelected
                                    ? GruvboxColors.accent
                                    : GruvboxColors.subtleDivider,
                              ),
                            ),
                            child: Text(
                              font.label,
                              style: font.editorStyle(
                                color: isSelected ? GruvboxColors.accent : GruvboxColors.fg,
                                fontSizeOverride: 12,
                                heightOverride: 1.2,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Divider(height: 16, color: GruvboxColors.subtleDivider),
                  _buildSheetSectionHeader('VIEW & CANVAS'),
                  _buildSheetActionTile(
                    icon: layoutState.isFocusMode ? Icons.fullscreen_exit : Icons.fullscreen,
                    iconColor: layoutState.isFocusMode ? GruvboxColors.accent : GruvboxColors.fg2,
                    title: layoutState.isFocusMode
                        ? 'Exit Focus Mode'
                        : 'Focus Mode (Hide Sidebars)',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      ref.read(layoutProvider.notifier).toggleFocusMode();
                    },
                  ),
                  _buildSheetActionTile(
                    icon: Icons.self_improvement_outlined,
                    iconColor: GruvboxColors.fg2,
                    title: 'Focus Mode (Distraction Free)',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      ref.read(layoutProvider.notifier).toggleZenMode();
                    },
                  ),
                  _buildSheetActionTile(
                    icon: layoutState.isReadableLineLength
                        ? Icons.format_align_justify
                        : Icons.format_align_center,
                    iconColor: layoutState.isReadableLineLength
                        ? GruvboxColors.accent
                        : GruvboxColors.fg2,
                    title: layoutState.isReadableLineLength
                        ? 'Expand to Full Pane Width'
                        : 'Centered Line Measure',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      ref.read(layoutProvider.notifier).toggleReadableLineLength();
                    },
                  ),
                  Divider(height: 14, color: GruvboxColors.subtleDivider),
                  _buildSheetSectionHeader('SEARCH & NAVIGATION'),
                  _buildSheetActionTile(
                    icon: Icons.search_rounded,
                    iconColor: GruvboxColors.fg2,
                    title: 'Find & Replace in Document',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      ref.read(findReplaceProvider.notifier).openFind(
                            replaceMode: false,
                            currentBuffer: activeTab?.content,
                          );
                    },
                  ),
                  _buildSheetActionTile(
                    icon: Icons.manage_search_rounded,
                    iconColor: GruvboxColors.fg2,
                    title: 'Search Workspace Files',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      GlobalSearchDialog.show(context);
                    },
                  ),
                  _buildSheetActionTile(
                    icon: Icons.file_open_outlined,
                    iconColor: GruvboxColors.fg2,
                    title: 'Quick Open Document',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      QuickOpenDialog.show(context);
                    },
                  ),
                  Divider(height: 14, color: GruvboxColors.subtleDivider),
                  _buildSheetSectionHeader('EXPORT & TOOLS'),
                  _buildSheetActionTile(
                    icon: Icons.print_outlined,
                    iconColor: GruvboxColors.fg2,
                    title: 'Export Document (EPUB/PDF/DOCX)',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      CompilerDialog.show(context);
                    },
                  ),
                  _buildSheetActionTile(
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: GruvboxColors.fg2,
                    title: 'View PDF Document in App',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      PdfViewerDialog.pickAndOpenPdf(context);
                    },
                  ),
                  _buildSheetActionTile(
                    icon: Icons.document_scanner_outlined,
                    iconColor: GruvboxColors.aqua,
                    title: Platform.isWindows
                        ? 'Scan Document to PDF (Windows Camera)'
                        : (Platform.isAndroid ? 'Scan Document to PDF (Android Scanner)' : 'Scan Document to PDF'),
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      ref.read(documentScannerServiceProvider).scanAndSave(context);
                    },
                  ),
                  if (activeTab != null)
                    _buildSheetActionTile(
                      icon: Icons.camera_alt_outlined,
                      iconColor: GruvboxColors.fg2,
                      title: 'Snapshots & Revisions',
                      onTap: () {
                        Navigator.of(modalCtx).pop();
                        SnapshotManagerDialog.show(
                          context,
                          fileUri: activeTab.uri,
                          fileName: activeTab.fileName,
                          currentContent: activeTab.content,
                        );
                      },
                    ),
                  _buildSheetActionTile(
                    icon: Icons.palette_outlined,
                    iconColor: GruvboxColors.accent,
                    title: 'Color Themes & Styling',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      showThemeManagerDialog(context, ref);
                    },
                  ),
                  _buildSheetActionTile(
                    icon: Icons.sync_rounded,
                    iconColor: GruvboxColors.fg2,
                    title: 'Cloud Folder Sync Settings',
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      SyncSettingsDialog.show(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
      child: Text(
        title,
        style: AppTypography.uiLabel(
          GruvboxColors.fgMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ).copyWith(letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildSheetActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: GruvboxColors.bg,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: GruvboxColors.subtleDivider),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.uiLabel(
                        GruvboxColors.fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: GruvboxColors.fgMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarMenuButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required ValueChanged<String> onSelected,
    required List<PopupMenuEntry<String>> items,
  }) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      color: GruvboxColors.bg1,
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: GruvboxColors.hairlineBorder),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: GruvboxColors.fgMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.uiLabel(
                GruvboxColors.fg2,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 1),
            Icon(Icons.keyboard_arrow_down_rounded, size: 13, color: GruvboxColors.fgMuted),
          ],
        ),
      ),
    );
  }
}

class _ZenFloatingHud extends StatefulWidget {
  final int wordCount;
  final bool isDirty;
  final EditorFontFamily editorFont;
  final ValueChanged<EditorFontFamily> onSelectFont;
  final VoidCallback onSave;
  final VoidCallback onExitZen;

  const _ZenFloatingHud({
    required this.wordCount,
    required this.isDirty,
    required this.editorFont,
    required this.onSelectFont,
    required this.onSave,
    required this.onExitZen,
  });

  @override
  State<_ZenFloatingHud> createState() => _ZenFloatingHudState();
}

class _ZenFloatingHudState extends State<_ZenFloatingHud> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final double targetOpacity =
        (isMobile || _isHovered || widget.isDirty) ? 1.0 : 0.34;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        duration: AppMotion.smoothTransition,
        curve: AppMotion.snappyEaseOut,
        opacity: targetOpacity,
        child: FrostedChrome(
          borderRadius: BorderRadius.circular(18),
          backgroundColor: GruvboxColors.bgGlass,
          border: Border.all(color: GruvboxColors.hairlineBorder, width: 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Typeface quick selector in Zen Mode
              PopupMenuButton<EditorFontFamily>(
                tooltip: 'Editor Font (${widget.editorFont.label})',
                onSelected: widget.onSelectFont,
                color: GruvboxColors.bg1,
                itemBuilder: (ctx) => EditorFontFamily.values.map((f) {
                  final active = f == widget.editorFont;
                  return PopupMenuItem<EditorFontFamily>(
                    value: f,
                    height: 36,
                    child: Row(
                      children: [
                        Icon(
                          active ? Icons.check_rounded : Icons.text_fields_rounded,
                          size: 14,
                          color: active ? GruvboxColors.accent : GruvboxColors.fgMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.label,
                            style: f.editorStyle(
                              color: active ? GruvboxColors.accent : GruvboxColors.fg,
                              fontSizeOverride: 12.5,
                              heightOverride: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg1.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GruvboxColors.subtleDivider),
                  ),
                  child: Text(
                    widget.editorFont.shortLabel,
                    style: AppTypography.uiLabel(GruvboxColors.fg2, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Tabular Word Count Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: GruvboxColors.bg1.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GruvboxColors.subtleDivider),
                ),
                child: Text(
                  '${widget.wordCount} words',
                  style: AppTypography.tabularMetric(
                    GruvboxColors.fgMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Quick Save Button
              TactilePressable(
                tooltip: widget.isDirty ? 'Save Changes (Ctrl+S)' : 'All Changes Saved',
                onTap: widget.onSave,
                child: AnimatedContainer(
                  duration: AppMotion.fastTransition,
                  curve: AppMotion.snappyEaseOut,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isDirty
                        ? GruvboxColors.orange.withValues(alpha: 0.18)
                        : GruvboxColors.bg1.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.isDirty
                          ? GruvboxColors.orange.withValues(alpha: 0.7)
                          : GruvboxColors.subtleDivider,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isDirty ? Icons.save_outlined : Icons.check_rounded,
                        size: 13,
                        color: widget.isDirty ? GruvboxColors.orange : GruvboxColors.fgMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isDirty ? 'Save' : 'Saved',
                        style: AppTypography.uiLabel(
                          widget.isDirty ? GruvboxColors.orange : GruvboxColors.fgMuted,
                          fontSize: 11,
                          fontWeight: widget.isDirty ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Exit Zen Mode Button
              TactilePressable(
                tooltip: 'Exit Zen Mode (Esc)',
                onTap: widget.onExitZen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: GruvboxColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GruvboxColors.accent.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen_exit_rounded, size: 14, color: GruvboxColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Exit Zen',
                        style: AppTypography.uiLabel(
                          GruvboxColors.fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      onTap: onTap,
      tooltip: tooltip,
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: AppMotion.fastTransition,
        curve: AppMotion.snappyEaseOut,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: isActive ? GruvboxColors.bg1 : Colors.transparent,
          borderRadius: BorderRadius.circular(4.5),
          border: isActive
              ? Border.all(color: GruvboxColors.hairlineBorder, width: 0.65)
              : null,
        ),
        child: Icon(
          icon,
          color: isActive ? GruvboxColors.accent : GruvboxColors.fgMuted,
          size: 14.5,
        ),
      ),
    );
  }
}

class _EmptyStateActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isPrimary;
  final VoidCallback onTap;

  const _EmptyStateActionCard({
    required this.icon,
    required this.title,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  State<_EmptyStateActionCard> createState() => _EmptyStateActionCardState();
}

class _EmptyStateActionCardState extends State<_EmptyStateActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: TactilePressable(
        pressedScale: 0.97,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fastTransition,
          curve: AppMotion.snappyEaseOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? GruvboxColors.bg1
                : GruvboxColors.bgHard.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered || widget.isPrimary
                  ? GruvboxColors.accent.withValues(alpha: _isHovered ? 0.55 : 0.28)
                  : GruvboxColors.subtleDivider,
              width: 0.75,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: widget.isPrimary || _isHovered
                    ? GruvboxColors.accent
                    : GruvboxColors.fg2,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.uiLabel(
                  GruvboxColors.fg,
                  fontSize: 12.5,
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

class _RecentManuscriptRow extends StatefulWidget {
  final FileNode file;
  final VoidCallback onTap;

  const _RecentManuscriptRow({
    required this.file,
    required this.onTap,
  });

  @override
  State<_RecentManuscriptRow> createState() => _RecentManuscriptRowState();
}

class _RecentManuscriptRowState extends State<_RecentManuscriptRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TactilePressable(
        pressedScale: 0.99,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: _hovered ? GruvboxColors.bg1.withValues(alpha: 0.6) : Colors.transparent,
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 14,
                color: _hovered ? GruvboxColors.accent : GruvboxColors.fgMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  p.basenameWithoutExtension(widget.file.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.sectionTitle(
                    GruvboxColors.fg,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Icon(
                Icons.north_east_rounded,
                size: 13,
                color: _hovered ? GruvboxColors.accent : GruvboxColors.fgMuted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  final String keyCombo;
  final String label;

  const _ShortcutHint({required this.keyCombo, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: GruvboxColors.bgHard.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
          ),
          child: Text(
            keyCombo,
            style: AppTypography.codeMono(
              GruvboxColors.fg2,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 11),
        ),
      ],
    );
  }
}
