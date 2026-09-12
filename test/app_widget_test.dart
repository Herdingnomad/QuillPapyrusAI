import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/app.dart';
import 'package:quill_papyrus_ai/layout/three_pane_layout.dart';
import 'package:quill_papyrus_ai/layout/single_pane_nav.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
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

    testWidgets('Samsung Galaxy Z Fold unfolded screen (768x900) renders ThreePaneLayout', (tester) async {
      // Samsung Fold unfolded inner display is typically 768 x 900+ logical dp
      tester.view.physicalSize = const Size(768, 900);
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
    });

    testWidgets('SinglePaneNav hides BottomNavigationBar when Zen Mode is active', (tester) async {
      tester.view.physicalSize = const Size(380, 840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return const QuillPapyrusApp();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Trigger Zen Mode
      container.read(layoutProvider.notifier).toggleZenMode();
      await tester.pumpAndSettle();

      // Bottom bar must be completely hidden for 100% clean canvas
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('ThreePaneLayout hides edge rails when Zen Mode is active', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return const QuillPapyrusApp();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In default workspace, left and right panes are visible or have rails
      container.read(layoutProvider.notifier).setLeftPaneVisible(false);
      container.read(layoutProvider.notifier).setRightPaneVisible(false);
      await tester.pumpAndSettle();

      // When collapsed in standard mode, rails exist
      expect(find.byTooltip('Show Files Explorer (Ctrl+B)'), findsOneWidget);
      expect(find.byTooltip('Show AI Assistant (Ctrl+J)'), findsOneWidget);

      // Now enter Zen Mode
      container.read(layoutProvider.notifier).toggleZenMode();
      await tester.pumpAndSettle();

      // In Zen Mode, rails are suppressed for pure canvas
      expect(find.byTooltip('Show Files Explorer (Ctrl+B)'), findsNothing);
      expect(find.byTooltip('Show AI Assistant (Ctrl+J)'), findsNothing);
    });
  });
}

