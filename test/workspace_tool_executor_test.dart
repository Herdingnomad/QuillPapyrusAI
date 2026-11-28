import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/services/workspace_tool_executor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WorkspaceToolExecutor (All 7 Local Tools)', () {
    late Directory tempRoot;
    late Directory farmFolder;
    late WorkspaceToolExecutor executor;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('quill_tools_test_');
      farmFolder = Directory(p.join(tempRoot.path, 'Farm-Log'));
      await farmFolder.create(recursive: true);

      await File(p.join(farmFolder.path, 'pasture.md')).writeAsString('''---
title: Pasture Rotation
tags: [farm, grazing]
---

Moved herd to Paddock 3 after morning rain.
''');
      await File(p.join(farmFolder.path, 'health.md')).writeAsString('''# Herd Health
Checked hooves and minerals #livestock #farm
''');
      executor = WorkspaceToolExecutor();
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('extractToolCall parses valid <tool_call> JSON and strips blocks', () {
      const raw = '<tool_call>{"name": "read_file", "arguments": {"path": "pasture.md"}}</tool_call>';
      final call = WorkspaceToolExecutor.extractToolCall(raw);
      expect(call, isNotNull);
      expect(call!.name, equals('read_file'));
      expect(call.arguments['path'], equals('pasture.md'));
      expect(WorkspaceToolExecutor.stripToolCallBlocks(raw), isEmpty);
    });

    test('1. list_files lists markdown files in folder', () async {
      final res = await executor.execute(
        call: const ParsedToolCall(name: 'list_files', arguments: {'folder': 'Farm-Log'}, rawMatch: ''),
        workspaceRoot: tempRoot.path,
      );
      expect(res.didModifyFiles, isFalse);
      expect(res.result.toLowerCase(), contains('farm-log/pasture.md'));
      expect(res.result.toLowerCase(), contains('farm-log/health.md'));
    });

    test('2. search_notes finds matching notes across folder', () async {
      final res = await executor.execute(
        call: const ParsedToolCall(name: 'search_notes', arguments: {'query': 'Paddock 3'}, rawMatch: ''),
        workspaceRoot: tempRoot.path,
        scopedFolderPath: farmFolder.path,
      );
      expect(res.result, contains('pasture.md'));
      expect(res.result, contains('Paddock 3'));
    });

    test('3. read_file returns full file contents', () async {
      final res = await executor.execute(
        call: const ParsedToolCall(name: 'read_file', arguments: {'path': 'pasture.md'}, rawMatch: ''),
        workspaceRoot: tempRoot.path,
        scopedFolderPath: farmFolder.path,
      );
      expect(res.result, contains('Moved herd to Paddock 3'));
    });

    test('4. find_by_tag finds both frontmatter and inline #tags', () async {
      final res = await executor.execute(
        call: const ParsedToolCall(name: 'find_by_tag', arguments: {'tag': '#farm'}, rawMatch: ''),
        workspaceRoot: tempRoot.path,
      );
      expect(res.result, contains('Farm-Log/pasture.md'));
      expect(res.result, contains('Farm-Log/health.md'));
    });

    test('5. get_current_datetime returns current local date and time', () async {
      final res = await executor.execute(
        call: const ParsedToolCall(name: 'get_current_datetime', arguments: {}, rawMatch: ''),
        workspaceRoot: tempRoot.path,
      );
      expect(res.result, contains('Date: '));
      expect(res.result, contains('Local Time: '));
    });

    test('6. create_note creates new file, refuses overwrite, and blocks path traversal', () async {
      final created = await executor.execute(
        call: const ParsedToolCall(
          name: 'create_note',
          arguments: {'path': 'daily-summary', 'content': '# Summary\nAll good.'},
          rawMatch: '',
        ),
        workspaceRoot: tempRoot.path,
        scopedFolderPath: farmFolder.path,
      );
      expect(created.didModifyFiles, isTrue);
      expect(File(p.join(farmFolder.path, 'daily-summary.md')).existsSync(), isTrue);

      // Refuses overwrite
      final dup = await executor.execute(
        call: const ParsedToolCall(
          name: 'create_note',
          arguments: {'path': 'daily-summary.md', 'content': 'Overwrite attempt'},
          rawMatch: '',
        ),
        workspaceRoot: tempRoot.path,
        scopedFolderPath: farmFolder.path,
      );
      expect(dup.didModifyFiles, isFalse);
      expect(dup.result, contains('already exists'));

      // Blocks path traversal outside workspace
      final escape = await executor.execute(
        call: const ParsedToolCall(
          name: 'create_note',
          arguments: {'path': '../../outside.md', 'content': 'nope'},
          rawMatch: '',
        ),
        workspaceRoot: tempRoot.path,
      );
      expect(escape.didModifyFiles, isFalse);
      expect(escape.result, contains('outside workspace'));
    });

    test('7. append_to_note safely appends without overwriting existing content', () async {
      final appended = await executor.execute(
        call: const ParsedToolCall(
          name: 'append_to_note',
          arguments: {'path': 'health.md', 'content': '- [ ] Order mineral blocks'},
          rawMatch: '',
        ),
        workspaceRoot: tempRoot.path,
        scopedFolderPath: farmFolder.path,
      );
      expect(appended.didModifyFiles, isTrue);
      final updated = await File(p.join(farmFolder.path, 'health.md')).readAsString();
      expect(updated, contains('Checked hooves and minerals'));
      expect(updated, contains('- [ ] Order mineral blocks'));
    });

    test('8. analyze_folder scans all files for overview and duplicate passages', () async {
      const sharedScene =
          'Mark woke early to the steady hum of the land, stretched by the porch, and conjured a fresh cup of dark coffee from the ley lines before checking the north pasture fence.';
      await File(p.join(farmFolder.path, 'ch1.md')).writeAsString('# Chapter 1\n\n$sharedScene\n');
      await File(p.join(farmFolder.path, 'ch2.md')).writeAsString('# Chapter 2\n\n$sharedScene\n');

      final overview = await executor.execute(
        call: const ParsedToolCall(
          name: 'analyze_folder',
          arguments: {'folder': 'Farm-Log', 'mode': 'overview'},
          rawMatch: '',
        ),
        workspaceRoot: tempRoot.path,
      );
      expect(overview.result, contains('4 files'));
      expect(overview.result.toLowerCase(), contains('ch1.md'));
      expect(overview.result.toLowerCase(), contains('ch2.md'));

      final dups = await executor.execute(
        call: const ParsedToolCall(
          name: 'analyze_folder',
          arguments: {'folder': 'Farm-Log', 'mode': 'duplicates'},
          rawMatch: '',
        ),
        workspaceRoot: tempRoot.path,
      );
      expect(dups.result.toLowerCase(), contains('ch1.md'));
      expect(dups.result.toLowerCase(), contains('ch2.md'));
      expect(dups.result, contains('100% overlap'));

      // Mode 'scenes' builds cached semantic beat sheets using the provided summarizer
      int summarizerCalls = 0;
      final scenes1 = await executor.execute(
        call: const ParsedToolCall(
          name: 'analyze_folder',
          arguments: {'folder': 'Farm-Log', 'mode': 'scenes'},
          rawMatch: '',
        ),
        workspaceRoot: tempRoot.path,
        sceneSummarizer: (fileName, content) async {
          summarizerCalls++;
          return 'Beat summary for $fileName';
        },
      );
      expect(scenes1.result, contains('Scene Beat Digest'));
      expect(scenes1.result, contains('Beat summary for'));
      expect(summarizerCalls, greaterThanOrEqualTo(4));

      // Second call on unchanged files should hit SQLite cache (0 new summarizer calls)
      final beforeSecond = summarizerCalls;
      final scenes2 = await executor.execute(
        call: const ParsedToolCall(
          name: 'analyze_folder',
          arguments: {'folder': 'Farm-Log', 'mode': 'scenes'},
          rawMatch: '',
        ),
        workspaceRoot: tempRoot.path,
        sceneSummarizer: (fileName, content) async {
          summarizerCalls++;
          return 'Should not be called';
        },
      );
      expect(summarizerCalls, equals(beforeSecond));
      expect(scenes2.result, contains('0 freshly summarized'));
    });
  });
}
