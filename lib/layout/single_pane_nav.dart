import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/quick_open_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/theme_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/editor/editor_pane.dart';
import 'package:quill_papyrus_ai/widgets/file_tree/file_tree_panel.dart';
import 'package:quill_papyrus_ai/widgets/sidecar/sidecar_pane.dart';

class SinglePaneNav extends ConsumerStatefulWidget {
  const SinglePaneNav({super.key});

  @override
  ConsumerState<SinglePaneNav> createState() => _SinglePaneNavState();
}

class _SinglePaneNavState extends ConsumerState<SinglePaneNav> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutProvider);
    final editorState = ref.watch(editorProvider);
    final isZen = layoutState.isZenMode;
    final activeTab = editorState.activeTab;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: GruvboxColors.bg,
      appBar: isZen
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: SafeArea(
                bottom: false,
                child: FrostedChrome(
                  blur: 20.0,
                  backgroundColor: GruvboxColors.bgGlassElevated,
                  border: Border(
                    bottom: BorderSide(
                      color: GruvboxColors.hairlineBorder,
                      width: 0.75,
                    ),
                  ),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Text(
                          'Quill & Papyrus',
                          style: TextStyle(
                            color: GruvboxColors.fg,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (activeTab != null) ...[
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: GruvboxColors.gray, fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeTab.fileName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: GruvboxColors.fg4,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        TactilePressable(
                          tooltip: 'Quick Open (Ctrl+P)',
                          onTap: () => QuickOpenDialog.show(context),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(Icons.search, size: 20, color: GruvboxColors.fg4),
                          ),
                        ),
                        TactilePressable(
                          tooltip: 'Quick Note',
                          onTap: () => ref.read(quickNoteServiceProvider).createQuickNote(),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(Icons.add_circle_outline, size: 20, color: GruvboxColors.aqua),
                          ),
                        ),
                        TactilePressable(
                          tooltip: 'Themes',
                          onTap: () => showThemeManagerDialog(context, ref),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(Icons.palette_outlined, size: 20, color: GruvboxColors.yellow),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        top: isZen,
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            FileTreePanel(),
            EditorPane(),
            SidecarPane(),
          ],
        ),
      ),
      bottomNavigationBar: (isZen || isKeyboardOpen)
          ? null
          : Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: FrostedChrome(
                  backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.90),
                  blur: 24.0,
                  border: Border.all(
                    color: GruvboxColors.hairlineBorder,
                    width: 0.75,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedItemColor: GruvboxColors.accent,
                      unselectedItemColor: GruvboxColors.fg4,
                      selectedFontSize: 12,
                      unselectedFontSize: 12,
                      type: BottomNavigationBarType.fixed,
                      onTap: (index) {
                        if (_currentIndex != index) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _currentIndex = index;
                          });
                        }
                      },
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.folder_outlined),
                          activeIcon: Icon(Icons.folder),
                          label: 'Files',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.edit_note_outlined),
                          activeIcon: Icon(Icons.edit_note),
                          label: 'Editor',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.smart_toy_outlined),
                          activeIcon: Icon(Icons.smart_toy),
                          label: 'AI Chat',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

