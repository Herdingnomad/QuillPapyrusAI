import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/layout/single_pane_nav.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/sidecar/sidecar_pane.dart';
import 'package:quill_papyrus_ai/widgets/editor/markdown_formatting_helper.dart';
import 'package:quill_papyrus_ai/widgets/editor/mobile_keyboard_accessory_bar.dart';

void main() {
  group('Interface Redesign & Motion Primitives Tests', () {
    test('AppMotion tokens have physically accurate spring and curve parameters', () {
      expect(AppMotion.criticallyDamped.damping, closeTo(26.83, 0.1));
      expect(AppMotion.momentumSpring.damping, closeTo(23.73, 0.1));
      expect(AppMotion.pressFeedback.inMilliseconds, equals(140));
      expect(AppMotion.modalExit < AppMotion.modalEnter, isTrue); // Asymmetric exit
    });

    testWidgets('TactilePressable scales on tap down and resets on tap up', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactilePressable(
                onTap: () => tapped = true,
                pressedScale: 0.95,
                tooltip: 'Press Me',
                child: const SizedBox(width: 100, height: 100, key: Key('tactile_target')),
              ),
            ),
          ),
        ),
      );

      final animatedScaleFinder = find.byType(AnimatedScale);
      expect(animatedScaleFinder, findsOneWidget);

      AnimatedScale scaleWidget = tester.widget(animatedScaleFinder);
      expect(scaleWidget.scale, equals(1.0));

      // Pointer down should trigger scale down
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('tactile_target'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      scaleWidget = tester.widget(animatedScaleFinder);
      expect(scaleWidget.scale, equals(0.95));

      // Pointer up should trigger callback and restore scale to 1.0
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      scaleWidget = tester.widget(animatedScaleFinder);
      expect(scaleWidget.scale, equals(1.0));
      expect(tapped, isTrue);
    });

    testWidgets('FrostedChrome renders BackdropFilter with correct blur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrostedChrome(
              backgroundColor: Colors.black54,
              blur: 20.0,
              borderRadius: BorderRadius.circular(12),
              child: const Text('Frosted Content'),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Frosted Content'), findsOneWidget);
    });

    testWidgets('SinglePaneNav provides FrostedChrome bottom bar and SidecarPane access', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SinglePaneNav(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(FrostedChrome), findsWidgets);

      // Tap AI Chat tab to ensure SidecarPane is loaded with all sub-tools
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();

      expect(find.byType(SidecarPane), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('Grammar'), findsOneWidget);
      expect(find.text('Scene'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);
    });

    test('MarkdownFormattingHelper wraps text, cycles headings, and toggles checklists', () {
      final controller = TextEditingController(text: 'Chapter One\nIt was a dark night.\nDone task');

      // Test heading cycle
      controller.selection = const TextSelection.collapsed(offset: 5); // on 'Chapter One'
      MarkdownFormattingHelper.cycleHeading(controller);
      expect(controller.text.startsWith('# Chapter One'), isTrue);

      MarkdownFormattingHelper.cycleHeading(controller);
      expect(controller.text.startsWith('## Chapter One'), isTrue);

      MarkdownFormattingHelper.cycleHeading(controller);
      expect(controller.text.startsWith('### Chapter One'), isTrue);

      MarkdownFormattingHelper.cycleHeading(controller);
      expect(controller.text.startsWith('Chapter One'), isTrue);

      // Test wrap selection
      controller.selection = const TextSelection(baseOffset: 12, extentOffset: 14); // 'It'
      MarkdownFormattingHelper.wrapSelection(controller, '**', '**');
      expect(controller.text.contains('**It** was a dark night.'), isTrue);

      // Test checklist toggle
      controller.selection = TextSelection.collapsed(offset: controller.text.length - 2); // 'Done task'
      MarkdownFormattingHelper.toggleCheckbox(controller);
      expect(controller.text.endsWith('- [ ] Done task'), isTrue);

      MarkdownFormattingHelper.toggleCheckbox(controller);
      expect(controller.text.endsWith('- [x] Done task'), isTrue);

      MarkdownFormattingHelper.toggleCheckbox(controller);
      expect(controller.text.endsWith('Done task'), isTrue);
    });

    testWidgets('MobileKeyboardAccessoryBar renders formatting buttons and triggers actions', (tester) async {
      final controller = TextEditingController(text: 'Hello world');
      final undoController = UndoHistoryController();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MobileKeyboardAccessoryBar(
                controller: controller,
                undoController: undoController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MobileKeyboardAccessoryBar), findsOneWidget);
      expect(find.text('H#'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);

      // Select 'world'
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);

      // Tap 'B'
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('Hello **world**'));
    });
  });
}

