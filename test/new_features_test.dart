import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/app_theme_data.dart';
import 'package:quill_papyrus_ai/models/compiler_config.dart';
import 'package:quill_papyrus_ai/models/manuscript_metadata.dart';
import 'package:quill_papyrus_ai/models/pacing_quota.dart';
import 'package:quill_papyrus_ai/models/search_models.dart';
import 'package:quill_papyrus_ai/services/compiler_service.dart';
import 'package:quill_papyrus_ai/services/grammar_service.dart';
import 'package:quill_papyrus_ai/services/search_service.dart';
import 'package:quill_papyrus_ai/services/sync_service.dart';
import 'package:quill_papyrus_ai/services/typography_service.dart';

void main() {
  group('TypographyService Tests', () {
    final typography = TypographyService.instance;

    test('Converts straight quotes to smart curly quotes', () {
      final input = '"Call me Ishmael," wrote Melville. \'Yes,\' he agreed.';
      final result = typography.applySmartTypography(input);
      expect(result.contains('“Call me Ishmael,”'), isTrue);
      expect(result.contains('‘Yes,’'), isTrue);
    });

    test('Converts double and triple hyphens to em-dash', () {
      final input = 'He paused--then spoke---or did he?';
      final result = typography.applySmartTypography(input);
      expect(result, 'He paused—then spoke—or did he?');
    });

    test('Converts three dots to proper typographical ellipsis', () {
      final input = 'Wait... what happened?';
      final result = typography.applySmartTypography(input);
      expect(result, 'Wait… what happened?');
    });

    test('Preserves code blocks and inline code from smart punctuation', () {
      final input = 'Here is code: `var x = "hello"--"world";` and done.';
      final result = typography.applySmartTypography(input);
      expect(result.contains('`var x = "hello"--"world";`'), isTrue);
    });
  });

  group('SearchService Tests', () {
    final search = SearchService.instance;

    test('Finds exact matches with case sensitivity', () {
      const text = 'The quick brown Fox jumps over the lazy fox.';

      final matchesCaseSensitive = search.findMatches(
        text,
        const SearchOptions(query: 'Fox', matchCase: true),
      );
      expect(matchesCaseSensitive.length, 1);
      expect(matchesCaseSensitive.first.startOffset, 16);

      final matchesInsensitive = search.findMatches(
        text,
        const SearchOptions(query: 'fox', matchCase: false),
      );
      expect(matchesInsensitive.length, 2);
    });

    test('Whole word match respects word boundaries', () {
      const text = 'cat catch category concatenate cat';
      final matches = search.findMatches(
        text,
        const SearchOptions(query: 'cat', wholeWord: true),
      );
      expect(matches.length, 2);
      expect(matches[0].startOffset, 0);
      expect(matches[1].startOffset, 31);
    });

    test('Regex search finds patterns correctly', () {
      const text = 'Chapter 1: The Beginning. Chapter 22: The End.';
      final matches = search.findMatches(
        text,
        const SearchOptions(query: r'Chapter \d+:', useRegex: true),
      );
      expect(matches.length, 2);
      expect(matches[0].matchedText, 'Chapter 1:');
      expect(matches[1].matchedText, 'Chapter 22:');
    });

    test('Replaces single match and replaces all matches correctly', () {
      const text = 'apple banana apple cherry apple';
      final options = const SearchOptions(query: 'apple', replaceWith: 'orange');

      final firstMatch = search.findMatches(text, options).first;
      final replacedFirst = search.replaceMatch(
        content: text,
        match: firstMatch,
        replacement: 'orange',
      );
      expect(replacedFirst, 'orange banana apple cherry apple');

      final replacedAll = search.replaceAll(content: text, options: options);
      expect(replacedAll, 'orange banana orange cherry orange');
    });
  });

  group('CompilerService Tests', () {
    final compiler = CompilerService.instance;

    test('Chapter numbering Roman Numerals formatting', () {
      expect(CompilerService.romanNumerals[0], 'I');
      expect(CompilerService.romanNumerals[3], 'IV');
      expect(CompilerService.romanNumerals[8], 'IX');
      expect(CompilerService.romanNumerals[13], 'XIV');
      expect(CompilerService.romanNumerals[28], 'XXIX');
    });

    test('Chapter numbering Words formatting', () {
      expect(CompilerService.wordNumbers[0], 'One');
      expect(CompilerService.wordNumbers[11], 'Twelve');
      expect(CompilerService.wordNumbers[20], 'Twenty-One');
    });

    test('Sanitizes Markdown stripping front-matter, comments, and todo markers', () {
      final doc = '''---
title: Scene One
pov: Ronald
status: draft
---
The sun rose over the castle. <!-- internal plot note -->
- [ ] TODO: polish dialogue
He stepped outside.''';

      final config = const CompilerConfig(
        bookTitle: 'Chronicles of Arcana',
        authorName: 'A. Writer',
        outputFormat: CompilerOutputFormat.cleanMarkdown,
        numberingStyle: ChapterNumberingStyle.words,
        stripFrontmatter: true,
        stripComments: true,
        stripTodoMarkers: true,
      );

      final sanitized = compiler.sanitizeMarkdown(doc, config);

      expect(sanitized.contains('<!-- internal plot note -->'), isFalse);
      expect(sanitized.contains('pov: Ronald'), isFalse);
      expect(sanitized.contains('TODO: polish dialogue'), isFalse);
      expect(sanitized.contains('The sun rose over the castle.'), isTrue);
      expect(sanitized.contains('He stepped outside.'), isTrue);
    });
  });

  group('ManuscriptMetadata Tests', () {
    test('Extracts metadata from YAML frontmatter and modifies it', () {
      final doc = '''---
title: The Silent Tower
pov: Sarah
timeline: Day 4, Dawn
status: draft
target_words: 2500
synopsis: Sarah investigates the locked archive in the western parapet.
---

The heavy iron key turned with a groaning click.
''';

      final meta = ManuscriptMetadata.extractFromMarkdown(doc, fallbackTitle: 'Tower.md');
      expect(meta.title, 'The Silent Tower');
      expect(meta.pov, 'Sarah');
      expect(meta.timeline, 'Day 4, Dawn');
      expect(meta.status, SceneDraftStatus.draft);
      expect(meta.targetWords, 2500);
      expect(meta.synopsis, 'Sarah investigates the locked archive in the western parapet.');

      // Modify and reapply to markdown
      final updated = meta.copyWith(
        status: SceneDraftStatus.revised,
        pov: 'Sarah & Marcus',
      );

      final applied = updated.applyToMarkdown(doc);
      expect(applied.contains('pov: Sarah & Marcus'), isTrue);
      expect(applied.contains('status: Revised'), isTrue);
      expect(applied.contains('The heavy iron key turned with a groaning click.'), isTrue);
    });
  });

  group('SyncService Tests', () {
    final sync = SyncService.instance;

    test('Computes consistent SHA-256 hash', () {
      const content = 'The quick brown fox jumps over the lazy dog';
      final hash1 = sync.computeHash(content);
      final hash2 = sync.computeHash(content);
      expect(hash1, hash2);
      expect(hash1.length, 64);
    });

    test('Performs atomic file write safely without file loss', () async {
      final tempDir = Directory.systemTemp.createTempSync('quill_sync_test_');
      final targetPath = '${tempDir.path}/atomic_scene.md';

      await sync.writeAtomic(targetPath, 'Initial draft text');
      expect(File(targetPath).existsSync(), isTrue);
      expect(await File(targetPath).readAsString(), 'Initial draft text');

      // Update atomically
      await sync.writeAtomic(targetPath, 'Overwritten updated chapter content');
      expect(await File(targetPath).readAsString(), 'Overwritten updated chapter content');

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Reconciles folders safely copying newer and missing files', () async {
      final srcDir = Directory.systemTemp.createTempSync('quill_reconcile_src_');
      final dstDir = Directory.systemTemp.createTempSync('quill_reconcile_dst_');

      final file1 = File('${srcDir.path}/note1.md');
      await file1.writeAsString('Note 1 in source');

      final file2Src = File('${srcDir.path}/note2.md');
      await file2Src.writeAsString('Newer note 2 in source');

      final file2Dst = File('${dstDir.path}/note2.md');
      await file2Dst.writeAsString('Older note 2 in destination');
      await file2Dst.setLastModified(DateTime.now().subtract(const Duration(hours: 2)));

      final count = await sync.reconcileFolders(sourcePath: srcDir.path, targetPath: dstDir.path);
      expect(count, 2);
      expect(File('${dstDir.path}/note1.md').existsSync(), isTrue);
      expect(await File('${dstDir.path}/note2.md').readAsString(), 'Newer note 2 in source');

      try {
        srcDir.deleteSync(recursive: true);
        dstDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });

  group('PacingQuota Model Tests', () {
    test('Calculates daily and manuscript pacing fractions correctly', () {
      final target = ManuscriptTarget(
        targetDailyWords: 1000,
        targetManuscriptWords: 50000,
        updatedAt: DateTime.now(),
      );

      expect(target.dailyProgressFraction(500), 0.5);
      expect(target.dailyProgressFraction(1500), 1.0);
      expect(target.progressFraction(25000), 0.5);
      expect(target.estimatedReadingHours(60000), 4.0);
    });
  });

  group('Theme Cloud Sync Tests', () {
    test('Serializes and deserializes theme cloud sync payload', () {
      final customTheme = AppThemeData.gruvboxDark.copyWith(
        id: 'custom_emerald_forest',
        name: 'Emerald Forest',
        isCustom: true,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'version': 1,
        'updatedAt': now,
        'platform': 'android',
        'activeThemeId': customTheme.id,
        'customThemes': [customTheme.toMap()],
      };

      final jsonStr = jsonEncode(payload);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['version'], 1);
      expect(decoded['updatedAt'], now);
      expect(decoded['activeThemeId'], 'custom_emerald_forest');

      final rawCustom = decoded['customThemes'] as List;
      expect(rawCustom.length, 1);
      final restoredTheme = AppThemeData.fromMap(rawCustom.first as Map<String, dynamic>);
      expect(restoredTheme.id, 'custom_emerald_forest');
      expect(restoredTheme.name, 'Emerald Forest');
      expect(restoredTheme.isCustom, isTrue);
    });

    test('Writes and reads .quill/theme_settings.json atomically', () async {
      final tempDir = Directory.systemTemp.createTempSync('quill_theme_sync_');
      final syncService = SyncService.instance;
      final themeFilePath = p.join(tempDir.path, '.quill', 'theme_settings.json');

      final testData = {
        'version': 1,
        'updatedAt': 1761168000000,
        'platform': 'windows',
        'activeThemeId': 'catppuccin_mocha',
        'customThemes': [],
      };

      await syncService.writeAtomic(themeFilePath, jsonEncode(testData));

      final targetFile = File(themeFilePath);
      expect(targetFile.existsSync(), isTrue);

      final readContent = await targetFile.readAsString();
      final parsed = jsonDecode(readContent) as Map<String, dynamic>;
      expect(parsed['activeThemeId'], 'catppuccin_mocha');
      expect(parsed['updatedAt'], 1761168000000);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Theme sync conflict timestamp reconciliation simulation', () {
      final localTimestamp = 1000;
      final cloudTimestampNewer = 2000;
      final cloudTimestampOlder = 500;

      // Cloud newer -> should import cloud
      final shouldImportCloud = cloudTimestampNewer > localTimestamp;
      expect(shouldImportCloud, isTrue);

      // Local newer -> should push local to cloud
      final shouldPushLocal = localTimestamp > cloudTimestampOlder;
      expect(shouldPushLocal, isTrue);
    });
  });

  group('GrammarService Tests', () {
    final grammar = GrammarService.instance;

    test('Detects and fixes duplicate consecutive words', () {
      const text = 'He went to the the market yesterday.';
      final issues = grammar.analyze(text);

      expect(issues.any((i) => i.type == GrammarIssueType.repeatedWord), isTrue);
      final dupIssue = issues.firstWhere((i) => i.type == GrammarIssueType.repeatedWord);
      expect(dupIssue.matchedText, 'the the');
      expect(dupIssue.replacements, ['the']);

      final fixed = grammar.applyFix(text, dupIssue, dupIssue.replacements.first);
      expect(fixed, 'He went to the market yesterday.');
    });

    test('Detects missing space after punctuation and space before punctuation', () {
      const text = 'Hello,world and pause ,here.';
      final issues = grammar.analyze(text);

      expect(issues.any((i) => i.message.contains("Missing space after ','")), isTrue);
      expect(issues.any((i) => i.message.contains("Extra space before punctuation ','")), isTrue);

      final fixedAll = grammar.applyAllFixes(text, issues);
      expect(fixedAll.contains('Hello, world'), isTrue);
      expect(fixedAll.contains('pause, here.'), isTrue);
    });

    test('Detects double punctuation and normalizes it', () {
      const text = 'Wait,, did you see that..';
      final issues = grammar.analyze(text);

      expect(issues.any((i) => i.type == GrammarIssueType.doublePunctuation), isTrue);
      final fixed = grammar.applyAllFixes(text, issues);
      expect(fixed.contains('Wait,'), isTrue);
      expect(fixed.contains('that…'), isTrue);
    });

    test('Flags lowercase sentence start and capitalizes it', () {
      const text = 'The door clicked shut. it was dark inside.';
      final issues = grammar.analyze(text);

      expect(issues.any((i) => i.type == GrammarIssueType.capitalization), isTrue);
      final capIssue = issues.firstWhere((i) => i.type == GrammarIssueType.capitalization);
      final fixed = grammar.applyFix(text, capIssue, capIssue.replacements.first);
      expect(fixed, 'The door clicked shut. It was dark inside.');
    });

    test('Detects confused homophones (their/there, your/you\'re, its/it\'s)', () {
      const text1 = 'They parked there car in the driveway.';
      final issues1 = grammar.analyze(text1);
      expect(issues1.any((i) => i.type == GrammarIssueType.homophone), isTrue);
      expect(grammar.applyAllFixes(text1, issues1), 'They parked their car in the driveway.');

      const text2 = 'I think your welcome to come.';
      final issues2 = grammar.analyze(text2);
      expect(grammar.applyAllFixes(text2, issues2), "I think you're welcome to come.");

      const text3 = 'The cat chased it\'s tail.';
      final issues3 = grammar.analyze(text3);
      expect(grammar.applyAllFixes(text3, issues3), 'The cat chased its tail.');
    });

    test('Suggests simplifications for wordy clichés', () {
      const text = 'She studied hard in order to pass the exam.';
      final issues = grammar.analyze(text);

      expect(issues.any((i) => i.type == GrammarIssueType.cliche), isTrue);
      final fixed = grammar.applyAllFixes(text, issues);
      expect(fixed, 'She studied hard to pass the exam.');
    });

    test('Ignores code blocks and YAML frontmatter from false positives', () {
      const doc = '''---
title: My Document
tags: [one,two]
---
Here is code: `var x = 1,y = 2;`
And fenced:
```
the the = 1;
```
Real text: the the cat.
''';
      final issues = grammar.analyze(doc);
      // Only the real text "the the cat" should be flagged, not code or frontmatter
      expect(issues.length, 1);
      expect(issues.first.matchedText, 'the the');
    });
  });
}
