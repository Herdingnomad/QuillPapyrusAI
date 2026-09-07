import 'package:equatable/equatable.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';

enum WorkspaceStatus { initial, loading, loaded, error }

class WorkspaceState with Equatable {
  final WorkspaceStatus status;
  final String? rootUri;
  final String? rootName;
  final FileNode? fileTree;
  final Set<String> expandedDirs;
  final String? selectedFileUri;
  final String? errorMessage;
  final List<String> tags;
  final Map<String, List<String>> tagIndex;
  final List<String> topics;
  final Map<String, List<String>> topicIndex;

  const WorkspaceState({
    this.status = WorkspaceStatus.initial,
    this.rootUri,
    this.rootName,
    this.fileTree,
    this.expandedDirs = const {},
    this.selectedFileUri,
    this.errorMessage,
    this.tags = const [],
    this.tagIndex = const {},
    this.topics = const [],
    this.topicIndex = const {},
  });

  bool get isLoading => status == WorkspaceStatus.loading;
  bool get isLoaded => status == WorkspaceStatus.loaded;
  bool get hasError => status == WorkspaceStatus.error;
  String? get error => errorMessage;
  FileNode? get rootNode => fileTree;

  WorkspaceState copyWith({
    WorkspaceStatus? status,
    bool? isLoading,
    String? rootUri,
    String? rootName,
    FileNode? fileTree,
    FileNode? rootNode,
    Set<String>? expandedDirs,
    String? selectedFileUri,
    String? errorMessage,
    String? error,
    List<String>? tags,
    Map<String, List<String>>? tagIndex,
    List<String>? topics,
    Map<String, List<String>>? topicIndex,
  }) {
    WorkspaceStatus newStatus = status ?? this.status;
    if (isLoading != null) {
      newStatus = isLoading
          ? WorkspaceStatus.loading
          : (fileTree != null || rootNode != null || this.fileTree != null
              ? WorkspaceStatus.loaded
              : WorkspaceStatus.initial);
    }
    if (errorMessage != null || error != null) {
      if (errorMessage != null || (error != null && error.isNotEmpty)) {
        newStatus = WorkspaceStatus.error;
      }
    }

    return WorkspaceState(
      status: newStatus,
      rootUri: rootUri ?? this.rootUri,
      rootName: rootName ?? this.rootName,
      fileTree: fileTree ?? rootNode ?? this.fileTree,
      expandedDirs: expandedDirs ?? this.expandedDirs,
      selectedFileUri: selectedFileUri ?? this.selectedFileUri,
      errorMessage: errorMessage ?? error ?? this.errorMessage,
      tags: tags ?? this.tags,
      tagIndex: tagIndex ?? this.tagIndex,
      topics: topics ?? this.topics,
      topicIndex: topicIndex ?? this.topicIndex,
    );
  }

  @override
  List<Object?> get props => [
        status,
        rootUri,
        rootName,
        fileTree,
        expandedDirs,
        selectedFileUri,
        errorMessage,
        tags,
        tagIndex,
        topics,
        topicIndex,
      ];
}
