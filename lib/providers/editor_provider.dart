import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show Color, TextRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/editor_tab.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';

/// Available modes for the editor view
enum EditorViewMode { source, split, preview }

/// Alias for backwards compatibility if referenced
typedef ViewMode = EditorViewMode;

/// State object representing the editor tabs and view configuration
class EditorState with Equatable {
  final List<EditorTab> tabs;
  final int activeTabIndex;
  final EditorViewMode viewMode;
  final int cursorLine;
  final int cursorColumn;
  final TextRange? activeHighlightRange;
  final Color? activeHighlightColor;
  final bool isReplacementHighlight;
  final int highlightVersion;

  const EditorState({
    this.tabs = const [],
    this.activeTabIndex = -1,
    this.viewMode = EditorViewMode.source,
    this.cursorLine = 1,
    this.cursorColumn = 1,
    this.activeHighlightRange,
    this.activeHighlightColor,
    this.isReplacementHighlight = false,
    this.highlightVersion = 0,
  });

  EditorTab? get activeTab =>
      (activeTabIndex >= 0 && activeTabIndex < tabs.length) ? tabs[activeTabIndex] : null;

  List<EditorTab> get openTabs => tabs;

  String? get activeFileUri => activeTab?.uri;

  int get wordCount {
    final content = activeTab?.content;
    if (content == null || content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  EditorState copyWith({
    List<EditorTab>? tabs,
    int? activeTabIndex,
    EditorViewMode? viewMode,
    int? cursorLine,
    int? cursorColumn,
    TextRange? activeHighlightRange,
    Color? activeHighlightColor,
    bool? isReplacementHighlight,
    int? highlightVersion,
  }) {
    return EditorState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      viewMode: viewMode ?? this.viewMode,
      cursorLine: cursorLine ?? this.cursorLine,
      cursorColumn: cursorColumn ?? this.cursorColumn,
      activeHighlightRange: activeHighlightRange ?? this.activeHighlightRange,
      activeHighlightColor: activeHighlightColor ?? this.activeHighlightColor,
      isReplacementHighlight: isReplacementHighlight ?? this.isReplacementHighlight,
      highlightVersion: highlightVersion ?? this.highlightVersion,
    );
  }

  @override
  List<Object?> get props => [
        tabs,
        activeTabIndex,
        viewMode,
        cursorLine,
        cursorColumn,
        activeHighlightRange,
        activeHighlightColor,
        isReplacementHighlight,
        highlightVersion,
      ];
}

/// Main editor provider for managing tabs and content
final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  return EditorNotifier(
    ref.read(safStorageServiceProvider),
    onFileSaved: (uri, content) {
      ref.read(workspaceProvider.notifier).updateFileMetadata(uri, content);
    },
  );
});

/// Notifier for managing open editor tabs, their content, and saving files
class EditorNotifier extends StateNotifier<EditorState> {
  final SafStorageService _storage;
  final void Function(String uri, String content)? onFileSaved;

  static const Duration hotExitDebounceDuration = Duration(milliseconds: 150);
  static const Duration writeBackDebounceDuration = Duration(milliseconds: 500);

  final Map<String, Timer> _hotExitTimers = {};
  final Map<String, Timer> _writeBackTimers = {};

  EditorNotifier(this._storage, {this.onFileSaved}) : super(const EditorState());

  void _scheduleHotExitDraft(String uri, String content, int cursorPosition) {
    _hotExitTimers[uri]?.cancel();
    _hotExitTimers[uri] = Timer(hotExitDebounceDuration, () async {
      _hotExitTimers.remove(uri);
      await DatabaseService.instance.upsertDraft(uri, content, cursorPosition: cursorPosition);
    });
  }

  void _scheduleDebouncedWriteBack(String uri) {
    _writeBackTimers[uri]?.cancel();
    _writeBackTimers[uri] = Timer(writeBackDebounceDuration, () async {
      _writeBackTimers.remove(uri);
      await _performAtomicWriteBack(uri);
    });
  }

  Future<void> _performAtomicWriteBack(String uri) async {
    final index = state.tabs.indexWhere((t) => t.uri == uri);
    if (index == -1) return;
    final tab = state.tabs[index];
    if (tab.isPdf || tab.content == tab.savedContent) {
      await DatabaseService.instance.deleteDraft(uri);
      return;
    }

    try {
      await _storage.writeFile(tab.uri, tab.content);
      await DatabaseService.instance.deleteDraft(tab.uri);

      if (index < state.tabs.length && state.tabs[index].uri == uri) {
        final newTabs = List<EditorTab>.from(state.tabs);
        newTabs[index] = tab.copyWith(savedContent: tab.content);
        state = state.copyWith(tabs: newTabs);
      }
      onFileSaved?.call(tab.uri, tab.content);
    } catch (_) {}
  }

  /// Flushes all pending write-backs and hot-exit drafts to disk immediately
  Future<void> flushPendingWrites() async {
    for (final timer in _hotExitTimers.values) {
      timer.cancel();
    }
    _hotExitTimers.clear();

    for (final timer in _writeBackTimers.values) {
      timer.cancel();
    }
    _writeBackTimers.clear();

    final newTabs = List<EditorTab>.from(state.tabs);
    bool changed = false;

    for (int i = 0; i < newTabs.length; i++) {
      final tab = newTabs[i];
      if (!tab.isPdf && tab.content != tab.savedContent) {
        try {
          await _storage.writeFile(tab.uri, tab.content);
          await DatabaseService.instance.deleteDraft(tab.uri);
          newTabs[i] = tab.copyWith(savedContent: tab.content);
          changed = true;
          onFileSaved?.call(tab.uri, tab.content);
        } catch (_) {}
      }
    }

    if (changed) {
      state = state.copyWith(tabs: newTabs);
    }
  }

  /// Reads content via SAF, checks for uncommitted Hot Exit draft, adds tab or switches to existing tab
  Future<void> openFile(String uri, String fileName) async {
    final index = state.tabs.indexWhere((tab) => tab.uri == uri);
    if (index != -1) {
      switchTab(index);
      return;
    }

    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    try {
      final diskContent = isPdf ? uri : await _storage.readFile(uri);
      String initialContent = diskContent;
      String savedContent = diskContent;
      int cursor = 0;

      if (!isPdf) {
        final draft = await DatabaseService.instance.getDraft(uri);
        if (draft != null) {
          final draftContent = draft['content'] as String?;
          if (draftContent != null && draftContent != diskContent) {
            initialContent = draftContent;
            cursor = (draft['cursor_position'] as int?) ?? 0;
            // savedContent remains diskContent so tab shows unsaved dirty dot
          } else {
            await DatabaseService.instance.deleteDraft(uri);
          }
        }
      }

      final newTab = EditorTab(
        uri: uri,
        fileName: fileName,
        content: initialContent,
        savedContent: savedContent,
        cursorPosition: cursor,
      );

      state = state.copyWith(
        tabs: [...state.tabs, newTab],
        activeTabIndex: state.tabs.length,
      );
    } catch (e) {
      // Create empty tab on error
      final fallbackTab = EditorTab(
        uri: uri,
        fileName: fileName,
        content: isPdf ? uri : '',
        savedContent: isPdf ? uri : '',
      );
      state = state.copyWith(
        tabs: [...state.tabs, fallbackTab],
        activeTabIndex: state.tabs.length,
      );
    }
  }

  /// Reloads the file content from disk for a specific URI if open
  Future<void> reloadFile(String uri) async {
    final index = state.tabs.indexWhere((tab) => tab.uri == uri);
    if (index == -1) return;
    if (state.tabs[index].isPdf) return;
    try {
      final content = await _storage.readFile(uri);
      final updatedTab = state.tabs[index].copyWith(
        content: content,
        savedContent: content,
      );
      final newTabs = List<EditorTab>.from(state.tabs);
      newTabs[index] = updatedTab;
      state = state.copyWith(tabs: newTabs);
    } catch (_) {}
  }

  /// Reloads the currently active tab from disk
  Future<void> reloadCurrentTab() async {
    final active = state.activeTab;
    if (active != null) {
      await reloadFile(active.uri);
    }
  }

  /// Convenience method for opening a FileNode
  Future<void> openFileNode(FileNode node) async {
    await openFile(node.uri, node.name);
  }

  /// Removes the tab at index or with tabId, flushes changes if dirty, and adjusts activeTabIndex gracefully
  Future<void> closeTab(dynamic target) async {
    int index = -1;
    if (target is int) {
      index = target;
    } else if (target is String) {
      index = state.tabs.indexWhere((t) => t.uri == target || t.id == target);
    }

    if (index < 0 || index >= state.tabs.length) {
      return;
    }

    final tabToClose = state.tabs[index];
    _hotExitTimers[tabToClose.uri]?.cancel();
    _hotExitTimers.remove(tabToClose.uri);
    _writeBackTimers[tabToClose.uri]?.cancel();
    _writeBackTimers.remove(tabToClose.uri);

    // Update in-memory state synchronously for instant UI responsiveness
    final newTabs = List<EditorTab>.from(state.tabs)..removeAt(index);
    int newIndex = state.activeTabIndex;

    if (newTabs.isEmpty) {
      newIndex = -1;
    } else if (newIndex >= index) {
      newIndex = (newIndex - 1).clamp(0, newTabs.length - 1);
    } else if (newIndex >= newTabs.length) {
      newIndex = newTabs.length - 1;
    }

    state = state.copyWith(
      tabs: newTabs,
      activeTabIndex: newIndex,
    );

    // If tab had unsaved changes, flush to disk asynchronously
    if (!tabToClose.isPdf && tabToClose.content != tabToClose.savedContent) {
      try {
        await _storage.writeFile(tabToClose.uri, tabToClose.content);
        await DatabaseService.instance.deleteDraft(tabToClose.uri);
        onFileSaved?.call(tabToClose.uri, tabToClose.content);
      } catch (_) {}
    } else {
      await DatabaseService.instance.deleteDraft(tabToClose.uri);
    }
  }

  /// Closes the currently active tab
  Future<void> closeActiveTab() {
    if (state.activeTabIndex >= 0 && state.activeTabIndex < state.tabs.length) {
      return closeTab(state.activeTabIndex);
    }
    return Future.value();
  }

  /// Cycles to the next open tab (wrapping around)
  void nextTab() {
    if (state.tabs.length <= 1) return;
    final nextIndex = (state.activeTabIndex + 1) % state.tabs.length;
    switchTab(nextIndex);
  }

  /// Cycles to the previous open tab (wrapping around)
  void previousTab() {
    if (state.tabs.length <= 1) return;
    final prevIndex = (state.activeTabIndex - 1 + state.tabs.length) % state.tabs.length;
    switchTab(prevIndex);
  }

  /// Closes all tabs except the specified index
  void closeOtherTabs(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= state.tabs.length) return;
    final keptTab = state.tabs[keepIndex];
    state = state.copyWith(
      tabs: [keptTab],
      activeTabIndex: 0,
    );
  }

  /// Closes all tabs to the right of the specified index
  void closeTabsToTheRight(int fromIndex) {
    if (fromIndex < 0 || fromIndex >= state.tabs.length - 1) return;
    final newTabs = state.tabs.sublist(0, fromIndex + 1);
    final newActive = state.activeTabIndex > fromIndex ? fromIndex : state.activeTabIndex;
    state = state.copyWith(
      tabs: newTabs,
      activeTabIndex: newActive,
    );
  }

  /// Sets the currently active tab by index or tabId
  void switchTab(dynamic target) {
    int index = -1;
    if (target is int) {
      index = target;
    } else if (target is String) {
      index = state.tabs.indexWhere((t) => t.uri == target || t.id == target);
    }

    if (index >= 0 && index < state.tabs.length) {
      state = state.copyWith(activeTabIndex: index);
    }
  }

  /// Updates the content of the currently active tab
  void updateActiveTabContent(String content, {bool recordUndo = true}) =>
      updateContent(content, recordUndo: recordUndo);

  /// Saves the active tab to disk
  Future<void> saveCurrentTab() => saveActiveFile();

  /// Updates the content of the currently active tab
  void updateContent(String content, {bool recordUndo = true}) {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return;
    }

    final newTabs = List<EditorTab>.from(state.tabs);
    final activeTab = newTabs[state.activeTabIndex];

    if (activeTab.content == content) return;

    List<String> newUndoStack = activeTab.undoStack;
    if (recordUndo) {
      newUndoStack = [...activeTab.undoStack, activeTab.content];
      if (newUndoStack.length > 50) {
        newUndoStack = newUndoStack.sublist(newUndoStack.length - 50);
      }
    }

    newTabs[state.activeTabIndex] = activeTab.copyWith(
      content: content,
      undoStack: newUndoStack,
      redoStack: recordUndo ? const [] : activeTab.redoStack,
    );

    state = state.copyWith(tabs: newTabs);

    // Two-tier persistence engine:
    // Tier 1: Micro-debounced instant Hot Exit snapshot to SQLite (150ms)
    // Tier 2: Debounced atomic write-back to disk (500ms)
    if (!activeTab.isPdf) {
      _scheduleHotExitDraft(activeTab.uri, content, activeTab.cursorPosition);
      _scheduleDebouncedWriteBack(activeTab.uri);
    }
  }

  /// Undoes the last change in the currently active tab
  void undo() {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return;
    }

    final newTabs = List<EditorTab>.from(state.tabs);
    final activeTab = newTabs[state.activeTabIndex];

    if (activeTab.undoStack.isEmpty) return;

    final previousContent = activeTab.undoStack.last;
    final newUndoStack = List<String>.from(activeTab.undoStack)..removeLast();
    final newRedoStack = [...activeTab.redoStack, activeTab.content];

    newTabs[state.activeTabIndex] = activeTab.copyWith(
      content: previousContent,
      undoStack: newUndoStack,
      redoStack: newRedoStack,
    );

    state = state.copyWith(tabs: newTabs);
  }

  /// Redoes the last undone change in the currently active tab
  void redo() {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return;
    }

    final newTabs = List<EditorTab>.from(state.tabs);
    final activeTab = newTabs[state.activeTabIndex];

    if (activeTab.redoStack.isEmpty) return;

    final nextContent = activeTab.redoStack.last;
    final newRedoStack = List<String>.from(activeTab.redoStack)..removeLast();
    final newUndoStack = [...activeTab.undoStack, activeTab.content];

    newTabs[state.activeTabIndex] = activeTab.copyWith(
      content: nextContent,
      undoStack: newUndoStack,
      redoStack: newRedoStack,
    );

    state = state.copyWith(tabs: newTabs);
  }

  /// Updates cursor line and column
  void updateCursor(int line, int column) {
    state = state.copyWith(cursorLine: line, cursorColumn: column);
  }

  /// Updates the cursor position for the currently active tab
  void updateCursorPosition(int position) {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return;
    }

    final newTabs = List<EditorTab>.from(state.tabs);
    final activeTab = newTabs[state.activeTabIndex];

    newTabs[state.activeTabIndex] = activeTab.copyWith(cursorPosition: position);

    state = state.copyWith(tabs: newTabs);
  }

  /// Sets a target range to highlight and focus in the editor canvas
  void highlightRange({
    required int offset,
    required int length,
    Color? color,
    bool isReplacement = false,
  }) {
    state = state.copyWith(
      activeHighlightRange: TextRange(start: offset, end: offset + length),
      activeHighlightColor: color,
      isReplacementHighlight: isReplacement,
      highlightVersion: state.highlightVersion + 1,
    );
  }

  /// Clears any active highlight range
  void clearHighlight() {
    state = state.copyWith(
      activeHighlightRange: null,
      activeHighlightColor: null,
      isReplacementHighlight: false,
    );
  }

  /// Writes content via SAF for the active tab and updates savedContent state
  Future<void> saveActiveFile() async {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return;
    }

    final activeTab = state.tabs[state.activeTabIndex];
    if (activeTab.isPdf || activeTab.content == activeTab.savedContent) {
      await DatabaseService.instance.deleteDraft(activeTab.uri);
      return;
    }

    try {
      _hotExitTimers[activeTab.uri]?.cancel();
      _hotExitTimers.remove(activeTab.uri);
      _writeBackTimers[activeTab.uri]?.cancel();
      _writeBackTimers.remove(activeTab.uri);

      await _storage.writeFile(activeTab.uri, activeTab.content);
      await DatabaseService.instance.deleteDraft(activeTab.uri);

      final newTabs = List<EditorTab>.from(state.tabs);
      newTabs[state.activeTabIndex] = activeTab.copyWith(savedContent: activeTab.content);

      state = state.copyWith(tabs: newTabs);
      onFileSaved?.call(activeTab.uri, activeTab.content);
    } catch (_) {}
  }

  /// Saves all dirty tabs
  Future<void> saveAllFiles() async {
    final newTabs = List<EditorTab>.from(state.tabs);
    bool changed = false;

    for (int i = 0; i < newTabs.length; i++) {
      final tab = newTabs[i];
      if (!tab.isPdf && tab.content != tab.savedContent) {
        try {
          _hotExitTimers[tab.uri]?.cancel();
          _hotExitTimers.remove(tab.uri);
          _writeBackTimers[tab.uri]?.cancel();
          _writeBackTimers.remove(tab.uri);

          await _storage.writeFile(tab.uri, tab.content);
          await DatabaseService.instance.deleteDraft(tab.uri);
          newTabs[i] = tab.copyWith(savedContent: tab.content);
          changed = true;
          onFileSaved?.call(tab.uri, tab.content);
        } catch (_) {}
      }
    }

    if (changed) {
      state = state.copyWith(tabs: newTabs);
    }
  }

  /// Toggles source/split/preview view mode
  void setViewMode(EditorViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  /// Inserts or updates full structured YAML frontmatter at line 1 of the active document
  void insertFrontMatterInActiveFile({
    String? title,
    DateTime? date,
    String? dayOfWeek,
    String? mood,
    List<String>? tags,
    List<String>? topics,
    String? status,
  }) {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return;
    }

    final activeTab = state.tabs[state.activeTabIndex];
    final defaultTitle = title ?? (activeTab.fileName.endsWith('.md')
        ? activeTab.fileName.substring(0, activeTab.fileName.length - 3)
        : activeTab.fileName);

    final updatedContent = FrontMatterService.insertOrUpdateFullFrontMatter(
      activeTab.content,
      title: defaultTitle,
      date: date,
      dayOfWeek: dayOfWeek,
      mood: mood,
      tags: tags,
      topics: topics,
      status: status,
    );

    updateContent(updatedContent);
    onFileSaved?.call(activeTab.uri, updatedContent);
  }

  /// Toggles a tag in the currently open file's YAML frontmatter.
  /// Returns whether the tag is now attached (true/false), or null if no file is open.
  bool? toggleTagInActiveFile(String tag) {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return null;
    }

    final activeTab = state.tabs[state.activeTabIndex];
    final updatedContent = FrontMatterService.toggleTag(activeTab.content, tag);
    updateContent(updatedContent);
    final isNowActive = FrontMatterService.hasTag(updatedContent, tag);
    onFileSaved?.call(activeTab.uri, updatedContent);
    return isNowActive;
  }

  /// Checks if active file has given tag
  bool activeFileHasTag(String tag) {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return false;
    }
    final activeTab = state.tabs[state.activeTabIndex];
    return FrontMatterService.hasTag(activeTab.content, tag);
  }

  /// Toggles a topic in the currently open file's YAML frontmatter.
  /// Returns whether the topic is now attached (true/false), or null if no file is open.
  bool? toggleTopicInActiveFile(String topic) {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return null;
    }

    final activeTab = state.tabs[state.activeTabIndex];
    final updatedContent = FrontMatterService.toggleTopic(activeTab.content, topic);
    updateContent(updatedContent);
    final isNowActive = FrontMatterService.hasTopic(updatedContent, topic);
    onFileSaved?.call(activeTab.uri, updatedContent);
    return isNowActive;
  }

  /// Checks if active file has given topic
  bool activeFileHasTopic(String topic) {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return false;
    }
    final activeTab = state.tabs[state.activeTabIndex];
    return FrontMatterService.hasTopic(activeTab.content, topic);
  }

  /// Handle drag reorder of tabs
  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= state.tabs.length ||
        newIndex < 0 ||
        newIndex > state.tabs.length) {
      return;
    }

    final newTabs = List<EditorTab>.from(state.tabs);
    final tab = newTabs.removeAt(oldIndex);

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    newTabs.insert(newIndex, tab);

    int activeIndex = state.activeTabIndex;
    if (activeIndex == oldIndex) {
      activeIndex = newIndex;
    } else if (activeIndex > oldIndex && activeIndex <= newIndex) {
      activeIndex -= 1;
    } else if (activeIndex < oldIndex && activeIndex >= newIndex) {
      activeIndex += 1;
    }

    state = state.copyWith(tabs: newTabs, activeTabIndex: activeIndex);
  }

  /// Updates the URI and fileName of an open tab when a file is moved or renamed
  void updateFileUri(String oldUri, String newUri, {String? newFileName}) {
    final index = state.tabs.indexWhere((t) => t.uri == oldUri);
    if (index != -1) {
      final oldTab = state.tabs[index];
      final fileName = newFileName ?? p.basename(newUri);
      final newTabs = List<EditorTab>.from(state.tabs);
      newTabs[index] = oldTab.copyWith(
        uri: newUri,
        fileName: fileName,
      );
      state = state.copyWith(tabs: newTabs);
    }
  }

  @override
  void dispose() {
    for (final timer in _hotExitTimers.values) {
      timer.cancel();
    }
    _hotExitTimers.clear();
    for (final timer in _writeBackTimers.values) {
      timer.cancel();
    }
    _writeBackTimers.clear();
    super.dispose();
  }
}
