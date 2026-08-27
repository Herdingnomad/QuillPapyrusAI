import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/diff_model.dart';
import 'package:quill_papyrus_ai/models/editor_tab.dart';
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
  });
}
