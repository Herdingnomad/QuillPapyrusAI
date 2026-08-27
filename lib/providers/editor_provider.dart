import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/editor_tab.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';
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

  const EditorState({
    this.tabs = const [],
    this.activeTabIndex = -1,
    this.viewMode = EditorViewMode.source,
    this.cursorLine = 1,
    this.cursorColumn = 1,
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
  }) {
    return EditorState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      viewMode: viewMode ?? this.viewMode,
      cursorLine: cursorLine ?? this.cursorLine,
      cursorColumn: cursorColumn ?? this.cursorColumn,
    );
  }

  @override
  List<Object?> get props => [tabs, activeTabIndex, viewMode, cursorLine, cursorColumn];
}

/// Main editor provider for managing tabs and content
final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  return EditorNotifier(ref.read(safStorageServiceProvider));
});

/// Notifier for managing open editor tabs, their content, and saving files
class EditorNotifier extends StateNotifier<EditorState> {
  final SafStorageService _storage;

  EditorNotifier(this._storage) : super(const EditorState());

  /// Reads content via SAF, adds tab or switches to existing tab
  Future<void> openFile(String uri, String fileName) async {
    final index = state.tabs.indexWhere((tab) => tab.uri == uri);
    if (index != -1) {
      switchTab(index);
      return;
    }

    try {
      final content = await _storage.readFile(uri);
      final newTab = EditorTab(
        uri: uri,
        fileName: fileName,
        content: content,
        savedContent: content,
        cursorPosition: 0,
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
        content: '',
        savedContent: '',
      );
      state = state.copyWith(
        tabs: [...state.tabs, fallbackTab],
        activeTabIndex: state.tabs.length,
      );
    }
  }

  /// Convenience method for opening a FileNode
  Future<void> openFileNode(FileNode node) async {
    await openFile(node.uri, node.name);
  }

  /// Removes the tab at index or with tabId and adjusts activeTabIndex gracefully
  void closeTab(dynamic target) {
    int index = -1;
    if (target is int) {
      index = target;
    } else if (target is String) {
      index = state.tabs.indexWhere((t) => t.uri == target || t.id == target);
    }

    if (index < 0 || index >= state.tabs.length) {
      return;
    }

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

  /// Writes content via SAF for the active tab and updates savedContent state
  Future<void> saveActiveFile() async {
    if (state.activeTabIndex < 0 || state.activeTabIndex >= state.tabs.length) {
      return;
    }

    final activeTab = state.tabs[state.activeTabIndex];
    if (activeTab.content == activeTab.savedContent) {
      return;
    }

    try {
      await _storage.writeFile(activeTab.uri, activeTab.content);

      final newTabs = List<EditorTab>.from(state.tabs);
      newTabs[state.activeTabIndex] = activeTab.copyWith(savedContent: activeTab.content);

      state = state.copyWith(tabs: newTabs);
    } catch (_) {}
  }

  /// Saves all dirty tabs
  Future<void> saveAllFiles() async {
    final newTabs = List<EditorTab>.from(state.tabs);
    bool changed = false;

    for (int i = 0; i < newTabs.length; i++) {
      final tab = newTabs[i];
      if (tab.content != tab.savedContent) {
        try {
          await _storage.writeFile(tab.uri, tab.content);
          newTabs[i] = tab.copyWith(savedContent: tab.content);
          changed = true;
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
}
