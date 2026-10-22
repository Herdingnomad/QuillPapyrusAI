class TypographyService {
  TypographyService._();
  static final TypographyService instance = TypographyService._();

  /// Standard fiction scene break dividers
  static const List<String> sceneDividers = [
    '* * *',
    '#',
    '— ❖ —',
    '❦',
    '✦ ✦ ✦',
    '~ ~ ~',
  ];

  /// Converts plain text smart punctuation (curly quotes, em-dashes, ellipses)
  String applySmartTypography(String input) {
    if (input.isEmpty) return input;

    var text = input;

    // Temporarily extract code blocks and inline code
    final codeSnippets = <String>[];
    text = text.replaceAllMapped(RegExp(r'```[\s\S]*?```'), (m) {
      codeSnippets.add(m.group(0)!);
      return '__TYPO_CODE_${codeSnippets.length - 1}__';
    });
    text = text.replaceAllMapped(RegExp(r'`[^`\n]+`'), (m) {
      codeSnippets.add(m.group(0)!);
      return '__TYPO_CODE_${codeSnippets.length - 1}__';
    });

    // Convert em-dashes: '---' and '--' -> '—'
    text = text.replaceAll('---', '—');
    text = text.replaceAll('--', '—');

    // Convert ellipses: '...' -> '…'
    text = text.replaceAll('...', '…');

    // Smart double quotes: "text" -> “text”
    final doubleQuoteRegex = RegExp(r'(^|[\s\(\[\{—])"([^\s"])');
    while (doubleQuoteRegex.hasMatch(text)) {
      text = text.replaceFirstMapped(doubleQuoteRegex, (m) => '${m[1]}“${m[2]}');
    }
    text = text.replaceAll('"', '”');

    // Smart single quotes & apostrophes: 'word' -> ‘word’, don't -> don’t
    final singleQuoteOpen = RegExp(r"(^|[\s\(\[\{—])'([^\s'])");
    while (singleQuoteOpen.hasMatch(text)) {
      text = text.replaceFirstMapped(singleQuoteOpen, (m) => '${m[1]}‘${m[2]}');
    }
    text = text.replaceAll("'", '’');

    // Restore preserved code snippets
    for (int i = 0; i < codeSnippets.length; i++) {
      text = text.replaceAll('__TYPO_CODE_${i}__', codeSnippets[i]);
    }

    return text;
  }

  /// Checks if a line is a scene break divider
  bool isSceneDivider(String line) {
    final trimmed = line.trim();
    return sceneDividers.contains(trimmed) ||
        trimmed == '***' ||
        trimmed == '* * * * *' ||
        trimmed == '---';
  }

  /// Calculates indentation metrics for manuscript book paragraphs
  /// Rules:
  /// 1. Suppress indent on first paragraph after heading
  /// 2. Suppress indent immediately following a scene divider (* * *, #)
  /// 3. Indent all subsequent body prose paragraphs by 2.5em (approx 3 spaces)
  bool shouldIndentParagraph({
    required int paragraphIndex,
    required String currentParagraph,
    String? previousParagraph,
  }) {
    if (currentParagraph.trim().startsWith('#') ||
        currentParagraph.trim().startsWith('>') ||
        currentParagraph.trim().startsWith('-') ||
        isSceneDivider(currentParagraph)) {
      return false;
    }

    if (previousParagraph == null) return false;

    final prev = previousParagraph.trim();
    if (prev.startsWith('#') || isSceneDivider(prev) || prev.startsWith('---')) {
      return false; // Suppress indent on chapter opening or scene break
    }

    return true;
  }
}
