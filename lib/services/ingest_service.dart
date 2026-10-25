import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/ai_service.dart';
import 'package:quill_papyrus_ai/services/image_preprocess_service.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';

class IngestResult {
  final String sourcePath;
  final String archivedPath;
  final List<String> croppedArtworkPaths;
  final String transcribedText;
  final String? targetDailyLogPath;

  IngestResult({
    required this.sourcePath,
    required this.archivedPath,
    required this.croppedArtworkPaths,
    required this.transcribedText,
    this.targetDailyLogPath,
  });
}

class IngestService {
  final Ref _ref;
  final QuickNoteService _quickNoteService;
  final AiService _aiService;

  IngestService(this._ref, this._quickNoteService, this._aiService);

  /// Ingests an incoming journal page image or PDF export into the vault
  Future<IngestResult?> ingestFile({
    required String filePath,
    String? sourceMedium, // 'Kindle Scribe', 'Paper Journal', 'OneNote'
    Function(String stage)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      onProgress?.call('Ensuring vault folders...');
      final dirs = await _quickNoteService.ensureVaultDirectories();
      final sketchesDir = dirs['sketches']!;
      final rawExportsDir = dirs['rawExports']!;

      // 1. Archive original raw file
      onProgress?.call('Archiving raw export...');
      final originalFileName = p.basename(filePath);
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final archivedFileName = '${timestamp}_$originalFileName';
      final archivedPath = p.join(rawExportsDir, archivedFileName);
      await file.copy(archivedPath);

      // 2. Save full uncropped image into /Assets/Sketches/
      final sketchFileName = '${timestamp}_$originalFileName';
      final sketchPath = p.join(sketchesDir, sketchFileName);
      await file.copy(sketchPath);

      String workingImagePath = sketchPath;
      final ext = p.extension(filePath).toLowerCase();

      if (sourceMedium == 'Paper Journal' || ext == '.jpg' || ext == '.jpeg') {
        onProgress?.call('Enhancing contrast for paper/ink...');
        final enhancedPath = p.join(sketchesDir, '${timestamp}_enhanced$ext');
        final enhanced = await ImagePreprocessService.enhancePaperContrast(
          inputImagePath: workingImagePath,
          outputImagePath: enhancedPath,
        );
        if (enhanced != null) {
          workingImagePath = enhanced;
        }
      }

      // 3. AI Vision analysis (Gemma 4 E2B) for full-page transcription
      onProgress?.call('Gemma 4 E2B: Transcribing notes...');
      final analysis = await _aiService.analyzeJournalPageWithGemmaVision(
        File(workingImagePath),
      );

      // 4. Preserve full image intact (no cropping)
      final List<String> imagePaths = [workingImagePath];

      // 5. Build Markdown entry block
      onProgress?.call('Appending to Daily Log...');
      final buffer = StringBuffer();

      // Render the full intact image
      final imgName = p.basename(workingImagePath);
      final relPath = '../Assets/Sketches/$imgName';
      buffer.writeln('![Journal Capture]($relPath)\n');

      if (analysis.transcribedText.trim().isNotEmpty) {
        buffer.writeln('### Transcribed Notes');
        buffer.writeln(analysis.transcribedText.trim());
      }

      final mediumTitle = sourceMedium != null && sourceMedium.isNotEmpty
          ? '$sourceMedium Import'
          : 'Journal Import';
      final sourceTag = sourceMedium?.toLowerCase().contains('scribe') == true
          ? 'scribe'
          : sourceMedium?.toLowerCase().contains('onenote') == true
              ? 'onenote'
              : 'paper';

      final dailyPath = await _quickNoteService.appendEntryToDailyNote(
        sectionTitle: mediumTitle,
        content: buffer.toString().trim(),
        sourceTag: sourceTag,
      );

      await _ref.read(workspaceProvider.notifier).refreshWorkspace();
      onProgress?.call('Ingestion complete!');

      return IngestResult(
        sourcePath: filePath,
        archivedPath: archivedPath,
        croppedArtworkPaths: imagePaths,
        transcribedText: analysis.transcribedText,
        targetDailyLogPath: dailyPath,
      );
    } catch (_) {
      return null;
    }
  }

  /// Scans /Inbox-Dropzone for pending files and ingests them
  Future<List<IngestResult>> scanAndIngestDropzone({
    Function(String stage)? onProgress,
  }) async {
    final results = <IngestResult>[];
    try {
      final dirs = await _quickNoteService.ensureVaultDirectories();
      final dropzone = Directory(dirs['inboxDropzone']!);

      if (!await dropzone.exists()) return results;

      final files = dropzone.listSync();
      for (final entity in files) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.webp' || ext == '.pdf') {
            onProgress?.call('Ingesting ${p.basename(entity.path)}...');
            final res = await ingestFile(
              filePath: entity.path,
              sourceMedium: ext == '.pdf' ? 'Kindle Scribe' : 'Paper Journal',
              onProgress: onProgress,
            );
            if (res != null) {
              results.add(res);
              // Clean up original from dropzone after archiving and ingestion
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
    return results;
  }
}

final ingestServiceProvider = Provider<IngestService>((ref) {
  return IngestService(
    ref,
    ref.read(quickNoteServiceProvider),
    ref.read(aiServiceProvider),
  );
});
