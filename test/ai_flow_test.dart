import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/diff_model.dart';
import 'package:quill_papyrus_ai/models/editor_tab.dart';
import 'package:quill_papyrus_ai/providers/diff_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/ai_service.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';

void main() {
  group('AI Flow and Inline Diff Tests', () {
    test('AiService generates quick edits with prompt templates', () async {
      final aiService = AiService();
      const sampleText = 'the sentence has no punctuation';

      final fixed = await aiService.generateQuickEdit(action: 'grammar', selectedText: sampleText);
      expect(fixed.isNotEmpty, isTrue);

      final summary = await aiService.generateQuickEdit(action: 'summarize', selectedText: sampleText);
      expect(summary.contains('-'), isTrue);

      final actionItems = await aiService.generateQuickEdit(action: 'action_items', selectedText: sampleText);
      expect(actionItems.contains('- [ ]'), isTrue);

      final table = await aiService.generateQuickEdit(action: 'table', selectedText: sampleText);
      expect(table.contains('|'), isTrue);

      final outline = await aiService.generateQuickEdit(action: 'outline', selectedText: sampleText);
      expect(outline.contains('#'), isTrue);
    });

    test('Inline diff computes and replaces text correctly in EditorTab', () {
      var tab = const EditorTab(
        uri: '/test/note.md',
        fileName: 'note.md',
        content: 'The old content here.',
        savedContent: 'The old content here.',
      );

      final proposal = DiffService.createProposal(
        originalFullText: tab.content,
        proposedReplacement: 'The new improved content here.',
        selectionStart: 0,
        selectionEnd: tab.content.length,
        actionTitle: 'Grammar Fix',
      );

      expect(proposal.chunks.any((c) => c.type == DiffType.addition), isTrue);

      final appliedContent = tab.content.replaceRange(
        proposal.selectionStart,
        proposal.selectionEnd,
        proposal.proposedText,
      );

      tab = tab.copyWith(content: appliedContent);
      expect(tab.content, 'The new improved content here.');
      expect(tab.isDirty, isTrue);
    });

    test('AiService loadNativeModel and unloadModel handle non-Android/missing files gracefully', () async {
      final aiService = AiService();
      // On desktop/test environment or missing file, should return false gracefully without crashing
      final loaded = await aiService.loadNativeModel('/non_existent/model.gguf');
      expect(loaded, isFalse);
      expect(aiService.isModelLoaded, isFalse);

      // unloadModel should complete safely
      await aiService.unloadModel();
      expect(aiService.isModelLoaded, isFalse);
    });

    test('AiService generates intelligent frontmatter from markdown content', () async {
      final aiService = AiService();
      const content = '''# Flutter Local AI Testing
A productive session experimenting with on-device LLMs.

Date: 2026-09-06
Tags: flutter, ai, mobile
Topics: development, testing
''';

      final frontmatter = await aiService.generateFrontMatterForDocument(
        documentContent: content,
        fallbackTitle: 'test_note.md',
        workspaceTags: ['ai', 'mobile', 'flutter'],
        workspaceTopics: ['development', 'testing'],
      );

      expect(frontmatter.title, contains('Flutter Local AI Testing'));
      expect(frontmatter.tags, contains('ai'));
      expect(frontmatter.tags, contains('technology'));
      expect(frontmatter.topics, contains('development'));
    });

    test('AiService generateStream provides offline tokens gracefully when no native model is loaded', () async {
      final aiService = AiService();
      expect(aiService.isModelLoaded, isFalse);

      final tokens = <String>[];
      await for (final token in aiService.generateStream(prompt: 'Hello AI assistant', systemPrompt: 'You are helpful.')) {
        tokens.add(token);
      }

      expect(tokens, isNotEmpty);
      final fullResponse = tokens.join();
      expect(fullResponse.isNotEmpty, isTrue);
    });

    test('DiffService createProposal handles arbitrary and boundary selections safely', () {
      const doc = 'Hello world, this is a test document.';
      // Selection covering full document
      final fullProposal = DiffService.createProposal(
        originalFullText: doc,
        proposedReplacement: 'Replaced whole doc',
        selectionStart: 0,
        selectionEnd: doc.length,
        actionTitle: 'Replace All',
      );
      expect(fullProposal.selectionStart, 0);
      expect(fullProposal.selectionEnd, doc.length);

      // Selection covering substring
      final subProposal = DiffService.createProposal(
        originalFullText: doc,
        proposedReplacement: 'universe',
        selectionStart: 6,
        selectionEnd: 11,
        actionTitle: 'Replace Word',
      );
      expect(subProposal.selectionStart, 6);
      expect(subProposal.selectionEnd, 11);
    });

    test('DiffService cleanSpecialTokens removes end_of_turn and special tokens', () {
      const dirty = 'Here is the response.<end_of_turn>\n';
      final cleaned = DiffService.cleanSpecialTokens(dirty);
      expect(cleaned, 'Here is the response.');
      expect(cleaned.contains('<end_of_turn>'), isFalse);
    });

    test('DiffNotifier insertProposedBelow inserts generation below selection without replacing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final editorNotifier = container.read(editorProvider.notifier);
      await editorNotifier.openFile('/test/sample.md', 'sample.md');
      editorNotifier.updateContent('Line 1\nLine 2\nLine 3');

      final diffNotifier = container.read(diffProvider.notifier);
      final proposal = DiffService.createProposal(
        originalFullText: 'Line 1\nLine 2\nLine 3',
        proposedReplacement: 'Inserted Note',
        selectionStart: 0,
        selectionEnd: 6, // "Line 1"
        actionTitle: 'Test Insert',
      );
      diffNotifier.showProposal(proposal);
      expect(container.read(diffProvider).hasActiveDiff, isTrue);

      diffNotifier.insertProposedBelow();
      expect(container.read(diffProvider).hasActiveDiff, isFalse);

      final updatedContent = container.read(editorProvider).activeTab!.content;
      // Original text preserved, inserted text appended below
      expect(updatedContent.contains('Line 1'), isTrue);
      expect(updatedContent.contains('Inserted Note'), isTrue);
      expect(updatedContent.contains('Line 2'), isTrue);
    });

    test('All 8 quick action prompts generate appropriate content', () async {
      final aiService = AiService();
      const text = 'Important system update: please verify the database connection and backup schedules.';

      final actions = ['grammar', 'expand', 'summarize', 'action_items', 'explain', 'table', 'outline', 'concise'];
      for (final action in actions) {
        final result = await aiService.generateQuickEdit(action: action, selectedText: text);
        expect(result.isNotEmpty, isTrue, reason: 'Action $action should produce non-empty output');
        expect(result.contains('<end_of_turn>'), isFalse, reason: 'Action $action must not contain end_of_turn');
      }
    });
  });
}
