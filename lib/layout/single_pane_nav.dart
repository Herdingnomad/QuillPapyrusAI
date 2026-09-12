import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/widgets/file_tree/file_tree_panel.dart';
import 'package:quill_papyrus_ai/widgets/editor/editor_pane.dart';
import 'package:quill_papyrus_ai/widgets/ai/ai_panel.dart';

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
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            FileTreePanel(),
            EditorPane(),
            AiPanel(),
          ],
        ),
      ),
      bottomNavigationBar: isZen
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
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
    );
  }
}

