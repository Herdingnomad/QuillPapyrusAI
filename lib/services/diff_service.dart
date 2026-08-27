import 'dart:math';
import 'package:quill_papyrus_ai/models/diff_model.dart';

class DiffService {
  /// Computes a word/token-level diff between original and proposed text.
  static List<DiffChunk> computeWordDiff(String original, String proposed) {
    if (original == proposed) {
      return [DiffChunk(type: DiffType.equal, text: original)];
    }

    if (original.isEmpty) {
      return [DiffChunk(type: DiffType.addition, text: proposed)];
    }

    if (proposed.isEmpty) {
      return [DiffChunk(type: DiffType.deletion, text: original)];
    }

    final origTokens = _tokenize(original);
    final propTokens = _tokenize(proposed);

    final lcsMatrix = _computeLcsMatrix(origTokens, propTokens);
    final rawChunks = _backtrackLcs(lcsMatrix, origTokens, propTokens, origTokens.length, propTokens.length);

    return _coalesceChunks(rawChunks);
  }

  /// Computes a line-level diff between original and proposed text.
  static List<DiffChunk> computeLineDiff(String original, String proposed) {
    final origLines = original.split('\n');
    final propLines = proposed.split('\n');

    final lcsMatrix = _computeLcsMatrix(origLines, propLines);
    final rawChunks = _backtrackLcs(lcsMatrix, origLines, propLines, origLines.length, propLines.length, isLine: true);

    return _coalesceChunks(rawChunks);
  }

  /// Creates a full InlineDiffProposal comparing a section of document text
  static InlineDiffProposal createProposal({
    required String originalFullText,
    required String proposedReplacement,
    required int selectionStart,
    required int selectionEnd,
    String actionTitle = 'AI Proposed Edit',
  }) {
    final safeStart = selectionStart.clamp(0, originalFullText.length);
    final safeEnd = selectionEnd.clamp(safeStart, originalFullText.length);
    final originalSub = originalFullText.substring(safeStart, safeEnd);
    final chunks = computeWordDiff(originalSub, proposedReplacement);

    return InlineDiffProposal(
      originalText: originalSub,
      proposedText: proposedReplacement,
      chunks: chunks,
      selectionStart: safeStart,
      selectionEnd: safeEnd,
      actionTitle: actionTitle,
    );
  }

  /// Extracts clean markdown content from an AI assistant response,
  /// stripping out conversational greetings, model badges, and markdown code fences.
  static String extractCleanAiContent(String rawAiResponse) {
    var text = rawAiResponse.trim();

    // 1. If wrapped in a code fence (```markdown ... ``` or ``` ... ```), extract just the block
    final codeBlockRegex = RegExp(r'```(?:markdown|md)?\s*\n([\s\S]*?)\n```', multiLine: true);
    final match = codeBlockRegex.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    // 2. Strip leading model badge if present
    text = text.replaceAll(RegExp(r'^>\s*\*\*Local Engine Active\*\*:[^\n]*\n*', multiLine: true), '').trim();

    // 3. Strip conversational headers like "### Assistant Response\n\nHere is what you need..."
    text = text.replaceAll(RegExp(r'^###\s*Assistant Response\s*\n*', multiLine: true), '').trim();
    text = text.replaceAll(RegExp(r'^Here is (?:what you need regarding|a dedicated structure|a structured markdown draft)[^\n]*:\s*\n*', multiLine: true), '').trim();

    // 4. Strip trailing helper notices
    text = text.replaceAll(RegExp(r'\*Tap \*\*Inline Diff\*\* or \*\*Insert\*\*[^\n]*\*', multiLine: true), '').trim();
    text = text.replaceAll(RegExp(r'### Active Note Context[\s\S]*$', multiLine: true), '').trim();
    text = text.replaceAll(RegExp(r'### Active Note Content Reviewed:[\s\S]*$', multiLine: true), '').trim();

    return text.trim();
  }

  /// Locates where the proposed content should be placed in the document:
  /// - Matching section heading replacement
  /// - Selected text replacement
  /// - Or clean append at the end
  static ({int start, int end, String title}) findTargetRange({
    required String documentContent,
    required String replacementText,
    int? activeSelectionStart,
    int? activeSelectionEnd,
  }) {
    // 1. If user has an explicit active selection in editor
    if (activeSelectionStart != null &&
        activeSelectionEnd != null &&
        activeSelectionStart < activeSelectionEnd &&
        activeSelectionEnd <= documentContent.length) {
      return (
        start: activeSelectionStart,
        end: activeSelectionEnd,
        title: 'Selected Text Revision',
      );
    }

    // 2. Check if replacement starts with a heading that exists in the document
    final headingMatch = RegExp(r'^(#{1,4}\s+[^\n]+)', multiLine: true).firstMatch(replacementText);
    if (headingMatch != null) {
      final heading = headingMatch.group(1)!.trim();
      final index = documentContent.indexOf(heading);
      if (index != -1) {
        // Find end of section (next heading of same or higher level, or EOF)
        final headingLevel = heading.indexOf(' ');
        final nextHeadingPattern = RegExp('^#{1,$headingLevel}\\s+', multiLine: true);
        final restOfDoc = documentContent.substring(index + heading.length);
        final nextMatch = nextHeadingPattern.firstMatch(restOfDoc);

        final sectionEnd = nextMatch != null ? index + heading.length + nextMatch.start : documentContent.length;
        return (
          start: index,
          end: sectionEnd,
          title: 'Section Revision ($heading)',
        );
      }
    }

    // 3. Fallback: Append at the end of the document
    return (
      start: documentContent.length,
      end: documentContent.length,
      title: 'Append to Document',
    );
  }

  static List<String> _tokenize(String text) {
    final RegExp tokenRegex = RegExp(r'(\s+|[^\s\w]+|\w+)');
    final matches = tokenRegex.allMatches(text);
    return matches.map((m) => m.group(0)!).toList();
  }

  static List<List<int>> _computeLcsMatrix(List<String> a, List<String> b) {
    final matrix = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          matrix[i][j] = matrix[i - 1][j - 1] + 1;
        } else {
          matrix[i][j] = max(matrix[i - 1][j], matrix[i][j - 1]);
        }
      }
    }

    return matrix;
  }

  static List<DiffChunk> _backtrackLcs(
    List<List<int>> matrix,
    List<String> a,
    List<String> b,
    int i,
    int j, {
    bool isLine = false,
  }) {
    final chunks = <DiffChunk>[];

    int currI = i;
    int currJ = j;

    while (currI > 0 || currJ > 0) {
      if (currI > 0 && currJ > 0 && a[currI - 1] == b[currJ - 1]) {
        final text = isLine ? '${a[currI - 1]}\n' : a[currI - 1];
        chunks.insert(0, DiffChunk(type: DiffType.equal, text: text));
        currI--;
        currJ--;
      } else if (currJ > 0 && (currI == 0 || matrix[currI][currJ - 1] >= matrix[currI - 1][currJ])) {
        final text = isLine ? '${b[currJ - 1]}\n' : b[currJ - 1];
        chunks.insert(0, DiffChunk(type: DiffType.addition, text: text));
        currJ--;
      } else if (currI > 0 && (currJ == 0 || matrix[currI][currJ - 1] < matrix[currI - 1][currJ])) {
        final text = isLine ? '${a[currI - 1]}\n' : a[currI - 1];
        chunks.insert(0, DiffChunk(type: DiffType.deletion, text: text));
        currI--;
      }
    }

    return chunks;
  }

  static List<DiffChunk> _coalesceChunks(List<DiffChunk> chunks) {
    if (chunks.isEmpty) return [];

    final merged = <DiffChunk>[];
    DiffChunk current = chunks.first;

    for (int i = 1; i < chunks.length; i++) {
      final next = chunks[i];
      if (current.type == next.type) {
        current = DiffChunk(
          type: current.type,
          text: current.text + next.text,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    return merged;
  }
}
