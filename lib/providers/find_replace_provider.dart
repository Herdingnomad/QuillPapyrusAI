import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/search_models.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/search_service.dart';

class FindReplaceState with Equatable {
  final bool isVisible;
  final bool isReplaceMode;
  final SearchOptions options;
  final List<SearchMatch> matches;
  final int currentMatchIndex;
  final bool isGlobalSearchOpen;
  final List<WorkspaceSearchResult> globalResults;
  final bool isGlobalSearching;

  const FindReplaceState({
    this.isVisible = false,
    this.isReplaceMode = false,
    this.options = const SearchOptions(),
    this.matches = const [],
    this.currentMatchIndex = -1,
    this.isGlobalSearchOpen = false,
    this.globalResults = const [],
    this.isGlobalSearching = false,
  });

  SearchMatch? get currentMatch =>
      (currentMatchIndex >= 0 && currentMatchIndex < matches.length) ? matches[currentMatchIndex] : null;

  int get matchCount => matches.length;

  FindReplaceState copyWith({
    bool? isVisible,
    bool? isReplaceMode,
    SearchOptions? options,
    List<SearchMatch>? matches,
    int? currentMatchIndex,
    bool? isGlobalSearchOpen,
    List<WorkspaceSearchResult>? globalResults,
    bool? isGlobalSearching,
  }) {
    return FindReplaceState(
      isVisible: isVisible ?? this.isVisible,
      isReplaceMode: isReplaceMode ?? this.isReplaceMode,
      options: options ?? this.options,
      matches: matches ?? this.matches,
      currentMatchIndex: currentMatchIndex ?? this.currentMatchIndex,
      isGlobalSearchOpen: isGlobalSearchOpen ?? this.isGlobalSearchOpen,
      globalResults: globalResults ?? this.globalResults,
      isGlobalSearching: isGlobalSearching ?? this.isGlobalSearching,
    );
  }

  @override
  List<Object?> get props => [
        isVisible,
        isReplaceMode,
        options,
        matches,
        currentMatchIndex,
        isGlobalSearchOpen,
        globalResults,
        isGlobalSearching,
      ];
}

final findReplaceProvider = StateNotifierProvider<FindReplaceNotifier, FindReplaceState>((ref) {
  return FindReplaceNotifier(ref);
});

class FindReplaceNotifier extends StateNotifier<FindReplaceState> {
  final Ref _ref;
  final SearchService _service = SearchService.instance;

  FindReplaceNotifier(this._ref) : super(const FindReplaceState());

  void openFind({bool replaceMode = false, String? initialQuery, String? currentBuffer}) {
    final query = initialQuery ?? state.options.query;
    final newOptions = state.options.copyWith(query: query);
    final matches = currentBuffer != null && query.isNotEmpty
        ? _service.findMatches(currentBuffer, newOptions)
        : <SearchMatch>[];

    state = state.copyWith(
      isVisible: true,
      isReplaceMode: replaceMode,
      options: newOptions,
      matches: matches,
      currentMatchIndex: matches.isNotEmpty ? 0 : -1,
    );
  }

  void close() {
    state = state.copyWith(
      isVisible: false,
      matches: [],
      currentMatchIndex: -1,
    );
  }

  void toggleReplaceMode() {
    state = state.copyWith(isReplaceMode: !state.isReplaceMode);
  }

  void updateQuery(String query, String currentBuffer) {
    final newOptions = state.options.copyWith(query: query);
    final matches = _service.findMatches(currentBuffer, newOptions);
    state = state.copyWith(
      options: newOptions,
      matches: matches,
      currentMatchIndex: matches.isNotEmpty ? 0 : -1,
    );
  }

  void updateReplaceWith(String replaceWith) {
    state = state.copyWith(
      options: state.options.copyWith(replaceWith: replaceWith),
    );
  }

  void toggleMatchCase(String currentBuffer) {
    final newOptions = state.options.copyWith(matchCase: !state.options.matchCase);
    final matches = _service.findMatches(currentBuffer, newOptions);
    state = state.copyWith(
      options: newOptions,
      matches: matches,
      currentMatchIndex: matches.isNotEmpty ? 0 : -1,
    );
  }

  void toggleUseRegex(String currentBuffer) {
    final newOptions = state.options.copyWith(useRegex: !state.options.useRegex);
    final matches = _service.findMatches(currentBuffer, newOptions);
    state = state.copyWith(
      options: newOptions,
      matches: matches,
      currentMatchIndex: matches.isNotEmpty ? 0 : -1,
    );
  }

  void toggleWholeWord(String currentBuffer) {
    final newOptions = state.options.copyWith(wholeWord: !state.options.wholeWord);
    final matches = _service.findMatches(currentBuffer, newOptions);
    state = state.copyWith(
      options: newOptions,
      matches: matches,
      currentMatchIndex: matches.isNotEmpty ? 0 : -1,
    );
  }

  SearchMatch? nextMatch() {
    if (state.matches.isEmpty) return null;
    final nextIdx = (state.currentMatchIndex + 1) % state.matches.length;
    state = state.copyWith(currentMatchIndex: nextIdx);
    return state.currentMatch;
  }

  SearchMatch? previousMatch() {
    if (state.matches.isEmpty) return null;
    final prevIdx = (state.currentMatchIndex - 1 + state.matches.length) % state.matches.length;
    state = state.copyWith(currentMatchIndex: prevIdx);
    return state.currentMatch;
  }

  /// Replaces the current match in the active editor
  void replaceCurrent(TextEditingController controller) {
    final current = state.currentMatch;
    if (current == null) return;

    final text = controller.text;
    final newText = _service.replaceMatch(
      content: text,
      match: current,
      replacement: state.options.replaceWith,
    );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: current.startOffset + state.options.replaceWith.length,
      ),
    );

    _ref.read(editorProvider.notifier).updateContent(newText);
    // Re-index remaining matches
    final matches = _service.findMatches(newText, state.options);
    final newIdx = matches.isEmpty
        ? -1
        : state.currentMatchIndex.clamp(0, matches.length - 1);

    state = state.copyWith(
      matches: matches,
      currentMatchIndex: newIdx,
    );
  }

  /// Replaces all matches in the active editor
  void replaceAll(TextEditingController controller) {
    if (state.matches.isEmpty) return;

    final text = controller.text;
    final newText = _service.replaceAll(
      content: text,
      options: state.options,
    );

    controller.text = newText;
    _ref.read(editorProvider.notifier).updateContent(newText);

    state = state.copyWith(
      matches: [],
      currentMatchIndex: -1,
    );
  }

  void openGlobalSearch() {
    state = state.copyWith(isGlobalSearchOpen: true);
  }

  void closeGlobalSearch() {
    state = state.copyWith(isGlobalSearchOpen: false);
  }

  Future<void> performGlobalSearch(String query, String rootPath) async {
    final options = state.options.copyWith(query: query);
    state = state.copyWith(
      isGlobalSearching: true,
      options: options,
      globalResults: [],
    );

    final results = await _service.searchWorkspace(rootPath: rootPath, options: options);

    state = state.copyWith(
      isGlobalSearching: false,
      globalResults: results,
    );
  }
}
