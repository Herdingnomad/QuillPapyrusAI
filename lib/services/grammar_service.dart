enum GrammarIssueType {
  repeatedWord,
  punctuationSpacing,
  doublePunctuation,
  capitalization,
  homophone,
  cliche,
  passiveVoice,
}

class GrammarIssue {
  final String id;
  final int offset;
  final int length;
  final int line;
  final int column;
  final GrammarIssueType type;
  final String message;
  final String matchedText;
  final List<String> replacements;
  final String severity; // 'error', 'warning', 'suggestion'

  const GrammarIssue({
    required this.id,
    required this.offset,
    required this.length,
    required this.line,
    required this.column,
    required this.type,
    required this.message,
    required this.matchedText,
    required this.replacements,
    this.severity = 'warning',
  });

  String get typeLabel {
    switch (type) {
      case GrammarIssueType.repeatedWord:
        return 'Duplicate Word';
      case GrammarIssueType.punctuationSpacing:
        return 'Punctuation Spacing';
      case GrammarIssueType.doublePunctuation:
        return 'Double Punctuation';
      case GrammarIssueType.capitalization:
        return 'Capitalization';
      case GrammarIssueType.homophone:
        return 'Confused Word';
      case GrammarIssueType.cliche:
        return 'Style & Cliché';
      case GrammarIssueType.passiveVoice:
        return 'Passive Voice';
    }
  }
}

class GrammarService {
  GrammarService._();
  static final GrammarService instance = GrammarService._();

  // Common homophone confusions and contextual regex checks
  static final List<_HomophoneRule> _homophoneRules = [
    // their / there / they're
    _HomophoneRule(
      pattern: RegExp(r'\bthere\s+(car|house|book|dog|cat|friend|friends|parents|family|name|eyes|hands|mind|work|job)\b', caseSensitive: false),
      message: "Did you mean 'their' (possessive) instead of 'there'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\bthere\b', caseSensitive: false), 'their'),
    ),
    _HomophoneRule(
      pattern: RegExp(r'\btheir\s+(is|are|was|were|will|would|can|could|should|seems|has|have|had)\b', caseSensitive: false),
      message: "Did you mean 'there' (location/existential) instead of 'their'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\btheir\b', caseSensitive: false), 'there'),
    ),
    _HomophoneRule(
      pattern: RegExp(r"\bthey're\s+(is|are|was|were)\b", caseSensitive: false),
      message: "Did you mean 'there' instead of 'they're'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r"\bthey're\b", caseSensitive: false), 'there'),
    ),

    // your / you're
    _HomophoneRule(
      pattern: RegExp(r'\byour\s+(welcome|right|wrong|going|doing|tired|ready|sure|awesome|beautiful|smart)\b', caseSensitive: false),
      message: "Did you mean 'you're' (you are) instead of 'your'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\byour\b', caseSensitive: false), "you're"),
    ),
    _HomophoneRule(
      pattern: RegExp(r"\byou're\s+(car|house|name|phone|computer|book|family|friend|time|mind|life)\b", caseSensitive: false),
      message: "Did you mean 'your' (possessive) instead of 'you're'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r"\byou're\b", caseSensitive: false), 'your'),
    ),

    // its / it's
    _HomophoneRule(
      pattern: RegExp(r'\bits\s+(a|an|the|not|been|time|okay|fine|ready|obvious|clear|going)\b', caseSensitive: false),
      message: "Did you mean 'it's' (it is / it has) instead of 'its'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\bits\b', caseSensitive: false), "it's"),
    ),
    _HomophoneRule(
      pattern: RegExp(r"\bit's\s+(own|color|size|shape|tail|fur|surface|nature|place|weight)\b", caseSensitive: false),
      message: "Did you mean 'its' (possessive) instead of 'it's'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r"\bit's\b", caseSensitive: false), 'its'),
    ),

    // affect / effect
    _HomophoneRule(
      pattern: RegExp(r'\b(the|an?|this|that|adverse|positive|negative|side)\s+affect\b', caseSensitive: false),
      message: "Did you mean noun 'effect' instead of verb 'affect'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\baffect\b', caseSensitive: false), 'effect'),
    ),
    _HomophoneRule(
      pattern: RegExp(r'\b(will|would|can|could|to)\s+effect\s+(the|a|an|our|your|my)\b', caseSensitive: false),
      message: "Did you mean verb 'affect' instead of noun 'effect'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\beffect\b', caseSensitive: false), 'affect'),
    ),

    // then / than
    _HomophoneRule(
      pattern: RegExp(r'\b(more|less|better|worse|faster|slower|bigger|smaller|rather|other)\s+then\b', caseSensitive: false),
      message: "Did you mean comparison 'than' instead of sequential 'then'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\bthen\b', caseSensitive: false), 'than'),
    ),
    _HomophoneRule(
      pattern: RegExp(r'\b(back|since|until|even|and|but)\s+than\b', caseSensitive: false),
      message: "Did you mean 'then' instead of 'than'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\bthan\b', caseSensitive: false), 'then'),
    ),

    // loose / lose
    _HomophoneRule(
      pattern: RegExp(r'\b(don\x27t|to|will|might|could)\s+loose\b', caseSensitive: false),
      message: "Did you mean 'lose' (misplace/fail) instead of 'loose' (unfastened)?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\bloose\b', caseSensitive: false), 'lose'),
    ),

    // lead / led
    _HomophoneRule(
      pattern: RegExp(r'\b(he|she|they|who)\s+lead\s+(the|them|us|her|him|to|through|into)\b', caseSensitive: false),
      message: "Did you mean past-tense 'led' instead of present/metal 'lead'?",
      replacementBuilder: (m) => m.group(0)!.replaceFirst(RegExp(r'\blead\b', caseSensitive: false), 'led'),
    ),
  ];

  // Common wordy clichés / filler phrases
  static final Map<String, String> _cliches = {
    'in order to': 'to',
    'at the end of the day': 'ultimately',
    'due to the fact that': 'because',
    'for the purpose of': 'to',
    'in the event that': 'if',
    'at this point in time': 'now',
    'all of a sudden': 'suddenly',
    'as a matter of fact': 'in fact',
    'needless to say': '',
    'in spite of the fact that': 'although',
    'has the ability to': 'can',
    'in close proximity to': 'near',
  };

  /// Analyzes text and returns all detected grammar, spelling, punctuation, and style issues.
  List<GrammarIssue> analyze(String text) {
    if (text.isEmpty) return const [];

    final issues = <GrammarIssue>[];
    final lineStarts = _computeLineStarts(text);

    // Compute regions to ignore: frontmatter, fenced code blocks, and inline code
    final ignoredRanges = _computeIgnoredRanges(text);
    bool isIgnored(int start, int end) {
      for (final range in ignoredRanges) {
        if (start < range.end && end > range.start) return true;
      }
      return false;
    }

    // 1. Repeated consecutive duplicate words: e.g. "the the", "in in", "that that"
    final duplicateWordRegex = RegExp(r'\b([A-Za-z]{2,})\s+\1\b', caseSensitive: false);
    for (final match in duplicateWordRegex.allMatches(text)) {
      if (isIgnored(match.start, match.end)) continue;
      final word = match.group(1)!;
      final pos = _getLineAndColumn(lineStarts, match.start);
      issues.add(GrammarIssue(
        id: 'dup_${match.start}',
        offset: match.start,
        length: match.end - match.start,
        line: pos.line,
        column: pos.column,
        type: GrammarIssueType.repeatedWord,
        message: "Repeated word '$word'.",
        matchedText: match.group(0)!,
        replacements: [word],
        severity: 'error',
      ));
    }

    // 2. Double punctuation: e.g. ",,", ";;", accidental ".." (not ellipsis "...")
    final doublePunctRegex = RegExp(r'([,;:])\1+|\.\.(?!\.)');
    for (final match in doublePunctRegex.allMatches(text)) {
      if (isIgnored(match.start, match.end)) continue;
      final raw = match.group(0)!;
      final replacement = raw.startsWith('..') ? '…' : raw[0];
      final pos = _getLineAndColumn(lineStarts, match.start);
      issues.add(GrammarIssue(
        id: 'double_punct_${match.start}',
        offset: match.start,
        length: match.end - match.start,
        line: pos.line,
        column: pos.column,
        type: GrammarIssueType.doublePunctuation,
        message: "Duplicate punctuation '$raw'.",
        matchedText: raw,
        replacements: [replacement],
        severity: 'warning',
      ));
    }

    // 3. Space before punctuation: e.g. "word ," -> "word,"
    final spaceBeforePunctRegex = RegExp(r'(\w+)\s+([,;:\.\?!])');
    for (final match in spaceBeforePunctRegex.allMatches(text)) {
      if (isIgnored(match.start, match.end)) continue;
      final word = match.group(1)!;
      final punct = match.group(2)!;
      final pos = _getLineAndColumn(lineStarts, match.start);
      issues.add(GrammarIssue(
        id: 'space_before_${match.start}',
        offset: match.start,
        length: match.end - match.start,
        line: pos.line,
        column: pos.column,
        type: GrammarIssueType.punctuationSpacing,
        message: "Extra space before punctuation '$punct'.",
        matchedText: match.group(0)!,
        replacements: ['$word$punct'],
        severity: 'warning',
      ));
    }

    // 4. Missing space after comma or semicolon: e.g. "hello,world" -> "hello, world"
    final missingSpaceRegex = RegExp(r'([,;])([A-Za-z])');
    for (final match in missingSpaceRegex.allMatches(text)) {
      if (isIgnored(match.start, match.end)) continue;
      final punct = match.group(1)!;
      final nextChar = match.group(2)!;
      final pos = _getLineAndColumn(lineStarts, match.start);
      issues.add(GrammarIssue(
        id: 'missing_space_${match.start}',
        offset: match.start,
        length: match.end - match.start,
        line: pos.line,
        column: pos.column,
        type: GrammarIssueType.punctuationSpacing,
        message: "Missing space after '$punct'.",
        matchedText: match.group(0)!,
        replacements: ['$punct $nextChar'],
        severity: 'warning',
      ));
    }

    // 5. Capitalization after sentence ending: e.g. "The door closed. it was cold." -> "It"
    final capAfterPeriodRegex = RegExp(r'([\.!\?]["\x27]?\s+)([a-z])');
    for (final match in capAfterPeriodRegex.allMatches(text)) {
      if (isIgnored(match.start, match.end)) continue;
      // Skip if preceded by common abbreviations like e.g., i.e., Mr., Mrs., Dr.
      final prefixStart = (match.start - 6).clamp(0, match.start);
      final prefix = text.substring(prefixStart, match.start).toLowerCase();
      if (prefix.endsWith('mr.') ||
          prefix.endsWith('mrs.') ||
          prefix.endsWith('ms.') ||
          prefix.endsWith('dr.') ||
          prefix.endsWith('e.g.') ||
          prefix.endsWith('i.e.') ||
          prefix.endsWith('vs.') ||
          prefix.endsWith('etc.')) {
        continue;
      }

      final lead = match.group(1)!;
      final letter = match.group(2)!;
      final upper = letter.toUpperCase();
      final pos = _getLineAndColumn(lineStarts, match.start);
      issues.add(GrammarIssue(
        id: 'cap_${match.start}',
        offset: match.start,
        length: match.end - match.start,
        line: pos.line,
        column: pos.column,
        type: GrammarIssueType.capitalization,
        message: "Sentence should begin with a capital letter '$upper'.",
        matchedText: match.group(0)!,
        replacements: ['$lead$upper'],
        severity: 'warning',
      ));
    }

    // 6. Confused homophones
    for (final rule in _homophoneRules) {
      for (final match in rule.pattern.allMatches(text)) {
        if (isIgnored(match.start, match.end)) continue;
        final replacement = rule.replacementBuilder(match);
        final pos = _getLineAndColumn(lineStarts, match.start);
        issues.add(GrammarIssue(
          id: 'homo_${match.start}',
          offset: match.start,
          length: match.end - match.start,
          line: pos.line,
          column: pos.column,
          type: GrammarIssueType.homophone,
          message: rule.message,
          matchedText: match.group(0)!,
          replacements: [replacement],
          severity: 'warning',
        ));
      }
    }

    // 7. Wordy clichés / filler phrases
    _cliches.forEach((cliche, replacement) {
      final regex = RegExp('\\b${RegExp.escape(cliche)}\\b', caseSensitive: false);
      for (final match in regex.allMatches(text)) {
        if (isIgnored(match.start, match.end)) continue;
        final pos = _getLineAndColumn(lineStarts, match.start);
        final replList = replacement.isNotEmpty ? [replacement] : <String>[];
        issues.add(GrammarIssue(
          id: 'cliche_${match.start}',
          offset: match.start,
          length: match.end - match.start,
          line: pos.line,
          column: pos.column,
          type: GrammarIssueType.cliche,
          message: replacement.isNotEmpty
              ? "Wordy phrase '$cliche' can often be simplified to '$replacement'."
              : "Consider removing filler phrase '$cliche'.",
          matchedText: match.group(0)!,
          replacements: replList,
          severity: 'suggestion',
        ));
      }
    });

    // 8. Passive voice detection: e.g. "was written by", "were defeated by"
    final passiveRegex = RegExp(r'\b(is|are|was|were|been|being)\s+([a-z]+ed)\s+by\b', caseSensitive: false);
    for (final match in passiveRegex.allMatches(text)) {
      if (isIgnored(match.start, match.end)) continue;
      final pos = _getLineAndColumn(lineStarts, match.start);
      issues.add(GrammarIssue(
        id: 'passive_${match.start}',
        offset: match.start,
        length: match.end - match.start,
        line: pos.line,
        column: pos.column,
        type: GrammarIssueType.passiveVoice,
        message: "Passive voice phrase '${match.group(0)}'. Consider active voice for stronger prose.",
        matchedText: match.group(0)!,
        replacements: const [],
        severity: 'suggestion',
      ));
    }

    // Sort issues sequentially by text offset
    issues.sort((a, b) => a.offset.compareTo(b.offset));
    return issues;
  }

  /// Replaces the matched issue text with the chosen replacement
  String applyFix(String text, GrammarIssue issue, String replacement) {
    if (issue.offset < 0 || issue.offset + issue.length > text.length) {
      return text;
    }
    return text.replaceRange(issue.offset, issue.offset + issue.length, replacement);
  }

  /// Applies all replacements backwards from end to start to prevent offset shifts
  String applyAllFixes(String text, List<GrammarIssue> issues) {
    final fixable = issues.where((i) => i.replacements.isNotEmpty).toList();
    fixable.sort((a, b) => b.offset.compareTo(a.offset)); // descending order

    var result = text;
    for (final issue in fixable) {
      if (issue.offset >= 0 && issue.offset + issue.length <= result.length) {
        result = result.replaceRange(issue.offset, issue.offset + issue.length, issue.replacements.first);
      }
    }
    return result;
  }

  List<int> _computeLineStarts(String text) {
    final starts = <int>[0];
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '\n') {
        starts.add(i + 1);
      }
    }
    return starts;
  }

  _LineCol _getLineAndColumn(List<int> starts, int offset) {
    var low = 0;
    var high = starts.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (starts[mid] <= offset) {
        if (mid == starts.length - 1 || starts[mid + 1] > offset) {
          return _LineCol(line: mid + 1, column: offset - starts[mid] + 1);
        }
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return const _LineCol(line: 1, column: 1);
  }

  List<_Range> _computeIgnoredRanges(String text) {
    final ranges = <_Range>[];

    // Frontmatter: ^---\n[\s\S]*?\n---
    if (text.startsWith('---')) {
      final end = text.indexOf('\n---', 3);
      if (end != -1) {
        ranges.add(_Range(0, end + 4));
      }
    }

    // Fenced code blocks: ```...```
    final fencedRegex = RegExp(r'```[\s\S]*?```');
    for (final match in fencedRegex.allMatches(text)) {
      ranges.add(_Range(match.start, match.end));
    }

    // Inline code: `...`
    final inlineRegex = RegExp(r'`[^`\n]+`');
    for (final match in inlineRegex.allMatches(text)) {
      ranges.add(_Range(match.start, match.end));
    }

    return ranges;
  }
}

class _HomophoneRule {
  final RegExp pattern;
  final String message;
  final String Function(Match) replacementBuilder;

  _HomophoneRule({
    required this.pattern,
    required this.message,
    required this.replacementBuilder,
  });
}

class _LineCol {
  final int line;
  final int column;
  const _LineCol({required this.line, required this.column});
}

class _Range {
  final int start;
  final int end;
  _Range(this.start, this.end);
}
