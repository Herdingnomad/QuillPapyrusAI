import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/app.dart';
import 'package:quill_papyrus_ai/layout/three_pane_layout.dart';
import 'package:quill_papyrus_ai/layout/single_pane_nav.dart';
import 'package:quill_papyrus_ai/widgets/editor/editor_pane.dart';
import 'package:quill_papyrus_ai/widgets/file_tree/file_tree_panel.dart';
import 'package:quill_papyrus_ai/widgets/ai/ai_panel.dart';

void main() {
  group('QuillPapyrusApp Widget Tests', () {
    testWidgets('Renders 3-pane layout on wide screen (e.g. tablet or unfolded Fold)', (tester) async {
      // Set wide viewport (1200x800)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: QuillPapyrusApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ThreePaneLayout), findsOneWidget);
      expect(find.byType(FileTreePanel), findsOneWidget);
      expect(find.byType(EditorPane), findsOneWidget);
      expect(find.byType(AiPanel), findsOneWidget);
      expect(find.textContaining('Open Workspace'), findsOneWidget);
    });

    testWidgets('Renders single-pane bottom navigation on narrow screen (e.g. phone / folded)', (tester) async {
      // Set narrow viewport (400x800)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: QuillPapyrusApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SinglePaneNav), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('AI Chat'), findsOneWidget);
    });
  });
}
