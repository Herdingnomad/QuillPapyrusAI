import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/search_models.dart';

class SearchService {
  SearchService._();
  static final SearchService instance = SearchService._();

  /// Compiles a RegExp safely handling invalid patterns
  RegExp? compilePattern(SearchOptions options) {
    if (options.query.isEmpty) return null;

    try {
      String pattern = options.query;
      if (!options.useRegex) {
        pattern = RegExp.escape(pattern);
      }
      if (options.wholeWord) {
        pattern = r'\b' + pattern + r'\b';
      }

      return RegExp(
        pattern,
        caseSensitive: options.matchCase,
        multiLine: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Finds all matches in a given text content
  List<SearchMatch> findMatches(String content, SearchOptions options) {
    final regex = compilePattern(options);
    if (regex == null) return [];

    final matches = <SearchMatch>[];
    int idx = 0;

    for (final m in regex.allMatches(content)) {
      final start = m.start;
      final end = m.end;
      final matchedText = m.group(0) ?? '';

      // Compute line and column
      final textBefore = content.substring(0, start);
      final line = '\n'.allMatches(textBefore).length + 1;
      final lastNewline = textBefore.lastIndexOf('\n');
      final col = start - (lastNewline == -1 ? 0 : lastNewline + 1) + 1;

      matches.add(SearchMatch(
        index: idx++,
        startOffset: start,
        endOffset: end,
        matchedText: matchedText,
        line: line,
        column: col,
      ));
    }

    return matches;
  }

  /// Replaces the currently selected match
  String replaceMatch({
    required String content,
    required SearchMatch match,
    required String replacement,
  }) {
    if (match.startOffset < 0 || match.endOffset > content.length) return content;
    return content.replaceRange(match.startOffset, match.endOffset, replacement);
  }

  /// Replaces all matches in the content
  String replaceAll({
    required String content,
    required SearchOptions options,
  }) {
    final regex = compilePattern(options);
    if (regex == null) return content;
    return content.replaceAll(regex, options.replaceWith);
  }

  /// Searches all markdown files in a workspace directory
  Future<List<WorkspaceSearchResult>> searchWorkspace({
    required String rootPath,
    required SearchOptions options,
  }) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return [];

    final regex = compilePattern(options);
    if (regex == null) return [];

    final results = <WorkspaceSearchResult>[];

    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        final name = p.basename(entity.path);
        if (name.startsWith('.') || (ext != '.md' && ext != '.txt' && ext != '.markdown')) {
          continue;
        }

        try {
          final content = await entity.readAsString();
          final lines = content.split('\n');
          final matchingLines = <WorkspaceMatchLine>[];

          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            final matches = regex.allMatches(line);
            for (final m in matches) {
              matchingLines.add(WorkspaceMatchLine(
                lineNumber: i + 1,
                lineText: line,
                startOffsetInLine: m.start,
                matchLength: m.end - m.start,
              ));
            }
          }

          if (matchingLines.isNotEmpty) {
            results.add(WorkspaceSearchResult(
              fileUri: entity.path,
              fileName: name,
              relativePath: p.relative(entity.path, from: rootPath).replaceAll(r'\', '/'),
              matchLines: matchingLines,
            ));
          }
        } catch (_) {}
      }
    }

    return results;
  }
}
