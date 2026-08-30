import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LayoutState with Equatable {
  final bool isLeftPaneVisible;
  final bool isRightPaneVisible;
  final double leftFraction;
  final double rightFraction;

  const LayoutState({
    this.isLeftPaneVisible = true,
    this.isRightPaneVisible = true,
    this.leftFraction = 0.22,
    this.rightFraction = 0.28,
  });

  bool get isFocusMode => !isLeftPaneVisible && !isRightPaneVisible;

  LayoutState copyWith({
    bool? isLeftPaneVisible,
    bool? isRightPaneVisible,
    double? leftFraction,
    double? rightFraction,
  }) {
    return LayoutState(
      isLeftPaneVisible: isLeftPaneVisible ?? this.isLeftPaneVisible,
      isRightPaneVisible: isRightPaneVisible ?? this.isRightPaneVisible,
      leftFraction: leftFraction ?? this.leftFraction,
      rightFraction: rightFraction ?? this.rightFraction,
    );
  }

  @override
  List<Object?> get props => [
        isLeftPaneVisible,
        isRightPaneVisible,
        leftFraction,
        rightFraction,
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
    if (state.isFocusMode) {
      // Restore both panes
      state = state.copyWith(isLeftPaneVisible: true, isRightPaneVisible: true);
    } else {
      // Collapse both side panes for distraction-free focus
      state = state.copyWith(isLeftPaneVisible: false, isRightPaneVisible: false);
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
