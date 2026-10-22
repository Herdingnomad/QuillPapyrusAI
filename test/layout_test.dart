import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';

void main() {
  group('Layout Provider and Slidable Pane Tests', () {
    test('LayoutState initializes with both panes visible', () {
      final notifier = LayoutNotifier();
      expect(notifier.state.isLeftPaneVisible, isTrue);
      expect(notifier.state.isRightPaneVisible, isTrue);
      expect(notifier.state.isFocusMode, isFalse);
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

    test('Fraction updates are correctly clamped within limits and can be reset', () {
      final notifier = LayoutNotifier();
      
      notifier.updateLeftFraction(0.02);
      expect(notifier.state.leftFraction, 0.08);

      notifier.updateLeftFraction(0.70);
      expect(notifier.state.leftFraction, 0.50);

      notifier.resetLeftWidth();
      expect(notifier.state.leftFraction, LayoutNotifier.defaultLeftFraction);

      notifier.updateRightFraction(0.05);
      expect(notifier.state.rightFraction, 0.12);

      notifier.updateRightFraction(0.80);
      expect(notifier.state.rightFraction, 0.55);

      notifier.resetRightWidth();
      expect(notifier.state.rightFraction, LayoutNotifier.defaultRightFraction);
    });

    test('Readable Line Length initializes true and toggles properly', () {
      final notifier = LayoutNotifier();
      expect(notifier.state.isReadableLineLength, isTrue);

      notifier.toggleReadableLineLength();
      expect(notifier.state.isReadableLineLength, isFalse);

      notifier.setReadableLineLength(true);
      expect(notifier.state.isReadableLineLength, isTrue);
    });
  });
}
