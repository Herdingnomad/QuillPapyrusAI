import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/layout/three_pane_layout.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/widgets/editor/code_editor_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/editor_pane.dart';
import 'package:quill_papyrus_ai/widgets/preview/markdown_preview.dart';

void main() {
  group('Layout Provider and Responsive Writing Space Tests', () {
    test('LayoutState initializes with both panes visible and full-pane writing measure', () {
      final notifier = LayoutNotifier();
      expect(notifier.state.isLeftPaneVisible, isTrue);
      expect(notifier.state.isRightPaneVisible, isTrue);
      expect(notifier.state.isFocusMode, isFalse);
      expect(notifier.state.isReadableLineLength, isFalse);
    });

    test('Toggles left and right pane visibility independently', () {
      final notifier = LayoutNotifier();

      notifier.toggleLeftPane();
      expect(notifier.state.isLeftPaneVisible, isFalse);
      expect(notifier.state.isRightPaneVisible, isTrue);

      notifier.toggleRightPane();
      expect(notifier.state.isRightPaneVisible, isFalse);
      expect(notifier.state.isFocusMode, isTrue);

      notifier.setLeftPaneVisible(true);
      expect(notifier.state.isLeftPaneVisible, isTrue);
      expect(notifier.state.isFocusMode, isFalse);
    });

    test('Toggle Focus Mode collapses and restores both side panes', () {
      final notifier = LayoutNotifier();

      notifier.toggleFocusMode();
      expect(notifier.state.isLeftPaneVisible, isFalse);
      expect(notifier.state.isRightPaneVisible, isFalse);
      expect(notifier.state.isFocusMode, isTrue);

      notifier.toggleFocusMode();
      expect(notifier.state.isLeftPaneVisible, isTrue);
      expect(notifier.state.isRightPaneVisible, isTrue);
      expect(notifier.state.isFocusMode, isFalse);
    });

    test('Sidebar pixel width updates are clamped within limits and can be reset', () {
      final notifier = LayoutNotifier();

      notifier.updateLeftWidth(40.0);
      expect(notifier.state.leftPaneWidth, LayoutNotifier.minLeftWidth);

      notifier.updateLeftWidth(1200.0);
      expect(notifier.state.leftPaneWidth, LayoutNotifier.maxLeftWidth);

      notifier.resetLeftWidth();
      expect(notifier.state.leftPaneWidth, LayoutNotifier.defaultLeftWidth);

      notifier.updateRightWidth(60.0);
      expect(notifier.state.rightPaneWidth, LayoutNotifier.minRightWidth);

      notifier.updateRightWidth(1500.0);
      expect(notifier.state.rightPaneWidth, LayoutNotifier.maxRightWidth);

      notifier.resetRightWidth();
      expect(notifier.state.rightPaneWidth, LayoutNotifier.defaultRightWidth);
    });

    test('Readable Line Length defaults to false and toggles properly', () {
      final notifier = LayoutNotifier();
      expect(notifier.state.isReadableLineLength, isFalse);

      notifier.toggleReadableLineLength();
      expect(notifier.state.isReadableLineLength, isTrue);

      notifier.setReadableLineLength(false);
      expect(notifier.state.isReadableLineLength, isFalse);
    });

    testWidgets(
      'Center pane and its writing space expand 1:1 when expanding the window',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1000, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.runAsync(() async {
          await container
              .read(editorProvider.notifier)
              .openFile('memory://Chapter1.md', 'Chapter1.md');
        });
        container.read(editorProvider.notifier).updateContent('# Chapter 1\nWriting prose.');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ThreePaneLayout(
                  leftPane: SizedBox.expand(key: Key('left_stub')),
                  centerPane: EditorPane(),
                  rightPane: SizedBox.expand(key: Key('right_stub')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final centerWidthAt1000 = tester.getSize(find.byType(EditorPane)).width;
        final writingWidthAt1000 = tester.getSize(find.byType(CodeEditorWidget)).width;
        expect(writingWidthAt1000, equals(centerWidthAt1000));

        // Expand window by +600px -> 1600px
        tester.view.physicalSize = const Size(1600, 800);
        await tester.pumpAndSettle();

        final centerWidthAt1600 = tester.getSize(find.byType(EditorPane)).width;
        final writingWidthAt1600 = tester.getSize(find.byType(CodeEditorWidget)).width;

        expect(centerWidthAt1600 - centerWidthAt1000, closeTo(600.0, 0.5));
        expect(writingWidthAt1600, equals(centerWidthAt1600));
        expect(writingWidthAt1600, greaterThan(1000.0)); // Never artificially capped at 840px

        // Expand window by another +600px -> 2200px
        tester.view.physicalSize = const Size(2200, 800);
        await tester.pumpAndSettle();

        final centerWidthAt2200 = tester.getSize(find.byType(EditorPane)).width;
        final writingWidthAt2200 = tester.getSize(find.byType(CodeEditorWidget)).width;

        expect(centerWidthAt2200 - centerWidthAt1600, closeTo(600.0, 0.5));
        expect(writingWidthAt2200, equals(centerWidthAt2200));
      },
    );

    testWidgets(
      'Center pane and writing space expand when closing left, right, or both side panels',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1400, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.runAsync(() async {
          await container
              .read(editorProvider.notifier)
              .openFile('memory://Chapter2.md', 'Chapter2.md');
        });
        container.read(editorProvider.notifier).updateContent('# Chapter 2\nExpanding canvas.');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ThreePaneLayout(
                  leftPane: SizedBox.expand(key: Key('left_stub')),
                  centerPane: EditorPane(),
                  rightPane: SizedBox.expand(key: Key('right_stub')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bothOpenWritingWidth = tester.getSize(find.byType(CodeEditorWidget)).width;
        expect(bothOpenWritingWidth, closeTo(840.0, 1.0)); // 1400 - 240 - 300 - 20

        // Close Left Panel -> center & writing space should gain ~226px (240px pane + 10px divider - 24px rail)
        container.read(layoutProvider.notifier).setLeftPaneVisible(false);
        await tester.pumpAndSettle();

        final leftClosedCenterWidth = tester.getSize(find.byType(EditorPane)).width;
        final leftClosedWritingWidth = tester.getSize(find.byType(CodeEditorWidget)).width;
        expect(leftClosedWritingWidth, equals(leftClosedCenterWidth));
        expect(leftClosedWritingWidth, greaterThan(bothOpenWritingWidth + 200.0));

        // Re-open Left Panel and close Right Panel -> center & writing space should gain ~286px
        container.read(layoutProvider.notifier).setLeftPaneVisible(true);
        container.read(layoutProvider.notifier).setRightPaneVisible(false);
        await tester.pumpAndSettle();

        final rightClosedCenterWidth = tester.getSize(find.byType(EditorPane)).width;
        final rightClosedWritingWidth = tester.getSize(find.byType(CodeEditorWidget)).width;
        expect(rightClosedWritingWidth, equals(rightClosedCenterWidth));
        expect(rightClosedWritingWidth, greaterThan(bothOpenWritingWidth + 260.0));

        // Close Both Side Panels -> center & writing space expand across full width between rails (1352px)
        container.read(layoutProvider.notifier).setLeftPaneVisible(false);
        await tester.pumpAndSettle();

        final bothClosedCenterWidth = tester.getSize(find.byType(EditorPane)).width;
        final bothClosedWritingWidth = tester.getSize(find.byType(CodeEditorWidget)).width;
        expect(bothClosedWritingWidth, equals(bothClosedCenterWidth));
        expect(bothClosedWritingWidth, closeTo(1352.0, 1.0));

        // Switch to Preview mode and verify MarkdownPreview also fills the expanded center pane
        container.read(editorProvider.notifier).setViewMode(EditorViewMode.preview);
        await tester.pumpAndSettle();

        final previewWidth = tester.getSize(find.byType(MarkdownPreview)).width;
        expect(previewWidth, equals(bothClosedCenterWidth));
      },
    );
  });
}
