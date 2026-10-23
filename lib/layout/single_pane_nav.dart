import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
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
    final isZen = layoutState.isZenMode;

    return Scaffold(
      backgroundColor: GruvboxColors.bg,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            FileTreePanel(),
            EditorPane(),
            SidecarPane(),
          ],
        ),
      ),
      bottomNavigationBar: isZen
          ? null
          : FrostedChrome(
              backgroundColor: GruvboxColors.bgGlass,
              blur: 16.0,
              border: Border(
                top: BorderSide(
                  color: GruvboxColors.hairlineBorder,
                  width: 0.75,
                ),
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
    );
  }
}
