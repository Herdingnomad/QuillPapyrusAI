import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LayoutState with Equatable {
  final bool isLeftPaneVisible;
  final bool isRightPaneVisible;
  final double leftFraction;
  final double rightFraction;
  final bool isZenMode;

  const LayoutState({
    this.isLeftPaneVisible = true,
    this.isRightPaneVisible = true,
    this.leftFraction = 0.22,
    this.rightFraction = 0.28,
    this.isZenMode = false,
  });

  bool get isFocusMode => !isLeftPaneVisible && !isRightPaneVisible && !isZenMode;

  LayoutState copyWith({
    bool? isLeftPaneVisible,
    bool? isRightPaneVisible,
    double? leftFraction,
    double? rightFraction,
    bool? isZenMode,
  }) {
    return LayoutState(
      isLeftPaneVisible: isLeftPaneVisible ?? this.isLeftPaneVisible,
      isRightPaneVisible: isRightPaneVisible ?? this.isRightPaneVisible,
      leftFraction: leftFraction ?? this.leftFraction,
      rightFraction: rightFraction ?? this.rightFraction,
      isZenMode: isZenMode ?? this.isZenMode,
    );
  }

  @override
  List<Object?> get props => [
        isLeftPaneVisible,
        isRightPaneVisible,
        leftFraction,
        rightFraction,
        isZenMode,
      ];
}

class LayoutNotifier extends StateNotifier<LayoutState> {
  LayoutNotifier() : super(const LayoutState());

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
    final clamped = fraction.clamp(0.15, 0.40);
    state = state.copyWith(leftFraction: clamped);
  }

  void updateRightFraction(double fraction) {
    final clamped = fraction.clamp(0.18, 0.45);
    state = state.copyWith(rightFraction: clamped);
  }
}

final layoutProvider = StateNotifierProvider<LayoutNotifier, LayoutState>((ref) {
  return LayoutNotifier();
});
