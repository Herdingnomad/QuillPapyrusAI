import 'package:flutter/material.dart';
import 'package:quill_papyrus_ai/widgets/file_tree/file_tree_panel.dart';
import 'package:quill_papyrus_ai/widgets/editor/editor_pane.dart';
import 'package:quill_papyrus_ai/widgets/ai/ai_panel.dart';

class SinglePaneNav extends StatefulWidget {
  const SinglePaneNav({super.key});

  @override
  State<SinglePaneNav> createState() => _SinglePaneNavState();
}

class _SinglePaneNavState extends State<SinglePaneNav> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: BottomNavigationBar(
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
