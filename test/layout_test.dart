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

    test('Fraction updates are correctly clamped within limits', () {
      final notifier = LayoutNotifier();
      
      notifier.updateLeftFraction(0.10);
      expect(notifier.state.leftFraction, 0.15);

      notifier.updateLeftFraction(0.50);
      expect(notifier.state.leftFraction, 0.40);

      notifier.updateRightFraction(0.10);
      expect(notifier.state.rightFraction, 0.18);

      notifier.updateRightFraction(0.60);
      expect(notifier.state.rightFraction, 0.45);
    });
  });
}
