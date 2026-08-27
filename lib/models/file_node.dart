import 'package:equatable/equatable.dart';

class FileNode with Equatable {
  final String uri;
  final String name;
  final String path;
  final bool isDirectory;
  final List<FileNode> children;
  final DateTime? lastModified;
  final int? sizeBytes;

  const FileNode({
    required this.uri,
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
    this.lastModified,
    this.sizeBytes,
  });

  FileNode copyWith({
    String? uri,
    String? name,
    String? path,
    bool? isDirectory,
    List<FileNode>? children,
    DateTime? lastModified,
    int? sizeBytes,
  }) {
    return FileNode(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      children: children ?? this.children,
      lastModified: lastModified ?? this.lastModified,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  @override
  List<Object?> get props => [uri];

  int get fileCount {
    if (!isDirectory) return 1;
    return children.fold(0, (count, child) => count + child.fileCount);
  }

  FileNode? findByName(String searchName) {
    if (name == searchName) return this;
    for (final child in children) {
      final found = child.findByName(searchName);
      if (found != null) return found;
    }
    return null;
  }

  FileNode? findByUri(String searchUri) {
    if (uri == searchUri) return this;
    for (final child in children) {
      final found = child.findByUri(searchUri);
      if (found != null) return found;
    }
    return null;
  }

  List<FileNode> get sortedChildren {
    final dirs = children.where((c) => c.isDirectory).toList();
    final files = children.where((c) => !c.isDirectory).toList();

    dirs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return [...dirs, ...files];
  }
}
