import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';

/// Function signature for generating a compact 2–3 line scene beat summary for one file.
typedef SceneSummarizer = Future<String> Function(String fileName, String plainContent);

/// Builds and caches per-file semantic scene beat sheets in SQLite (keyed by SHA-256 content hash),
/// enabling cross-chapter semantic similarity and continuity comparison across 25+ files in 1 pass.
class SceneDigestService {
  final DatabaseService _db;

  SceneDigestService({DatabaseService? db}) : _db = db ?? DatabaseService.instance;

  /// Computes a SHA-256 content hash for cache invalidation.
  static String hashContent(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// Deterministic local fallback beat extractor when no on-device LLM is loaded.
  static String fallbackBeatSummary(String fileName, String plainContent) {
    final lines = plainContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '(Empty file)';

    final headings = lines
        .where((l) => l.startsWith('#'))
        .map((l) => l.replaceFirst(RegExp(r'^#+\s*'), ''))
        .take(3)
        .toList();
    final proseLines = lines.where((l) => !l.startsWith('#')).toList();
    final opening = proseLines.isNotEmpty ? proseLines.first : '';
    final middle = proseLines.length > 4 ? proseLines[proseLines.length ~/ 2] : '';

    String clip(String s, int max) => s.length > max ? '${s.substring(0, max)}...' : s;
    final parts = <String>[];
    if (headings.isNotEmpty) parts.add('Sections: ${headings.join(" / ")}');
    if (opening.isNotEmpty) parts.add('Opens: ${clip(opening, 95)}');
    if (middle.isNotEmpty && middle != opening) parts.add('Mid: ${clip(middle, 95)}');
    return parts.join(' | ');
  }

  /// Builds (or retrieves from SQLite cache) a compact scene beat sheet for every file in [files].
  /// Returns a formatted multi-chapter digest ready for a single cross-chapter comparison pass.
  Future<({String report, int cachedCount, int generatedCount})> buildFolderSceneDigest({
    required List<File> files,
    required String workspaceRoot,
    required String folderName,
    SceneSummarizer? summarizer,
  }) async {
    int cachedCount = 0;
    int generatedCount = 0;
    final buf = StringBuffer();
    buf.writeln('Scene Beat Digest for "$folderName" (${files.length} files):');

    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final plain = FrontMatterService.stripFrontMatter(raw).trim();
        final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');
        if (plain.isEmpty) {
          buf.writeln('- $rel: (empty)');
          continue;
        }

        final hash = hashContent(plain);
        final cached = await _db.getSceneDigest(file.path);
        String digest;
        if (cached != null &&
            cached['content_hash'] == hash &&
            (cached['digest']?.toString().trim().isNotEmpty ?? false)) {
          digest = cached['digest'].toString().trim();
          cachedCount++;
        } else {
          if (summarizer != null) {
            try {
              final aiDigest = (await summarizer(rel, plain)).trim();
              digest = aiDigest.isNotEmpty
                  ? aiDigest
                  : fallbackBeatSummary(rel, plain);
            } catch (_) {
              digest = fallbackBeatSummary(rel, plain);
            }
          } else {
            digest = fallbackBeatSummary(rel, plain);
          }

          // Keep each file's digest compact (~260 chars max) so 30+ files fit easily
          if (digest.length > 260) {
            digest = '${digest.substring(0, 260)}...';
          }
          digest = digest.replaceAll(RegExp(r'\s+'), ' ').trim();

          await _db.upsertSceneDigest(
            fileUri: file.path,
            parentFolder: folderName,
            fileName: p.basename(file.path),
            contentHash: hash,
            digest: digest,
          );
          generatedCount++;
        }

        buf.writeln('- $rel: $digest');
      } catch (_) {}
    }

    return (
      report: buf.toString().trim(),
      cachedCount: cachedCount,
      generatedCount: generatedCount,
    );
  }
}
