import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';

class LayoutState with Equatable {
  final bool isLeftPaneVisible;
  final bool isRightPaneVisible;
  final double leftFraction;
  final double rightFraction;
  final bool isZenMode;
  final bool isReadableLineLength;

  const LayoutState({
    this.isLeftPaneVisible = true,
    this.isRightPaneVisible = true,
    this.leftFraction = 0.22,
    this.rightFraction = 0.28,
    this.isZenMode = false,
    this.isReadableLineLength = true,
  });

  bool get isFocusMode => !isLeftPaneVisible && !isRightPaneVisible && !isZenMode;

  LayoutState copyWith({
    bool? isLeftPaneVisible,
    bool? isRightPaneVisible,
    double? leftFraction,
    double? rightFraction,
    bool? isZenMode,
    bool? isReadableLineLength,
  }) {
    return LayoutState(
      isLeftPaneVisible: isLeftPaneVisible ?? this.isLeftPaneVisible,
      isRightPaneVisible: isRightPaneVisible ?? this.isRightPaneVisible,
      leftFraction: leftFraction ?? this.leftFraction,
      rightFraction: rightFraction ?? this.rightFraction,
      isZenMode: isZenMode ?? this.isZenMode,
      isReadableLineLength: isReadableLineLength ?? this.isReadableLineLength,
    );
  }

  @override
  List<Object?> get props => [
        isLeftPaneVisible,
        isRightPaneVisible,
        leftFraction,
        rightFraction,
        isZenMode,
        isReadableLineLength,
      ];
}

class LayoutNotifier extends StateNotifier<LayoutState> {
  static const double defaultLeftFraction = 0.22;
  static const double defaultRightFraction = 0.28;

  LayoutNotifier() : super(const LayoutState()) {
    _loadPersistedFractions();
  }

  Future<void> _loadPersistedFractions() async {
    try {
      final leftStr = await DatabaseService.instance.getSetting('left_pane_fraction');
      final rightStr = await DatabaseService.instance.getSetting('right_pane_fraction');
      double? left;
      double? right;
      if (leftStr != null) left = double.tryParse(leftStr);
      if (rightStr != null) right = double.tryParse(rightStr);

      if (left != null || right != null) {
        state = state.copyWith(
          leftFraction: left?.clamp(0.08, 0.50),
          rightFraction: right?.clamp(0.12, 0.55),
        );
      }
    } catch (_) {}
  }

  Future<void> persistFractions() async {
    try {
      await DatabaseService.instance.setSetting('left_pane_fraction', state.leftFraction.toString());
      await DatabaseService.instance.setSetting('right_pane_fraction', state.rightFraction.toString());
    } catch (_) {}
  }

  void toggleLeftPane() {
    state = state.copyWith(isLeftPaneVisible: !state.isLeftPaneVisible);
  }

  void toggleRightPane() {
    state = state.copyWith(isRightPaneVisible: !state.isRightPaneVisible);
  }

  void setLeftPaneVisible(bool visible) {
    state = state.copyWith(isLeftPaneVisible: visible);
  }

  void setRightPaneVisible(bool visible) {
    state = state.copyWith(isRightPaneVisible: visible);
  }

  void toggleReadableLineLength() {
    state = state.copyWith(isReadableLineLength: !state.isReadableLineLength);
  }

  void setReadableLineLength(bool enabled) {
    state = state.copyWith(isReadableLineLength: enabled);
  }

  void toggleFocusMode() {
    if (state.isFocusMode || state.isZenMode) {
      // Restore both panes
      state = state.copyWith(
        isLeftPaneVisible: true,
        isRightPaneVisible: true,
        isZenMode: false,
      );
    } else {
      // Collapse both side panes for distraction-free focus
      state = state.copyWith(
        isLeftPaneVisible: false,
        isRightPaneVisible: false,
        isZenMode: false,
      );
    }
  }

  void toggleZenMode() {
    if (state.isZenMode) {
      // Exit Zen mode
      state = state.copyWith(
        isZenMode: false,
        isLeftPaneVisible: true,
        isRightPaneVisible: true,
      );
    } else {
      // Enter Zen mode (pure canvas, hidden sidebars & toolbars)
      state = state.copyWith(
        isZenMode: true,
        isLeftPaneVisible: false,
        isRightPaneVisible: false,
      );
    }
  }

  void exitZenMode() {
    if (state.isZenMode) {
      state = state.copyWith(
        isZenMode: false,
        isLeftPaneVisible: true,
        isRightPaneVisible: true,
      );
    }
  }

  void updateLeftFraction(double fraction) {
    final clamped = fraction.clamp(0.08, 0.50);
    state = state.copyWith(leftFraction: clamped);
  }

  void updateRightFraction(double fraction) {
    final clamped = fraction.clamp(0.12, 0.55);
    state = state.copyWith(rightFraction: clamped);
  }

  void resetLeftWidth() {
    state = state.copyWith(leftFraction: defaultLeftFraction);
    persistFractions();
  }

  void resetRightWidth() {
    state = state.copyWith(rightFraction: defaultRightFraction);
    persistFractions();
  }
}

final layoutProvider = StateNotifierProvider<LayoutNotifier, LayoutState>((ref) {
  return LayoutNotifier();
});
