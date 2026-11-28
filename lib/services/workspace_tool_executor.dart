import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/services/indexer_service.dart';
import 'package:quill_papyrus_ai/services/scene_digest_service.dart';

/// Parsed tool invocation emitted by the LLM inside `<tool_call>{...}</tool_call>`.
class ParsedToolCall {
  final String name;
  final Map<String, dynamic> arguments;
  final String rawMatch;

  const ParsedToolCall({
    required this.name,
    required this.arguments,
    required this.rawMatch,
  });
}

/// Executes the 7 local, air-gapped workspace tools on behalf of the on-device AI:
/// 1. `list_files`
/// 2. `search_notes`
/// 3. `read_file`
/// 4. `find_by_tag`
/// 5. `get_current_datetime`
/// 6. `create_note` (non-destructive: refuses to overwrite existing files)
/// 7. `append_to_note` (non-destructive: appends to existing files)
class WorkspaceToolExecutor {
  final IndexerService _indexer = IndexerService();
  final SceneDigestService _sceneDigestService = SceneDigestService();

  /// Concise tool protocol injected into the system prompt when Workspace Access is enabled.
  static String buildToolInstructions({String? scopedFolderName}) {
    final scopeHint = (scopedFolderName != null && scopedFolderName.isNotEmpty)
        ? 'Active folder scope: "$scopedFolderName".'
        : 'Active scope: entire workspace.';
    return '''You have local workspace tools to inspect, search, read, and safely create/append notes. $scopeHint
When you need information from files or want to create/append a note, output ONLY a tool call block in this exact format:
<tool_call>{"name": "TOOL_NAME", "arguments": {...}}</tool_call>

Available tools:
1. list_files: {"folder": "optional subfolder name"} — Lists markdown files in the folder/workspace.
2. search_notes: {"query": "keywords", "folder": "optional subfolder"} — Searches all notes for matching text.
3. read_file: {"path": "relative path or filename.md"} — Reads the full contents of one specific note.
4. find_by_tag: {"tag": "tag_without_hash"} — Finds notes matching a #tag or frontmatter tag/topic.
5. get_current_datetime: {} — Returns today's exact local date, day of week, and time.
6. create_note: {"path": "folder/note.md", "content": "markdown text"} — Creates a NEW note (never overwrites).
7. append_to_note: {"path": "relative path or filename.md", "content": "markdown text"} — Appends text to an existing note.
8. analyze_folder: {"folder": "optional subfolder", "mode": "scenes|duplicates|overview"} — Scans EVERY file in a folder at once!
   - mode="scenes": Builds/reads cached AI scene beat summaries for ALL files in the folder so you can find semantically similar or repeated scenes/events (even when worded differently) across every chapter!
   - mode="duplicates": Detects exact or heavily word-overlapping passages across all files.
   - mode="overview": Returns word counts and headings for all files.

Rules:
- For requests asking about similar scenes, repeated events, continuity, or comparing ALL files in a folder, ALWAYS call analyze_folder with mode="scenes" first (never read 20+ files one by one).
- Output ONLY the <tool_call>...</tool_call> block when calling a tool (no extra commentary before it).
- After receiving a tool result, give a clear, complete final answer to the user.''';
  }

  /// Extracts the first valid `<tool_call>{...}</tool_call>` block from model output.
  static ParsedToolCall? extractToolCall(String text) {
    final match = RegExp(
      r'<tool_call>\s*(\{[\s\S]*?\})\s*</tool_call>',
      multiLine: true,
    ).firstMatch(text);
    if (match == null) return null;

    final jsonStr = match.group(1)!.trim();
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        final name = decoded['name']?.toString().trim() ?? '';
        final rawArgs = decoded['arguments'];
        final args = rawArgs is Map
            ? Map<String, dynamic>.from(rawArgs)
            : <String, dynamic>{};
        if (name.isNotEmpty) {
          return ParsedToolCall(
            name: name,
            arguments: args,
            rawMatch: match.group(0)!,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Removes any `<tool_call>...</tool_call>` blocks from text shown to the user.
  static String stripToolCallBlocks(String text) {
    return text
        .replaceAll(RegExp(r'<tool_call>[\s\S]*?</tool_call>', multiLine: true), '')
        .trim();
  }

  /// Executes a parsed tool call strictly within [workspaceRoot] (and optional [scopedFolderPath]).
  /// Returns `(resultText, didModifyFiles)`.
  Future<({String result, bool didModifyFiles})> execute({
    required ParsedToolCall call,
    String? workspaceRoot,
    String? scopedFolderPath,
    SceneSummarizer? sceneSummarizer,
  }) async {
    switch (call.name) {
      case 'get_current_datetime':
        return (result: _getCurrentDateTime(), didModifyFiles: false);

      case 'list_files':
        final folderArg = call.arguments['folder']?.toString().trim();
        final res = await _listFiles(
          workspaceRoot: workspaceRoot,
          scopedFolderPath: scopedFolderPath,
          folderArg: folderArg,
        );
        return (result: res, didModifyFiles: false);

      case 'search_notes':
        final query = call.arguments['query']?.toString().trim() ?? '';
        final folderArg = call.arguments['folder']?.toString().trim();
        final res = await _searchNotes(
          query: query,
          workspaceRoot: workspaceRoot,
          scopedFolderPath: scopedFolderPath,
          folderArg: folderArg,
        );
        return (result: res, didModifyFiles: false);

      case 'read_file':
        final pathArg = call.arguments['path']?.toString().trim() ?? '';
        final res = await _readFile(
          pathArg: pathArg,
          workspaceRoot: workspaceRoot,
          scopedFolderPath: scopedFolderPath,
        );
        return (result: res, didModifyFiles: false);

      case 'find_by_tag':
        final tagArg = call.arguments['tag']?.toString().trim() ?? '';
        final res = await _findByTag(
          tagArg: tagArg,
          workspaceRoot: workspaceRoot,
          scopedFolderPath: scopedFolderPath,
        );
        return (result: res, didModifyFiles: false);

      case 'create_note':
        final pathArg = call.arguments['path']?.toString().trim() ?? '';
        final content = call.arguments['content']?.toString() ?? '';
        return await _createNote(
          pathArg: pathArg,
          content: content,
          workspaceRoot: workspaceRoot,
          scopedFolderPath: scopedFolderPath,
        );

      case 'append_to_note':
        final pathArg = call.arguments['path']?.toString().trim() ?? '';
        final content = call.arguments['content']?.toString() ?? '';
        return await _appendToNote(
          pathArg: pathArg,
          content: content,
          workspaceRoot: workspaceRoot,
          scopedFolderPath: scopedFolderPath,
        );

      case 'analyze_folder':
        final folderArg = call.arguments['folder']?.toString().trim();
        final mode = (call.arguments['mode']?.toString().trim().toLowerCase() ?? 'overview');
        final res = await _analyzeFolder(
          workspaceRoot: workspaceRoot,
          scopedFolderPath: scopedFolderPath,
          folderArg: folderArg,
          mode: mode,
          sceneSummarizer: sceneSummarizer,
        );
        return (result: res, didModifyFiles: false);

      default:
        return (
          result: 'Error: Unknown tool "${call.name}".',
          didModifyFiles: false,
        );
    }
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dateStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return 'Date: $dateStr (${weekdays[now.weekday - 1]}), Local Time: $timeStr';
  }

  Directory? _resolveSearchRoot({
    String? workspaceRoot,
    String? scopedFolderPath,
    String? folderArg,
  }) {
    if (workspaceRoot == null || workspaceRoot.isEmpty) return null;
    final rootDir = Directory(workspaceRoot);
    if (!rootDir.existsSync()) return null;

    if (folderArg != null && folderArg.isNotEmpty) {
      final candidate = _safeJoin(workspaceRoot, folderArg);
      if (candidate != null && Directory(candidate).existsSync()) {
        return Directory(candidate);
      }
      // Also try matching a subfolder by basename
      final found = _findSubdirectoryByName(rootDir, folderArg);
      if (found != null) return found;
    }

    if (scopedFolderPath != null &&
        scopedFolderPath.isNotEmpty &&
        Directory(scopedFolderPath).existsSync()) {
      return Directory(scopedFolderPath);
    }

    return rootDir;
  }

  Directory? _findSubdirectoryByName(Directory root, String folderName) {
    final targetLower = folderName.toLowerCase();
    try {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          final base = p.basename(entity.path);
          if (base.startsWith('.') || base.toLowerCase() == 'models') continue;
          if (base.toLowerCase() == targetLower) return entity;
        }
      }
    } catch (_) {}
    return null;
  }

  List<File> _collectMarkdownFiles(Directory dir) {
    final files = <File>[];
    try {
      void walk(Directory current) {
        for (final entity in current.listSync(followLinks: false)) {
          final name = p.basename(entity.path);
          final lower = name.toLowerCase();
          if (name.startsWith('.') || lower == 'models') continue;
          if (entity is Directory) {
            walk(entity);
          } else if (entity is File &&
              (lower.endsWith('.md') ||
                  lower.endsWith('.markdown') ||
                  lower.endsWith('.txt'))) {
            files.add(entity);
          }
        }
      }

      walk(dir);
    } catch (_) {}
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return files;
  }

  Future<String> _listFiles({
    String? workspaceRoot,
    String? scopedFolderPath,
    String? folderArg,
  }) async {
    final baseDir = _resolveSearchRoot(
      workspaceRoot: workspaceRoot,
      scopedFolderPath: scopedFolderPath,
      folderArg: folderArg,
    );
    if (baseDir == null || workspaceRoot == null) {
      return 'No workspace folder is currently open.';
    }

    final files = _collectMarkdownFiles(baseDir);
    if (files.isEmpty) {
      return 'No markdown or text files found in ${p.basename(baseDir.path)}.';
    }

    final buf = StringBuffer();
    buf.writeln('Found ${files.length} file(s):');
    for (final f in files.take(200)) {
      final rel = p.relative(f.path, from: workspaceRoot).replaceAll(r'\', '/');
      buf.writeln('- $rel');
    }
    if (files.length > 200) {
      buf.writeln('...and ${files.length - 200} more files.');
    }
    return buf.toString().trim();
  }

  Future<String> _searchNotes({
    required String query,
    String? workspaceRoot,
    String? scopedFolderPath,
    String? folderArg,
  }) async {
    if (query.isEmpty) return 'Error: query parameter is required.';
    if (workspaceRoot == null || workspaceRoot.isEmpty) {
      return 'No workspace folder is currently open.';
    }

    final baseDir = _resolveSearchRoot(
      workspaceRoot: workspaceRoot,
      scopedFolderPath: scopedFolderPath,
      folderArg: folderArg,
    );
    if (baseDir == null) return 'Folder not found.';

    // 1. Try SQLite FTS5 index first
    final matches = <String>[];
    final seenFiles = <String>{};
    try {
      final parentFilter = baseDir.path == workspaceRoot
          ? null
          : p.basename(baseDir.path);
      final cleanQuery = query.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
      if (cleanQuery.isNotEmpty) {
        final indexed = await _indexer.search(cleanQuery, parentFolder: parentFilter);
        for (final item in indexed.take(10)) {
          final rel = item.fileUri.startsWith(workspaceRoot)
              ? p.relative(item.fileUri, from: workspaceRoot).replaceAll(r'\', '/')
              : item.fileName;
          seenFiles.add(rel.toLowerCase());
          final snippet = item.snippet.length > 350
              ? '${item.snippet.substring(0, 350)}...'
              : item.snippet;
          matches.add('[$rel — ${item.headingContext}]\n$snippet');
        }
      }
    } catch (_) {}

    // 2. Fallback / supplement with direct scan so newly created or unindexed files are always found
    if (matches.length < 8) {
      final terms = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 2)
          .toList();
      final files = _collectMarkdownFiles(baseDir);
      for (final file in files) {
        if (matches.length >= 10) break;
        final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');
        if (seenFiles.contains(rel.toLowerCase())) continue;
        try {
          final content = await file.readAsString();
          final lowerContent = content.toLowerCase();
          final lowerName = rel.toLowerCase();
          final hit = terms.isEmpty
              ? lowerContent.contains(query.toLowerCase())
              : terms.any((t) => lowerContent.contains(t) || lowerName.contains(t));
          if (hit) {
            seenFiles.add(rel.toLowerCase());
            final idx = terms.isNotEmpty
                ? lowerContent.indexOf(terms.firstWhere((t) => lowerContent.contains(t), orElse: () => ''))
                : lowerContent.indexOf(query.toLowerCase());
            final start = idx > 80 ? idx - 80 : 0;
            final end = (start + 360).clamp(0, content.length);
            final snippet = content.substring(start, end).trim();
            matches.add('[$rel]\n$snippet');
          }
        } catch (_) {}
      }
    }

    if (matches.isEmpty) {
      return 'No notes matched "$query".';
    }
    return 'Search results for "$query" (${matches.length}):\n\n${matches.join('\n\n')}';
  }

  Future<String> _readFile({
    required String pathArg,
    String? workspaceRoot,
    String? scopedFolderPath,
  }) async {
    if (pathArg.isEmpty) return 'Error: path parameter is required.';
    if (workspaceRoot == null || workspaceRoot.isEmpty) {
      return 'No workspace folder is currently open.';
    }

    final file = _resolveExistingFile(
      pathArg: pathArg,
      workspaceRoot: workspaceRoot,
      scopedFolderPath: scopedFolderPath,
    );
    if (file == null) {
      return 'File not found: "$pathArg". Call list_files to see exact file paths.';
    }

    try {
      final content = await file.readAsString();
      final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');
      const maxChars = 3200;
      if (content.length > maxChars) {
        return '=== $rel (showing first $maxChars of ${content.length} chars) ===\n'
            '${content.substring(0, maxChars)}\n...[truncated to fit context window]';
      }
      return '=== $rel ===\n$content';
    } catch (e) {
      return 'Error reading "$pathArg": $e';
    }
  }

  Future<String> _findByTag({
    required String tagArg,
    String? workspaceRoot,
    String? scopedFolderPath,
  }) async {
    final cleanTag = tagArg.replaceFirst(RegExp(r'^#'), '').trim().toLowerCase();
    if (cleanTag.isEmpty) return 'Error: tag parameter is required.';
    final baseDir = _resolveSearchRoot(
      workspaceRoot: workspaceRoot,
      scopedFolderPath: scopedFolderPath,
    );
    if (baseDir == null || workspaceRoot == null) {
      return 'No workspace folder is currently open.';
    }

    final files = _collectMarkdownFiles(baseDir);
    final results = <String>[];
    final inlineRegex = RegExp(r'(^|\s)#' + RegExp.escape(cleanTag) + r'\b', caseSensitive: false);

    for (final file in files) {
      if (results.length >= 25) break;
      try {
        final content = await file.readAsString();
        final fm = FrontMatterService.parse(content);
        final fmTags = [
          ...?fm?.tags.map((t) => t.toLowerCase()),
          ...?fm?.topics.map((t) => t.toLowerCase()),
        ];
        final hasTag = fmTags.contains(cleanTag) || inlineRegex.hasMatch(content);
        if (hasTag) {
          final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');
          final title = fm?.title != null && fm!.title!.isNotEmpty ? ' (${fm.title})' : '';
          results.add('- $rel$title');
        }
      } catch (_) {}
    }

    if (results.isEmpty) {
      return 'No notes found with tag "#$cleanTag".';
    }
    return 'Notes tagged #$cleanTag (${results.length}):\n${results.join('\n')}';
  }

  Future<({String result, bool didModifyFiles})> _createNote({
    required String pathArg,
    required String content,
    String? workspaceRoot,
    String? scopedFolderPath,
  }) async {
    if (pathArg.isEmpty) {
      return (result: 'Error: path parameter is required.', didModifyFiles: false);
    }
    if (workspaceRoot == null || workspaceRoot.isEmpty) {
      return (result: 'No workspace folder is currently open.', didModifyFiles: false);
    }

    var normalizedRel = pathArg.replaceAll(r'\', '/').replaceFirst(RegExp(r'^/+'), '');
    if (!normalizedRel.toLowerCase().endsWith('.md') &&
        !normalizedRel.toLowerCase().endsWith('.txt')) {
      normalizedRel = '$normalizedRel.md';
    }

    // If a scoped folder is active and user gave a bare filename, create inside scoped folder
    final baseDir = (!normalizedRel.contains('/') &&
            scopedFolderPath != null &&
            scopedFolderPath.isNotEmpty)
        ? scopedFolderPath
        : workspaceRoot;

    final fullPath = _safeJoin(baseDir, normalizedRel, confineTo: workspaceRoot);
    if (fullPath == null) {
      return (result: 'Error: Invalid path outside workspace.', didModifyFiles: false);
    }

    final file = File(fullPath);
    if (await file.exists()) {
      final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');
      return (
        result: 'Error: "$rel" already exists. Use append_to_note to add to it without overwriting.',
        didModifyFiles: false,
      );
    }

    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');
      try {
        final parentFolder = p.basename(file.parent.path);
        await _indexer.indexFile(file.path, p.basename(file.path), parentFolder, content);
      } catch (_) {}
      return (result: 'Created new note: $rel (${content.length} chars).', didModifyFiles: true);
    } catch (e) {
      return (result: 'Error creating note: $e', didModifyFiles: false);
    }
  }

  Future<({String result, bool didModifyFiles})> _appendToNote({
    required String pathArg,
    required String content,
    String? workspaceRoot,
    String? scopedFolderPath,
  }) async {
    if (pathArg.isEmpty || content.trim().isEmpty) {
      return (
        result: 'Error: path and non-empty content parameters are required.',
        didModifyFiles: false,
      );
    }
    if (workspaceRoot == null || workspaceRoot.isEmpty) {
      return (result: 'No workspace folder is currently open.', didModifyFiles: false);
    }

    final file = _resolveExistingFile(
      pathArg: pathArg,
      workspaceRoot: workspaceRoot,
      scopedFolderPath: scopedFolderPath,
    );
    if (file == null) {
      return (
        result: 'Error: File "$pathArg" not found. Use create_note to create a new file.',
        didModifyFiles: false,
      );
    }

    try {
      final existing = await file.readAsString();
      final separator = existing.isEmpty
          ? ''
          : (existing.endsWith('\n\n') ? '' : (existing.endsWith('\n') ? '\n' : '\n\n'));
      final updated = '$existing$separator${content.trim()}\n';
      await file.writeAsString(updated);
      final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');
      try {
        final parentFolder = p.basename(file.parent.path);
        await _indexer.indexFile(file.path, p.basename(file.path), parentFolder, updated);
      } catch (_) {}
      return (result: 'Appended to $rel successfully.', didModifyFiles: true);
    } catch (e) {
      return (result: 'Error appending to note: $e', didModifyFiles: false);
    }
  }

  File? _resolveExistingFile({
    required String pathArg,
    required String workspaceRoot,
    String? scopedFolderPath,
  }) {
    final cleaned = pathArg.replaceAll(r'\', '/').replaceFirst(RegExp(r'^/+'), '');

    // 1. Direct relative path from scoped folder or workspace root
    final candidates = <String?>[
      if (scopedFolderPath != null && scopedFolderPath.isNotEmpty)
        _safeJoin(scopedFolderPath, cleaned, confineTo: workspaceRoot),
      _safeJoin(workspaceRoot, cleaned, confineTo: workspaceRoot),
      if (!cleaned.toLowerCase().endsWith('.md'))
        _safeJoin(workspaceRoot, '$cleaned.md', confineTo: workspaceRoot),
    ];
    for (final c in candidates) {
      if (c != null && File(c).existsSync()) {
        return File(c);
      }
    }

    // 2. Basename match inside scoped folder, then workspace root
    final targetLower = p.basename(cleaned).toLowerCase();
    final targetWithMd = targetLower.endsWith('.md') ? targetLower : '$targetLower.md';
    final searchDirs = [
      if (scopedFolderPath != null && scopedFolderPath.isNotEmpty && Directory(scopedFolderPath).existsSync())
        Directory(scopedFolderPath),
      Directory(workspaceRoot),
    ];
    for (final dir in searchDirs) {
      for (final f in _collectMarkdownFiles(dir)) {
        final base = p.basename(f.path).toLowerCase();
        if (base == targetLower || base == targetWithMd) {
          return f;
        }
      }
    }
    return null;
  }

  /// Scans ALL markdown files in a folder at once (pure Dart, zero KV-cache overhead)
  /// to produce either a complete folder overview or a cross-file duplicate scene/passage report.
  Future<String> _analyzeFolder({
    String? workspaceRoot,
    String? scopedFolderPath,
    String? folderArg,
    required String mode,
    SceneSummarizer? sceneSummarizer,
  }) async {
    final baseDir = _resolveSearchRoot(
      workspaceRoot: workspaceRoot,
      scopedFolderPath: scopedFolderPath,
      folderArg: folderArg,
    );
    if (baseDir == null || workspaceRoot == null) {
      return 'No workspace folder is currently open.';
    }

    final files = _collectMarkdownFiles(baseDir);
    if (files.isEmpty) {
      return 'No markdown files found in ${p.basename(baseDir.path)}.';
    }

    if (mode == 'scenes') {
      final digest = await _sceneDigestService.buildFolderSceneDigest(
        files: files,
        workspaceRoot: workspaceRoot,
        folderName: p.basename(baseDir.path),
        summarizer: sceneSummarizer,
      );
      return '${digest.report}\n\n[Scene digest: ${digest.cachedCount} cached, ${digest.generatedCount} freshly summarized. Compare the scenes above to identify any similar or repeated events across different files.]';
    }

    if (mode == 'duplicates') {
      return _findDuplicatePassages(files, workspaceRoot, p.basename(baseDir.path));
    }

    // Default: compact overview of every file in the folder
    final buf = StringBuffer();
    buf.writeln('Folder "${p.basename(baseDir.path)}" overview (${files.length} files):');
    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final body = FrontMatterService.stripFrontMatter(raw).trim();
        final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');
        final words = body.isEmpty ? 0 : body.split(RegExp(r'\s+')).length;
        final headings = RegExp(r'^#{1,3}\s+(.+)$', multiLine: true)
            .allMatches(body)
            .map((m) => m.group(1)!.trim())
            .take(3)
            .join(' | ');
        final firstLine = body
            .split('\n')
            .map((l) => l.trim())
            .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
        final preview = firstLine.length > 90 ? '${firstLine.substring(0, 90)}...' : firstLine;
        buf.writeln(
          '- $rel ($words words)${headings.isNotEmpty ? " [$headings]" : ""}${preview.isNotEmpty ? " — $preview" : ""}',
        );
      } catch (_) {}
    }
    return buf.toString().trim();
  }

  /// Detects duplicate or heavily overlapping passages/scenes across all files in [files]
  /// using 4-word shingle Jaccard similarity on paragraph blocks.
  Future<String> _findDuplicatePassages(
    List<File> files,
    String workspaceRoot,
    String folderName,
  ) async {
    final List<({String relPath, String text, Set<String> shingles})> blocks = [];

    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final body = FrontMatterService.stripFrontMatter(raw).trim();
        if (body.isEmpty) continue;
        final rel = p.relative(file.path, from: workspaceRoot).replaceAll(r'\', '/');

        // Split into paragraph/scene chunks of meaningful length (>= 20 words)
        final paragraphs = body
            .split(RegExp(r'\r?\n\s*\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        for (final para in paragraphs) {
          final words = para
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
              .split(RegExp(r'\s+'))
              .where((w) => w.length >= 2)
              .toList();
          if (words.length < 18) continue;

          final shingles = <String>{};
          for (int i = 0; i <= words.length - 4; i++) {
            shingles.add('${words[i]} ${words[i + 1]} ${words[i + 2]} ${words[i + 3]}');
          }
          if (shingles.isNotEmpty) {
            blocks.add((relPath: rel, text: para, shingles: shingles));
          }
        }
      } catch (_) {}
    }

    final List<({String fileA, String fileB, double score, String excerpt})> hits = [];
    final seenPairs = <String>{};

    for (int i = 0; i < blocks.length; i++) {
      for (int j = i + 1; j < blocks.length; j++) {
        final a = blocks[i];
        final b = blocks[j];
        if (a.relPath == b.relPath) continue;

        final inter = a.shingles.intersection(b.shingles).length;
        if (inter < 4) continue;
        final union = a.shingles.length + b.shingles.length - inter;
        if (union <= 0) continue;
        final jaccard = inter / union;

        if (jaccard >= 0.25) {
          final pairKey = '${a.relPath}|${b.relPath}|${a.text.substring(0, a.text.length < 40 ? a.text.length : 40)}';
          if (seenPairs.add(pairKey)) {
            final excerpt = a.text.length > 140 ? '${a.text.substring(0, 140)}...' : a.text;
            hits.add((fileA: a.relPath, fileB: b.relPath, score: jaccard, excerpt: excerpt));
          }
        }
      }
    }

    hits.sort((a, b) => b.score.compareTo(a.score));

    if (hits.isEmpty) {
      return 'Scanned all ${files.length} files in "$folderName" (${blocks.length} paragraphs). No duplicate or heavily overlapping passages were detected across different files.';
    }

    final buf = StringBuffer();
    buf.writeln(
      'Scanned all ${files.length} files in "$folderName". Found ${hits.length} overlapping/duplicate passage(s):',
    );
    for (final h in hits.take(15)) {
      final pct = (h.score * 100).round();
      buf.writeln('- ${h.fileA} <-> ${h.fileB} ($pct% overlap): "${h.excerpt}"');
    }
    if (hits.length > 15) {
      buf.writeln('...and ${hits.length - 15} more matches.');
    }
    return buf.toString().trim();
  }

  /// Safely joins [relative] onto [base], ensuring the canonical result stays inside [confineTo ?? base].
  String? _safeJoin(String base, String relative, {String? confineTo}) {
    try {
      final boundary = p.canonicalize(confineTo ?? base);
      final resolved = p.canonicalize(p.join(base, relative));
      if (resolved == boundary || p.isWithin(boundary, resolved)) {
        return resolved;
      }
    } catch (_) {}
    return null;
  }
}
