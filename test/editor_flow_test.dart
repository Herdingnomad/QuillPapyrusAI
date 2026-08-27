import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/app.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/widgets/editor/code_editor_widget.dart';
import 'package:quill_papyrus_ai/widgets/preview/markdown_preview.dart';

void main() {
  group('Editor and Workspace Flow Tests', () {
    testWidgets('Opens workspace, loads files into editor, and switches view modes', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late WidgetRef refContainer;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              refContainer = ref;
              return const QuillPapyrusApp();
            },
          ),
        ),
      );
      await tester.pump();

      // Run real dart:io async operations in runAsync
      await tester.runAsync(() async {
        await refContainer.read(workspaceProvider.notifier).pickAndLoadWorkspace();
      });
      await tester.pump();

      // Verify workspace is loaded and Welcome.md is in the tree
      expect(find.text('Welcome.md'), findsOneWidget);

      // Open Welcome.md into editor
      final welcomeNode = refContainer.read(workspaceProvider).fileTree?.findByName('Welcome.md');
      expect(welcomeNode, isNotNull);

      await tester.runAsync(() async {
        await refContainer.read(editorProvider.notifier).openFile(welcomeNode!.uri, welcomeNode.name);
      });
      await tester.pump();

      // Verify editor has opened the file with tab
      final editorState = refContainer.read(editorProvider);
      expect(editorState.tabs.length, 1);
      expect(editorState.activeTab?.fileName, 'Welcome.md');
      expect(find.byType(CodeEditorWidget), findsOneWidget);

      // Switch to Preview mode
      final previewIconBtn = find.byTooltip('Preview View');
      expect(previewIconBtn, findsOneWidget);
      await tester.tap(previewIconBtn);
      await tester.pump();

      expect(find.byType(MarkdownPreview), findsOneWidget);

      // Switch to Split mode
      final splitIconBtn = find.byTooltip('Split View');
      expect(splitIconBtn, findsOneWidget);
      await tester.tap(splitIconBtn);
      await tester.pump();

      expect(find.byType(CodeEditorWidget), findsOneWidget);
      expect(find.byType(MarkdownPreview), findsOneWidget);

      // Test tag toggling immediately updates editor content
      refContainer.read(editorProvider.notifier).toggleTagInActiveFile('newtag');
      await tester.pump();

      final updatedTab = refContainer.read(editorProvider).activeTab;
      expect(FrontMatterService.hasTag(updatedTab!.content, 'newtag'), isTrue);

      // Test Undo and Redo in editor
      final originalContent = refContainer.read(editorProvider).activeTab!.content;
      refContainer.read(editorProvider.notifier).updateContent('$originalContent\n\nAdditional text');
      expect(refContainer.read(editorProvider).activeTab!.content.contains('Additional text'), isTrue);
      expect(refContainer.read(editorProvider).activeTab!.canUndo, isTrue);

      refContainer.read(editorProvider.notifier).undo();
      expect(refContainer.read(editorProvider).activeTab!.content, originalContent);
      expect(refContainer.read(editorProvider).activeTab!.canRedo, isTrue);

      refContainer.read(editorProvider.notifier).redo();
      expect(refContainer.read(editorProvider).activeTab!.content.contains('Additional text'), isTrue);

      // Test moving file/folder into another folder
      final notesDir = refContainer.read(workspaceProvider).fileTree?.findByName('notes');
      expect(notesDir, isNotNull);

      await tester.runAsync(() async {
        final success = await refContainer.read(workspaceProvider.notifier).moveNode(welcomeNode!.uri, notesDir!.uri);
        expect(success, isTrue);
      });
      await tester.pump();
    });
  });
}
