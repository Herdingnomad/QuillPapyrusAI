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
      final tags = await _collectWorkspaceTags(tree);
      state = state.copyWith(
        status: WorkspaceStatus.loaded,
        rootUri: uri,
        rootName: tree.name,
        fileTree: tree,
        expandedDirs: {tree.uri},
        tags: tags,
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
      final tags = await _collectWorkspaceTags(tree);
      // Merge with any custom added tags
      final mergedTags = {...state.tags, ...tags}.toList()..sort();
      state = state.copyWith(
        status: WorkspaceStatus.loaded,
        fileTree: tree,
        rootName: tree.name,
        tags: mergedTags,
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
    state = state.copyWith(tags: updated);
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
    state = state.copyWith(tags: updated);
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

  Future<List<String>> _collectWorkspaceTags(FileNode root) async {
    final Set<String> tags = {};

    Future<void> scanNode(FileNode node) async {
      if (node.isDirectory) {
        for (final child in node.children) {
          await scanNode(child);
        }
      } else if (node.name.toLowerCase().endsWith('.md')) {
        final content = await _storage.readFile(node.uri);
        final frontMatter = FrontMatterService.parse(content);
        if (frontMatter != null) {
          tags.addAll(frontMatter.tags);
        }
      }
    }

    await scanNode(root);
    return tags.toList()..sort();
  }
}
