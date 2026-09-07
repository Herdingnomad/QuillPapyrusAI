import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/workspace_state.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';

/// Service provider for SafStorageService (singleton)
final safStorageServiceProvider = Provider<SafStorageService>((ref) => SafStorageService());

/// Main workspace state notifier
final workspaceProvider = StateNotifierProvider<WorkspaceNotifier, WorkspaceState>((ref) {
  return WorkspaceNotifier(ref.read(safStorageServiceProvider));
});

/// Manages workspace state including file tree and directory expansion
class WorkspaceNotifier extends StateNotifier<WorkspaceState> {
  final SafStorageService _storage;

  WorkspaceNotifier(this._storage) : super(const WorkspaceState());

  /// Loads workspace from a specific directory URI
  Future<void> loadWorkspace(String uri) async {
    state = state.copyWith(
      status: WorkspaceStatus.loading,
      errorMessage: null,
    );
    try {
      final tree = await _storage.buildFileTree(uri);
      final meta = await _indexWorkspaceMetadata(tree);
      state = state.copyWith(
        status: WorkspaceStatus.loaded,
        rootUri: uri,
        rootName: tree.name,
        fileTree: tree,
        expandedDirs: {tree.uri},
        tags: meta.tags,
        tagIndex: meta.tagIndex,
        topics: meta.topics,
        topicIndex: meta.topicIndex,
      );
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Automatically initializes and loads the persistent internal storage workspace
  Future<void> loadDefaultWorkspace() async {
    final defaultPath = await _storage.getDefaultWorkspacePath();
    await loadWorkspace(defaultPath);
  }

  /// Calls directory picker and loads the workspace tree
  Future<void> pickAndLoadWorkspace() async {
    state = state.copyWith(
      status: WorkspaceStatus.loading,
      errorMessage: null,
    );
    try {
      final rootUri = await _storage.pickDirectory(forcePicker: true);
      if (rootUri != null) {
        await loadWorkspace(rootUri);
      } else {
        state = state.copyWith(status: state.fileTree != null ? WorkspaceStatus.loaded : WorkspaceStatus.initial);
      }
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Re-scans the current workspace root directory
  Future<void> refreshWorkspace() async {
    if (state.rootUri == null) return;
    state = state.copyWith(
      status: WorkspaceStatus.loading,
      errorMessage: null,
    );
    try {
      final tree = await _storage.buildFileTree(state.rootUri!);
      final meta = await _indexWorkspaceMetadata(tree);
      // Merge with any custom added tags & topics
      final mergedTags = {...state.tags, ...meta.tags}.toList()..sort();
      final mergedTopics = {...state.topics, ...meta.topics}.toList()..sort();
      state = state.copyWith(
        status: WorkspaceStatus.loaded,
        fileTree: tree,
        rootName: tree.name,
        tags: mergedTags,
        tagIndex: meta.tagIndex,
        topics: mergedTopics,
        topicIndex: meta.topicIndex,
      );
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Adds a tag to the workspace
  void addWorkspaceTag(String tag) {
    final clean = tag.trim().replaceAll('#', '');
    if (clean.isEmpty) return;
    if (!state.tags.contains(clean)) {
      final updated = [...state.tags, clean]..sort();
      state = state.copyWith(tags: updated);
    }
  }

  /// Removes a tag from the workspace
  void deleteWorkspaceTag(String tag) {
    final clean = tag.trim().replaceAll('#', '');
    final updated = List<String>.from(state.tags)..remove(clean);
    final updatedIndex = Map<String, List<String>>.from(state.tagIndex)..remove(clean);
    state = state.copyWith(tags: updated, tagIndex: updatedIndex);
  }

  /// Renames a tag in the workspace
  void updateWorkspaceTag(String oldTag, String newTag) {
    final cleanOld = oldTag.trim().replaceAll('#', '');
    final cleanNew = newTag.trim().replaceAll('#', '');
    if (cleanNew.isEmpty) return;
    final updated = List<String>.from(state.tags)..remove(cleanOld);
    if (!updated.contains(cleanNew)) {
      updated.add(cleanNew);
    }
    updated.sort();
    final updatedIndex = Map<String, List<String>>.from(state.tagIndex);
    final files = updatedIndex.remove(cleanOld) ?? [];
    updatedIndex[cleanNew] = files;
    state = state.copyWith(tags: updated, tagIndex: updatedIndex);
  }

  /// Adds a topic to the workspace
  void addWorkspaceTopic(String topic) {
    final clean = topic.trim().replaceAll('@', '');
    if (clean.isEmpty) return;
    if (!state.topics.contains(clean)) {
      final updated = [...state.topics, clean]..sort();
      state = state.copyWith(topics: updated);
    }
  }

  /// Removes a topic from the workspace
  void deleteWorkspaceTopic(String topic) {
    final clean = topic.trim().replaceAll('@', '');
    final updated = List<String>.from(state.topics)..remove(clean);
    final updatedIndex = Map<String, List<String>>.from(state.topicIndex)..remove(clean);
    state = state.copyWith(topics: updated, topicIndex: updatedIndex);
  }

  /// Renames a topic in the workspace
  void updateWorkspaceTopic(String oldTopic, String newTopic) {
    final cleanOld = oldTopic.trim().replaceAll('@', '');
    final cleanNew = newTopic.trim().replaceAll('@', '');
    if (cleanNew.isEmpty) return;
    final updated = List<String>.from(state.topics)..remove(cleanOld);
    if (!updated.contains(cleanNew)) {
      updated.add(cleanNew);
    }
    updated.sort();
    final updatedIndex = Map<String, List<String>>.from(state.topicIndex);
    final files = updatedIndex.remove(cleanOld) ?? [];
    updatedIndex[cleanNew] = files;
    state = state.copyWith(topics: updated, topicIndex: updatedIndex);
  }

  /// Toggles a directory's expanded state in the tree view
  void toggleDirectoryExpansion(String uri) {
    final expandedDirs = Set<String>.from(state.expandedDirs);
    if (expandedDirs.contains(uri)) {
      expandedDirs.remove(uri);
    } else {
      expandedDirs.add(uri);
    }
    state = state.copyWith(expandedDirs: expandedDirs);
  }

  /// Selects a file in the workspace
  void selectFile(String uri) {
    state = state.copyWith(selectedFileUri: uri);
  }

  /// Creates a new file and refreshes the workspace
  Future<String?> createFile(String dirUri, String name) async {
    try {
      final newUri = await _storage.createFile(dirUri, name);
      await refreshWorkspace();
      return newUri;
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Creates a new directory and refreshes the workspace
  Future<String?> createDirectory(String parentUri, String name) async {
    try {
      final newUri = await _storage.createDirectory(parentUri, name);
      await refreshWorkspace();
      return newUri;
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Deletes a file or directory and refreshes the workspace
  Future<void> deleteNode(String uri) async {
    try {
      await _storage.deleteNode(uri);
      await refreshWorkspace();
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Moves a file or directory into a target directory and refreshes
  Future<bool> moveNode(String sourceUri, String targetDirUri) async {
    try {
      final res = await _storage.moveNode(sourceUri, targetDirUri);
      if (res != null) {
        await refreshWorkspace();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Renames a file or directory and refreshes the workspace
  Future<void> renameNode(String uri, String newName) async {
    try {
      await _storage.renameNode(uri, newName);
      await refreshWorkspace();
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Creates a daily journal entry with full pre-filled YAML frontmatter
  Future<String?> createDailyJournalEntry({String? customTitle}) async {
    if (state.rootUri == null) return null;
    final now = DateTime.now();
    final dateStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final fileName = 'Journal Entry - $dateStr.md';
    final title = customTitle ?? 'Journal Entry - $dateStr';

    final frontMatter = FrontMatterService.generateFullFrontMatter(
      title: title,
      date: now,
    );

    try {
      final newUri = await _storage.createFile(state.rootUri!, fileName);
      await _storage.writeFile(newUri, '$frontMatter\n# $title\n\n');
      await refreshWorkspace();
      return newUri;
    } catch (e) {
      state = state.copyWith(
        status: WorkspaceStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Incremental update of tags and topics when a file is saved or edited
  void updateFileMetadata(String uri, String content) {
    final frontMatter = FrontMatterService.parse(content);
    final newTags = frontMatter?.tags ?? [];
    final newTopics = frontMatter?.topics ?? [];

    final updatedTagIndex = <String, Set<String>>{};
    state.tagIndex.forEach((k, v) {
      final s = v.toSet()..remove(uri);
      if (s.isNotEmpty) {
        updatedTagIndex[k] = s;
      }
    });
    for (final tag in newTags) {
      final clean = tag.trim().replaceAll('#', '');
      if (clean.isNotEmpty) {
        updatedTagIndex.putIfAbsent(clean, () => <String>{}).add(uri);
      }
    }

    final updatedTopicIndex = <String, Set<String>>{};
    state.topicIndex.forEach((k, v) {
      final s = v.toSet()..remove(uri);
      if (s.isNotEmpty) {
        updatedTopicIndex[k] = s;
      }
    });
    for (final topic in newTopics) {
      final clean = topic.trim().replaceAll('@', '');
      if (clean.isNotEmpty) {
        updatedTopicIndex.putIfAbsent(clean, () => <String>{}).add(uri);
      }
    }

    final mergedTags = {...state.tags, ...updatedTagIndex.keys}.toList()..sort();
    final mergedTopics = {...state.topics, ...updatedTopicIndex.keys}.toList()..sort();

    state = state.copyWith(
      tags: mergedTags,
      tagIndex: updatedTagIndex.map((k, v) => MapEntry(k, v.toList())),
      topics: mergedTopics,
      topicIndex: updatedTopicIndex.map((k, v) => MapEntry(k, v.toList())),
    );
  }

  Future<_WorkspaceMetadataIndex> _indexWorkspaceMetadata(FileNode root) async {
    final Map<String, Set<String>> tagMap = {};
    final Map<String, Set<String>> topicMap = {};

    Future<void> scanNode(FileNode node) async {
      if (node.isDirectory) {
        for (final child in node.children) {
          await scanNode(child);
        }
      } else if (node.name.toLowerCase().endsWith('.md')) {
        try {
          final content = await _storage.readFile(node.uri);
          final frontMatter = FrontMatterService.parse(content);
          if (frontMatter != null) {
            for (final tag in frontMatter.tags) {
              final clean = tag.trim().replaceAll('#', '');
              if (clean.isNotEmpty) {
                tagMap.putIfAbsent(clean, () => <String>{}).add(node.uri);
              }
            }
            for (final topic in frontMatter.topics) {
              final clean = topic.trim().replaceAll('@', '');
              if (clean.isNotEmpty) {
                topicMap.putIfAbsent(clean, () => <String>{}).add(node.uri);
              }
            }
          }
        } catch (_) {}
      }
    }

    await scanNode(root);

    final tags = tagMap.keys.toList()..sort();
    final topics = topicMap.keys.toList()..sort();
    final tagIndex = tagMap.map((k, v) => MapEntry(k, v.toList()));
    final topicIndex = topicMap.map((k, v) => MapEntry(k, v.toList()));

    return _WorkspaceMetadataIndex(
      tags: tags,
      tagIndex: tagIndex,
      topics: topics,
      topicIndex: topicIndex,
    );
  }
}

class _WorkspaceMetadataIndex {
  final List<String> tags;
  final Map<String, List<String>> tagIndex;
  final List<String> topics;
  final Map<String, List<String>> topicIndex;

  _WorkspaceMetadataIndex({
    required this.tags,
    required this.tagIndex,
    required this.topics,
    required this.topicIndex,
  });
}
