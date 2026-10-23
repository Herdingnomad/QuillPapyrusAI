import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/widget_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/editor/code_editor_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/inline_diff_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/pacing_status_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/sync_status_indicator.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/compiler_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/quick_open_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/global_search_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/snapshot_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/theme_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/editor/sync_settings_dialog.dart';
import 'package:quill_papyrus_ai/providers/find_replace_provider.dart';
import 'package:quill_papyrus_ai/widgets/preview/markdown_preview.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';

class EditorPane extends ConsumerWidget {
  const EditorPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final workspaceState = ref.watch(workspaceProvider);
    final layoutState = ref.watch(layoutProvider);
    final activeTab = editorState.activeTab;
    final tabs = editorState.tabs;

    if (tabs.isEmpty) {
      return Container(
        color: GruvboxColors.bg,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: GruvboxColors.bgHard.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GruvboxColors.hairlineBorder, width: 0.75),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emblem
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg1,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: GruvboxColors.aqua.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: GruvboxColors.aqua.withValues(alpha: 0.15),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.edit_note, color: GruvboxColors.aqua, size: 40),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Quill & Papyrus Studio',
                      style: TextStyle(
                        color: GruvboxColors.fg,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Distraction-free markdown writing crafted for fluid creative flow and on-device intelligence.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GruvboxColors.gray,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Quick action cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 420;
                        final actionCards = [
                          if (workspaceState.fileTree != null)
                            _EmptyStateActionCard(
                              icon: Icons.note_add_outlined,
                              iconColor: GruvboxColors.aqua,
                              title: 'New File',
                              subtitle: 'Create document',
                              onTap: () => _showCreateFileDialog(
                                context,
                                ref,
                                workspaceState.selectedFolderUri ?? workspaceState.fileTree!.uri,
                              ),
                            ),
                          _EmptyStateActionCard(
                            icon: Icons.bolt,
                            iconColor: GruvboxColors.yellow,
                            title: 'Quick Note',
                            subtitle: 'Instant memo (Ctrl+N)',
                            onTap: () => ref.read(quickNoteServiceProvider).createQuickNote(),
                          ),
                          _EmptyStateActionCard(
                            icon: Icons.search,
                            iconColor: GruvboxColors.green,
                            title: 'Quick Open',
                            subtitle: 'Find file (Ctrl+P)',
                            onTap: () => QuickOpenDialog.show(context),
                          ),
                        ];

                        if (isCompact) {
                          return Column(
                            children: actionCards.map((card) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: card,
                            )).toList(),
                          );
                        }

                        return Row(
                          children: actionCards.map((card) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: card,
                            ),
                          )).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    Divider(color: GruvboxColors.subtleDivider, height: 1),
                    const SizedBox(height: 16),

                    // Shortcut Helper footer
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _ShortcutHint(keyCombo: 'Ctrl P', label: 'Quick Open'),
                        _ShortcutHint(keyCombo: 'Ctrl B', label: 'File Explorer'),
                        _ShortcutHint(keyCombo: 'Ctrl J', label: 'AI Studio'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isDirty = activeTab?.isDirty ?? false;

    if (layoutState.isZenMode) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isWideScreen = screenWidth >= 650;

      return Container(
        color: GruvboxColors.bgHard,
        child: Stack(
          children: [
            // Centered "Digital Parchment / Typewriter" Editor Canvas
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isWideScreen ? 24.0 : 8.0,
                    vertical: isWideScreen ? 20.0 : 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg,
                    borderRadius: BorderRadius.circular(isWideScreen ? 12 : 8),
                    border: Border.all(
                      color: isWideScreen
                          ? GruvboxColors.bg3.withValues(alpha: 0.7)
                          : Colors.transparent,
                    ),
                    boxShadow: isWideScreen
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isWideScreen ? 12 : 8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWideScreen ? 24.0 : 12.0,
                        vertical: isWideScreen ? 24.0 : 12.0,
                      ),
                      child: Column(
                        children: [
                          const InlineDiffWidget(),
                          Expanded(
                            child: (editorState.viewMode == EditorViewMode.preview)
                                ? const MarkdownPreview()
                                : const CodeEditorWidget(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Floating Minimal Pill: Word Count, Quick Save, and Exit Zen
              Positioned(
                top: 14,
                right: 18,
                child: FrostedChrome(
                  borderRadius: BorderRadius.circular(18),
                  backgroundColor: GruvboxColors.bgGlass,
                  border: Border.all(color: GruvboxColors.hairlineBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Word Count Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg1.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: GruvboxColors.subtleDivider),
                        ),
                        child: Text(
                          '${editorState.wordCount} words',
                          style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Quick Save Button (Active in Zen Mode)
                      TactilePressable(
                        tooltip: isDirty ? 'Save Changes (Ctrl+S)' : 'All Changes Saved',
                        onTap: () async {
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
                        child: AnimatedContainer(
                          duration: AppMotion.fastTransition,
                          curve: AppMotion.snappyEaseOut,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDirty
                                ? GruvboxColors.orange.withValues(alpha: 0.22)
                                : GruvboxColors.bg1.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDirty ? GruvboxColors.orange : GruvboxColors.subtleDivider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDirty ? Icons.save_outlined : Icons.check,
                                size: 13,
                                color: isDirty ? GruvboxColors.orange : GruvboxColors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDirty ? 'Save' : 'Saved',
                                style: TextStyle(
                                  color: isDirty ? GruvboxColors.orange : GruvboxColors.green,
                                  fontSize: 11,
                                  fontWeight: isDirty ? FontWeight.bold : FontWeight.normal,
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
                        onTap: () => ref.read(layoutProvider.notifier).exitZenMode(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: GruvboxColors.aqua.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GruvboxColors.aqua.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen_exit, size: 14, color: GruvboxColors.aqua),
                              const SizedBox(width: 4),
                              Text(
                                'Exit Zen',
                                style: TextStyle(
                                  color: GruvboxColors.fg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
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
          ],
        ),
      );
    }

    return Container(
      color: GruvboxColors.bg,
      child: Column(
        children: [
          // Tab bar & Main Editor Header
          Container(
            height: 40,
            color: GruvboxColors.bgHard,
            child: Row(
              children: [
                // Scrollable tab list with proper constraints and tooltips
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
                        pressedScale: 0.98,
                        onTap: () => ref.read(editorProvider.notifier).switchTab(index),
                        onSecondaryTap: () {
                          final RenderBox? box = context.findRenderObject() as RenderBox?;
                          final pos = box != null ? box.localToGlobal(Offset.zero) : Offset.zero;
                          _showTabContextMenu(context, ref, index, pos + const Offset(40, 30));
                        },
                        child: AnimatedContainer(
                          duration: AppMotion.fastTransition,
                          curve: AppMotion.snappyEaseOut,
                          constraints: const BoxConstraints(minWidth: 80, maxWidth: 180),
                          padding: const EdgeInsets.only(left: 10, right: 6),
                          decoration: BoxDecoration(
                            color: isActive ? GruvboxColors.bg : GruvboxColors.bgHard,
                            border: Border(
                              top: BorderSide(
                                color: isActive ? GruvboxColors.aqua : Colors.transparent,
                                width: 2.5,
                              ),
                              right: BorderSide(
                                color: GruvboxColors.subtleDivider,
                                width: 0.75,
                              ),
                              bottom: BorderSide(
                                color: isActive ? Colors.transparent : GruvboxColors.subtleDivider,
                                width: 0.75,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab.fileName.endsWith('.md') ? Icons.description : Icons.insert_drive_file,
                                color: isActive ? GruvboxColors.aqua : GruvboxColors.gray,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tab.fileName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: isActive ? GruvboxColors.fg : GruvboxColors.fg4,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              if (tab.isDirty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
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
                                    Icons.close,
                                    color: isActive ? GruvboxColors.gray : GruvboxColors.fg4,
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

                // Quick New File button with Tactile feedback
                if (workspaceState.fileTree != null)
                  TactilePressable(
                    tooltip: 'New File',
                    onTap: () => _showCreateFileDialog(context, ref, workspaceState.selectedFolderUri ?? workspaceState.fileTree!.uri),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Icon(Icons.add, color: GruvboxColors.gray, size: 18),
                    ),
                  ),

                // All Open Tabs Dropdown Menu (for multi-tab management)
                if (tabs.length > 1)
                  PopupMenuButton<int>(
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg1,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: GruvboxColors.bg3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tab, size: 13, color: GruvboxColors.aqua),
                          const SizedBox(width: 3),
                          Text(
                            '${tabs.length}',
                            style: TextStyle(
                              color: GruvboxColors.fg,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, size: 13, color: GruvboxColors.gray),
                        ],
                      ),
                    ),
                    tooltip: 'All Open Tabs (${tabs.length})',
                    padding: EdgeInsets.zero,
                    color: GruvboxColors.bg1,
                    onSelected: (selectedIndex) {
                      if (selectedIndex == -2) {
                        // Close other tabs
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
                                isCurrent ? Icons.check : (t.fileName.endsWith('.md') ? Icons.description : Icons.insert_drive_file),
                                size: 14,
                                color: isCurrent ? GruvboxColors.aqua : GruvboxColors.gray,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.fileName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? GruvboxColors.aqua : GruvboxColors.fg,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12.5,
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
                            Icon(Icons.close_fullscreen, size: 14, color: GruvboxColors.gray),
                            SizedBox(width: 8),
                            Text('Close Other Tabs', style: TextStyle(color: GruvboxColors.fg4, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(width: 4),
                Container(width: 1, height: 18, color: GruvboxColors.bg3),
                const SizedBox(width: 2),

                // View Mode Toggles (source, split, preview)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg1,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ViewModeButton(
                        icon: Icons.code,
                        tooltip: 'Source View',
                        isActive: editorState.viewMode == EditorViewMode.source,
                        onTap: () => ref.read(editorProvider.notifier).setViewMode(EditorViewMode.source),
                      ),
                      _ViewModeButton(
                        icon: Icons.vertical_split,
                        tooltip: 'Split View',
                        isActive: editorState.viewMode == EditorViewMode.split,
                        onTap: () => ref.read(editorProvider.notifier).setViewMode(EditorViewMode.split),
                      ),
                      _ViewModeButton(
                        icon: Icons.visibility,
                        tooltip: 'Preview View',
                        isActive: editorState.viewMode == EditorViewMode.preview,
                        onTap: () => ref.read(editorProvider.notifier).setViewMode(EditorViewMode.preview),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),
                Container(width: 1, height: 18, color: GruvboxColors.bg3),
                const SizedBox(width: 4),

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
                            color: layoutState.isFocusMode ? GruvboxColors.yellow : GruvboxColors.gray,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              layoutState.isFocusMode ? 'Exit Focus Mode' : 'Focus Mode (Hide Sidebars)',
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
                          Icon(Icons.self_improvement, size: 16, color: GruvboxColors.aqua),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Zen Writing Mode (Canvas)',
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
                            layoutState.isReadableLineLength ? Icons.format_align_center : Icons.format_align_justify,
                            size: 16,
                            color: layoutState.isReadableLineLength ? GruvboxColors.aqua : GruvboxColors.gray,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              layoutState.isReadableLineLength ? 'Centered Width (Active)' : 'Full Screen Width',
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
                  icon: Icons.search,
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
                          Icon(Icons.search, size: 16, color: GruvboxColors.aqua),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Find & Replace (Ctrl+F)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'global',
                      child: Row(
                        children: [
                          Icon(Icons.manage_search, size: 16, color: GruvboxColors.yellow),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Search Workspace (Ctrl+Shift+F)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Tools Menu Dropdown
                _buildTopBarMenuButton(
                  icon: Icons.handyman_outlined,
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
                    } else if (val == 'themes') {
                      showThemeManagerDialog(context, ref);
                    } else if (val == 'sync') {
                      SyncSettingsDialog.show(context);
                    }
                  },
                  items: [
                    PopupMenuItem(
                      value: 'compile',
                      child: Row(
                        children: [
                          Icon(Icons.print_outlined, size: 16, color: GruvboxColors.purple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Compile Manuscript (EPUB/PDF/DOCX)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    if (activeTab != null)
                      PopupMenuItem(
                        value: 'snapshots',
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 16, color: GruvboxColors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Scene Snapshots (Ctrl+Shift+S)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'themes',
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 16, color: GruvboxColors.yellow),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Color Themes & Cloud Sync', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sync',
                      child: Row(
                        children: [
                          Icon(Icons.sync, size: 16, color: GruvboxColors.aqua),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Cloud Folder Sync Settings', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Divider(color: GruvboxColors.bg3, height: 1),


          // Active Inline Diff view if proposal is present
          const InlineDiffWidget(),

          // Content area with optional Readable Line Length centering
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useReadableWidth = layoutState.isReadableLineLength && constraints.maxWidth >= 900;
                final Widget editorRow = Row(
                  children: [
                    if (editorState.viewMode == EditorViewMode.source ||
                        editorState.viewMode == EditorViewMode.split)
                      const Expanded(child: CodeEditorWidget()),
                    if (editorState.viewMode == EditorViewMode.split)
                      Container(width: 1, color: GruvboxColors.bg3),
                    if (editorState.viewMode == EditorViewMode.preview ||
                        editorState.viewMode == EditorViewMode.split)
                      const Expanded(child: MarkdownPreview()),
                  ],
                );

                if (!useReadableWidth) {
                  return editorRow;
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          vertical: BorderSide(color: GruvboxColors.bg3.withValues(alpha: 0.4), width: 1),
                        ),
                      ),
                      child: editorRow,
                    ),
                  ),
                );
              },
            ),
          ),

          // Status bar
          Container(
            height: 26,
            color: GruvboxColors.bgHard,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showPacing = constraints.maxWidth >= 600;
                return Row(
                  children: [
                    Text(
                      'Ln ${editorState.cursorLine}, Col ${editorState.cursorColumn}',
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    const SyncStatusIndicator(),
                    if (showPacing) ...[
                      const SizedBox(width: 8),
                      const PacingStatusWidget(),
                    ],
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '${isDirty ? "● Modified" : "Saved"}  •  ${editorState.wordCount} words',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isDirty ? GruvboxColors.yellow : GruvboxColors.gray,
                          fontSize: 11,
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
            Text('Create New Markdown File', style: TextStyle(color: GruvboxColors.fg, fontSize: 16)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.folder, size: 14, color: GruvboxColors.yellow),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'in $parentLabel',
                    style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
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
            hintText: 'File name (e.g. Note.md)',
            hintStyle: TextStyle(color: GruvboxColors.gray),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GruvboxColors.aqua,
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
              Icon(Icons.close, size: 14, color: GruvboxColors.gray),
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
                Icon(Icons.close_fullscreen, size: 14, color: GruvboxColors.gray),
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
                  Icon(Icons.arrow_forward, size: 14, color: GruvboxColors.gray),
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
              Icon(Icons.copy, size: 14, color: GruvboxColors.gray),
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
      child: TactilePressable(
        pressedScale: 0.96,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(5.0),
            border: Border.all(color: GruvboxColors.subtleDivider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: GruvboxColors.fg2),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: GruvboxColors.fg,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 13, color: GruvboxColors.gray),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? GruvboxColors.bg2 : Colors.transparent,
          borderRadius: BorderRadius.circular(4.0),
          border: isActive
              ? Border.all(color: GruvboxColors.hairlineBorder)
              : null,
        ),
        child: Icon(
          icon,
          color: isActive ? GruvboxColors.aqua : GruvboxColors.gray,
          size: 16,
        ),
      ),
    );
  }
}

class _EmptyStateActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EmptyStateActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      pressedScale: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: GruvboxColors.bg1.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: GruvboxColors.fg,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: GruvboxColors.gray,
                fontSize: 10.5,
              ),
            ),
          ],
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
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
          ),
          child: Text(
            keyCombo,
            style: TextStyle(
              color: GruvboxColors.aqua,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
        ),
      ],
    );
  }
}

