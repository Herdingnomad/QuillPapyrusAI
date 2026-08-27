import 'package:equatable/equatable.dart';

class EditorTab with Equatable {
  final String uri;
  final String fileName;
  final String content;
  final String savedContent;
  final int cursorPosition;
  final int scrollOffset;
  final List<String> undoStack;
  final List<String> redoStack;

  const EditorTab({
    required this.uri,
    required this.fileName,
    required this.content,
    required this.savedContent,
    this.cursorPosition = 0,
    this.scrollOffset = 0,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  String get id => uri;
  bool get isDirty => content != savedContent;
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  EditorTab copyWith({
    String? uri,
    String? fileName,
    String? content,
    String? savedContent,
    int? cursorPosition,
    int? scrollOffset,
    List<String>? undoStack,
    List<String>? redoStack,
  }) {
    return EditorTab(
      uri: uri ?? this.uri,
      fileName: fileName ?? this.fileName,
      content: content ?? this.content,
      savedContent: savedContent ?? this.savedContent,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }

  @override
  List<Object?> get props => [
        uri,
        fileName,
        content,
        savedContent,
        cursorPosition,
        scrollOffset,
        undoStack,
        redoStack,
      ];
}
