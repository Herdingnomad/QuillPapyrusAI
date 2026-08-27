import 'package:quill_papyrus_ai/models/file_node.dart';

class WikilinkMatch {
  final String fullMatch;
  final String target;
  final String? displayText;
  final int startIndex;
  final int endIndex;

  WikilinkMatch({
    required this.fullMatch,
    required this.target,
    this.displayText,
    required this.startIndex,
    required this.endIndex,
  });
}

class WikilinkService {
  static final RegExp _wikilinkExp = RegExp(r'\[\[(.*?)(?:\|(.*?))?\]\]');

  static List<WikilinkMatch> findWikilinks(String content) {
    final matches = <WikilinkMatch>[];
    for (final match in _wikilinkExp.allMatches(content)) {
      matches.add(WikilinkMatch(
        fullMatch: match.group(0)!,
        target: match.group(1)!,
        displayText: match.group(2),
        startIndex: match.start,
        endIndex: match.end,
      ));
    }
    return matches;
  }

  static String? resolveWikilink(String target, FileNode workspaceRoot) {
    String searchName = target.toLowerCase();
    if (!searchName.endsWith('.md')) {
      searchName += '.md';
    }

    FileNode? findMatch(FileNode node) {
      if (!node.isDirectory && node.name.toLowerCase() == searchName) {
        return node;
      }
      for (final child in node.children) {
        final match = findMatch(child);
        if (match != null) return match;
      }
      return null;
    }

    final match = findMatch(workspaceRoot);
    return match?.uri;
  }

  static String renderWikilinksToMarkdown(String content, FileNode workspaceRoot) {
    return content.replaceAllMapped(_wikilinkExp, (match) {
      final target = match.group(1)!;
      final display = match.group(2) ?? target;
      final resolvedUri = resolveWikilink(target, workspaceRoot);

      if (resolvedUri != null) {
        return '[$display]($resolvedUri)';
      } else {
        return '<span class="unresolved-wikilink">$display</span>';
      }
    });
  }
}
