import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/pacing_quota.dart';
import 'package:quill_papyrus_ai/providers/pacing_provider.dart';
import 'package:quill_papyrus_ai/services/document_scanner_service.dart';

void main() {
  group('Folder Goals and Document Scanner Tests', () {
    test('ManuscriptTarget handles manuscript and folder targets correctly', () {
      final defaultTarget = ManuscriptTarget(
        id: 'default',
        targetManuscriptWords: 75000,
        targetDailyWords: 1500,
        updatedAt: DateTime.now(),
      );
      expect(defaultTarget.isFolderTarget, isFalse);
      expect(defaultTarget.targetWords, 75000);
      expect(defaultTarget.progressFraction(15000), 0.2);

      final folderTarget = ManuscriptTarget(
        id: '/workspace/Chapter_1',
        targetManuscriptWords: 4000,
        targetDailyWords: 800,
        updatedAt: DateTime.now(),
      );
      expect(folderTarget.isFolderTarget, isTrue);
      expect(folderTarget.targetWords, 4000);
      expect(folderTarget.progressFraction(2000), 0.5);
      expect(folderTarget.progressFraction(4500), 1.0);
    });

    test('PacingState tracks goals and word counts per folder', () {
      final defaultTarget = ManuscriptTarget(
        targetManuscriptWords: 50000,
        updatedAt: DateTime.now(),
      );

      final ch1Target = ManuscriptTarget(
        id: '/workspace/Chapter_1',
        targetManuscriptWords: 3000,
        updatedAt: DateTime.now(),
      );

      final ch2Target = ManuscriptTarget(
        id: '/workspace/Chapter_2',
        targetManuscriptWords: 5000,
        updatedAt: DateTime.now(),
      );

      final state = PacingState(
        target: defaultTarget,
        folderTargets: {
          '/workspace/Chapter_1': ch1Target,
          '/workspace/Chapter_2': ch2Target,
        },
        folderWordCounts: {
          '/workspace/Chapter_1': 1500,
          '/workspace/Chapter_2': 5000,
        },
        totalManuscriptWords: 6500,
      );

      expect(state.totalManuscriptWords, 6500);
      expect(state.wordsForFolder('/workspace/Chapter_1'), 1500);
      expect(state.wordsForFolder('/workspace/Chapter_2'), 5000);
      expect(state.wordsForFolder('/workspace/NonExistent'), 0);

      expect(state.targetForFolder('/workspace/Chapter_1'), ch1Target);
      expect(state.targetForFolder('/workspace/Chapter_2'), ch2Target);
      expect(state.targetForFolder('/workspace/NonExistent'), isNull);

      expect(state.progressForFolder('/workspace/Chapter_1'), closeTo(0.5, 0.001));
      expect(state.progressForFolder('/workspace/Chapter_2'), closeTo(1.0, 0.001));
      expect(state.progressForFolder('/workspace/NonExistent'), 0.0);
    });

    test('DocumentScannerService is registered in Riverpod and initializes cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final scannerService = container.read(documentScannerServiceProvider);
      expect(scannerService, isNotNull);
    });
  });
}
