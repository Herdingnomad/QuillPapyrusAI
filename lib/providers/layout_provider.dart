import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';

class LayoutState with Equatable {
  final bool isLeftPaneVisible;
  final bool isRightPaneVisible;
  final double leftPaneWidth;
  final double rightPaneWidth;
  final bool isZenMode;
  final bool isReadableLineLength;
  final EditorFontFamily editorFont;

  const LayoutState({
    this.isLeftPaneVisible = true,
    this.isRightPaneVisible = true,
    this.leftPaneWidth = LayoutNotifier.defaultLeftWidth,
    this.rightPaneWidth = LayoutNotifier.defaultRightWidth,
    this.isZenMode = false,
    this.isReadableLineLength = false,
    this.editorFont = EditorFontFamily.literaryProse,
  });

  bool get isFocusMode => !isLeftPaneVisible && !isRightPaneVisible && !isZenMode;

  LayoutState copyWith({
    bool? isLeftPaneVisible,
    bool? isRightPaneVisible,
    double? leftPaneWidth,
    double? rightPaneWidth,
    bool? isZenMode,
    bool? isReadableLineLength,
    EditorFontFamily? editorFont,
  }) {
    return LayoutState(
      isLeftPaneVisible: isLeftPaneVisible ?? this.isLeftPaneVisible,
      isRightPaneVisible: isRightPaneVisible ?? this.isRightPaneVisible,
      leftPaneWidth: leftPaneWidth ?? this.leftPaneWidth,
      rightPaneWidth: rightPaneWidth ?? this.rightPaneWidth,
      isZenMode: isZenMode ?? this.isZenMode,
      isReadableLineLength: isReadableLineLength ?? this.isReadableLineLength,
      editorFont: editorFont ?? this.editorFont,
    );
  }

  @override
  List<Object?> get props => [
        isLeftPaneVisible,
        isRightPaneVisible,
        leftPaneWidth,
        rightPaneWidth,
        isZenMode,
        isReadableLineLength,
        editorFont,
      ];
}

class LayoutNotifier extends StateNotifier<LayoutState> {
  static const double defaultLeftWidth = 240.0;
  static const double defaultRightWidth = 300.0;
  static const double minLeftWidth = 140.0;
  static const double maxLeftWidth = 640.0;
  static const double minRightWidth = 180.0;
  static const double maxRightWidth = 760.0;

  LayoutNotifier() : super(const LayoutState()) {
    _loadPersistedSettings();
  }

  Future<void> _loadPersistedSettings() async {
    try {
      final leftWidthStr = await DatabaseService.instance.getSetting('left_pane_width');
      final rightWidthStr = await DatabaseService.instance.getSetting('right_pane_width');
      final readableStr = await DatabaseService.instance.getSetting('readable_line_length');
      final fontStr = await DatabaseService.instance.getSetting('editor_font_family');

      double? leftW = leftWidthStr != null ? double.tryParse(leftWidthStr) : null;
      double? rightW = rightWidthStr != null ? double.tryParse(rightWidthStr) : null;

      // Migrate legacy fractional widths to fixed pixel widths so sidebars don't bloat on wide windows
      if (leftW == null) {
        final legacyLeftStr = await DatabaseService.instance.getSetting('left_pane_fraction');
        final legacyLeft = legacyLeftStr != null ? double.tryParse(legacyLeftStr) : null;
        if (legacyLeft != null) {
          leftW = (legacyLeft * 1100.0).clamp(minLeftWidth, 420.0);
        }
      }
      if (rightW == null) {
        final legacyRightStr = await DatabaseService.instance.getSetting('right_pane_fraction');
        final legacyRight = legacyRightStr != null ? double.tryParse(legacyRightStr) : null;
        if (legacyRight != null) {
          rightW = (legacyRight * 1100.0).clamp(minRightWidth, 480.0);
        }
      }

      final bool? persistedReadable = readableStr == null ? null : (readableStr == 'true');
      final persistedFont = fontStr != null ? EditorFontFamily.fromId(fontStr) : null;

      if (leftW != null || rightW != null || persistedReadable != null || persistedFont != null) {
        state = state.copyWith(
          leftPaneWidth: leftW?.clamp(minLeftWidth, maxLeftWidth),
          rightPaneWidth: rightW?.clamp(minRightWidth, maxRightWidth),
          isReadableLineLength: persistedReadable,
          editorFont: persistedFont,
        );
      }
    } catch (_) {}
  }

  Future<void> persistPaneWidths() async {
    try {
      await DatabaseService.instance.setSetting('left_pane_width', state.leftPaneWidth.toString());
      await DatabaseService.instance.setSetting('right_pane_width', state.rightPaneWidth.toString());
    } catch (_) {}
  }

  Future<void> _persistReadableLineLength(bool enabled) async {
    try {
      await DatabaseService.instance.setSetting('readable_line_length', enabled.toString());
    } catch (_) {}
  }

  Future<void> setEditorFont(EditorFontFamily font) async {
    state = state.copyWith(editorFont: font);
    try {
      await DatabaseService.instance.setSetting('editor_font_family', font.id);
    } catch (_) {}
  }

  Future<void> cycleEditorFont() async {
    const all = EditorFontFamily.values;
    final nextIdx = (all.indexOf(state.editorFont) + 1) % all.length;
    await setEditorFont(all[nextIdx]);
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
    final next = !state.isReadableLineLength;
    state = state.copyWith(isReadableLineLength: next);
    _persistReadableLineLength(next);
  }

  void setReadableLineLength(bool enabled) {
    state = state.copyWith(isReadableLineLength: enabled);
    _persistReadableLineLength(enabled);
  }

  void toggleFocusMode() {
    if (state.isFocusMode || state.isZenMode) {
      state = state.copyWith(
        isLeftPaneVisible: true,
        isRightPaneVisible: true,
        isZenMode: false,
      );
    } else {
      state = state.copyWith(
        isLeftPaneVisible: false,
        isRightPaneVisible: false,
        isZenMode: false,
      );
    }
  }

  void toggleZenMode() {
    if (state.isZenMode) {
      state = state.copyWith(
        isZenMode: false,
        isLeftPaneVisible: true,
        isRightPaneVisible: true,
      );
    } else {
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

  void updateLeftWidth(double widthPx) {
    final clamped = widthPx.clamp(minLeftWidth, maxLeftWidth);
    state = state.copyWith(leftPaneWidth: clamped);
  }

  void updateRightWidth(double widthPx) {
    final clamped = widthPx.clamp(minRightWidth, maxRightWidth);
    state = state.copyWith(rightPaneWidth: clamped);
  }

  void resetLeftWidth() {
    state = state.copyWith(leftPaneWidth: defaultLeftWidth);
    persistPaneWidths();
  }

  void resetRightWidth() {
    state = state.copyWith(rightPaneWidth: defaultRightWidth);
    persistPaneWidths();
  }
}

final layoutProvider = StateNotifierProvider<LayoutNotifier, LayoutState>((ref) {
  return LayoutNotifier();
});
