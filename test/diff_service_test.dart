import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/diff_model.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';

void main() {
  group('DiffService', () {
    test('detects word additions and deletions', () {
      const original = 'The quick brown fox jumps.';
      const proposed = 'The fast brown fox leaps.';

      final chunks = DiffService.computeWordDiff(original, proposed);
      expect(chunks.any((c) => c.type == DiffType.deletion && c.text.contains('quick')), isTrue);
      expect(chunks.any((c) => c.type == DiffType.addition && c.text.contains('fast')), isTrue);
      expect(chunks.any((c) => c.type == DiffType.equal && c.text.contains('brown fox')), isTrue);
    });

    test('creates full proposal', () {
      const fullText = 'Hello World\nThis is a sample sentence.\nGoodbye!';
      const originalSub = 'This is a sample sentence.';
      const proposedSub = 'This is an improved sentence.';

      final start = fullText.indexOf(originalSub);
      final end = start + originalSub.length;

      final proposal = DiffService.createProposal(
        originalFullText: fullText,
        proposedReplacement: proposedSub,
        selectionStart: start,
        selectionEnd: end,
        actionTitle: 'Improve Sentence',
      );

      expect(proposal.originalText, originalSub);
      expect(proposal.proposedText, proposedSub);
      expect(proposal.actionTitle, 'Improve Sentence');
      expect(proposal.chunks.isNotEmpty, isTrue);
    });

    test('strips <end_of_turn> and model turn tokens cleanly', () {
      const rawWithTurn = 'Here is the improved text.<end_of_turn>';
      final clean = DiffService.cleanSpecialTokens(rawWithTurn);
      expect(clean, 'Here is the improved text.');
      expect(clean.contains('<end_of_turn>'), isFalse);

      final proposal = DiffService.createProposal(
        originalFullText: 'Old text.',
        proposedReplacement: 'New text.<end_of_turn>',
        selectionStart: 0,
        selectionEnd: 9,
      );
      expect(proposal.proposedText, 'New text.');
      expect(proposal.proposedText.contains('<end_of_turn>'), isFalse);
    });
  });
}
