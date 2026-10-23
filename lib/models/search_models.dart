import 'package:equatable/equatable.dart';

class SearchOptions with Equatable {
  final String query;
  final String replaceWith;
  final bool matchCase;
  final bool useRegex;
  final bool wholeWord;
  final bool inSelectionOnly;

  const SearchOptions({
    this.query = '',
    this.replaceWith = '',
    this.matchCase = false,
    this.useRegex = false,
    this.wholeWord = false,
    this.inSelectionOnly = false,
  });

  SearchOptions copyWith({
    String? query,
    String? replaceWith,
    bool? matchCase,
    bool? useRegex,
    bool? wholeWord,
    bool? inSelectionOnly,
  }) {
    return SearchOptions(
      query: query ?? this.query,
      replaceWith: replaceWith ?? this.replaceWith,
      matchCase: matchCase ?? this.matchCase,
      useRegex: useRegex ?? this.useRegex,
      wholeWord: wholeWord ?? this.wholeWord,
      inSelectionOnly: inSelectionOnly ?? this.inSelectionOnly,
    );
  }

  @override
  List<Object?> get props => [query, replaceWith, matchCase, useRegex, wholeWord, inSelectionOnly];
}

class SearchMatch with Equatable {
  final int index;
  final int startOffset;
  final int endOffset;
  final String matchedText;
  final int line;
  final int column;

  const SearchMatch({
    required this.index,
    required this.startOffset,
    required this.endOffset,
    required this.matchedText,
    required this.line,
    required this.column,
  });

  @override
  List<Object?> get props => [index, startOffset, endOffset, matchedText, line, column];
}

class WorkspaceMatchLine with Equatable {
  final int lineNumber;
  final String lineText;
  final int startOffsetInLine;
  final int matchLength;

  const WorkspaceMatchLine({
    required this.lineNumber,
    required this.lineText,
    required this.startOffsetInLine,
    required this.matchLength,
  });

  @override
  List<Object?> get props => [lineNumber, lineText, startOffsetInLine, matchLength];
}

class WorkspaceSearchResult with Equatable {
  final String fileUri;
  final String fileName;
  final String relativePath;
  final List<WorkspaceMatchLine> matchLines;

  const WorkspaceSearchResult({
    required this.fileUri,
    required this.fileName,
    required this.relativePath,
    required this.matchLines,
  });

  int get matchCount => matchLines.length;

  @override
  List<Object?> get props => [fileUri, fileName, relativePath, matchLines];
}
