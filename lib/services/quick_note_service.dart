import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/workspace_state.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';
import 'package:quill_papyrus_ai/services/widget_service.dart';

class QuickNoteService {
  final Ref _ref;
  final SafStorageService _storage;
  final WidgetService _widgetService;

  QuickNoteService(this._ref, this._storage, this._widgetService);

  /// Resolves the workspace root path, ensuring default workspace is loaded if not set
  Future<String> _ensureWorkspaceRoot() async {
    var wsState = _ref.read(workspaceProvider);
    if (wsState.rootUri == null || wsState.status == WorkspaceStatus.initial) {
      await _ref.read(workspaceProvider.notifier).loadDefaultWorkspace();
      wsState = _ref.read(workspaceProvider);
    }
    final root = wsState.rootUri ?? await _storage.getDefaultWorkspacePath();
    await _widgetService.updateWorkspaceRoot(root);
    return root;
  }

  /// Creates an auto-timestamped quick note in the `QuickNotes/` folder
  Future<String?> createQuickNote({String? initialText}) async {
    try {
      final root = await _ensureWorkspaceRoot();
      final quickNotesDir = Directory(p.join(root, 'QuickNotes'));
      if (!await quickNotesDir.exists()) {
        await quickNotesDir.create(recursive: true);
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final fileTimestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      
      final fileName = 'Note_$fileTimestamp.md';
      final filePath = p.join(quickNotesDir.path, fileName);

      final frontmatter = '''---
title: Quick Note - $dateStr $timeStr
tags: [quicknote, inbox]
date: $dateStr $timeStr
---

${initialText ?? ''}''';

      await _storage.writeFile(filePath, frontmatter);
      await _ref.read(workspaceProvider.notifier).refreshWorkspace();
      await _ref.read(editorProvider.notifier).openFile(filePath, fileName);

      // Update Android Widget preview
      await _widgetService.updateWidgetData(
        title: 'Quick Note ($timeStr)',
        snippet: initialText?.trim().isNotEmpty == true ? initialText!.trim() : 'Draft created at $timeStr',
      );

      return filePath;
    } catch (_) {
      return null;
    }
  }

  /// Ensures standard Vault directories exist (/Daily-Logs, /Assets/Sketches, etc.)
  Future<Map<String, String>> ensureVaultDirectories() async {
    final root = await _ensureWorkspaceRoot();
    final dirs = {
      'dailyLogs': p.join(root, 'Daily-Logs'),
      'quickNotes': p.join(root, 'QuickNotes'),
      'sketches': p.join(root, 'Assets', 'Sketches'),
      'voiceNotes': p.join(root, 'Assets', 'VoiceNotes'),
      'rawExports': p.join(root, 'Assets', 'Raw-Exports'),
      'inboxDropzone': p.join(root, 'Inbox-Dropzone'),
    };

    for (final dirPath in dirs.values) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }
    }

    return dirs;
  }

  /// Opens or creates today's Daily note in `Daily-Logs/MM-DD-YY.md` (or `Daily/` for backward compat)
  Future<String?> openOrCreateDailyNote() async {
    try {
      final root = await _ensureWorkspaceRoot();
      await ensureVaultDirectories();

      // Check Daily-Logs first, fallback to Daily if user already has an established folder
      String dailyFolder = p.join(root, 'Daily-Logs');
      if (!await Directory(dailyFolder).exists() && await Directory(p.join(root, 'Daily')).exists()) {
        dailyFolder = p.join(root, 'Daily');
      }

      final now = DateTime.now();
      final monthStr = now.month.toString().padLeft(2, '0');
      final dayStr = now.day.toString().padLeft(2, '0');
      final yearShort = (now.year % 100).toString().padLeft(2, '0');
      final isoDate = '${now.year}-$monthStr-$dayStr';
      
      // Look for either MM-DD-YY.md or YYYY-MM-DD.md
      final mmddyyName = '$monthStr-$dayStr-$yearShort.md';
      final isoName = '$isoDate.md';
      
      String targetPath = p.join(dailyFolder, mmddyyName);
      String targetFileName = mmddyyName;

      if (await File(p.join(dailyFolder, isoName)).exists()) {
        targetPath = p.join(dailyFolder, isoName);
        targetFileName = isoName;
      }

      final file = File(targetPath);
      if (!await file.exists()) {
        const monthNames = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        final readableDate = '${monthNames[now.month - 1]} ${now.day}, ${now.year}';
        final initialTime = _formatTime(now);

        final content = '''---
date: $isoDate
sources: [native]
tags: [daily, journal]
---

# Daily Scratchpad — $readableDate

## $initialTime - Native Entry
- [ ] 
''';
        await _storage.writeFile(targetPath, content);
      }

      await _ref.read(workspaceProvider.notifier).refreshWorkspace();
      await _ref.read(editorProvider.notifier).openFile(targetPath, targetFileName);

      await _widgetService.updateWidgetData(
        title: 'Daily Note ($isoDate)',
        snippet: 'Today\'s active daily log',
      );

      return targetPath;
    } catch (_) {
      return null;
    }
  }

  /// Appends an entry block to today's daily log (or creates it if needed)
  Future<String?> appendEntryToDailyNote({
    required String sectionTitle,
    required String content,
    String? sourceTag,
  }) async {
    try {
      final dailyPath = await openOrCreateDailyNote();
      if (dailyPath == null) return null;

      final file = File(dailyPath);
      if (!await file.exists()) return null;

      var currentText = await file.readAsString();

      // Update sources frontmatter if sourceTag provided
      if (sourceTag != null && sourceTag.isNotEmpty) {
        if (!currentText.contains(RegExp('sources:.*\b$sourceTag\b', caseSensitive: false))) {
          currentText = currentText.replaceFirstMapped(
            RegExp(r'(sources:\s*\[(.*?)\])', multiLine: true),
            (m) {
              final existing = m.group(2)?.trim() ?? '';
              final updated = existing.isEmpty ? sourceTag : '$existing, $sourceTag';
              return 'sources: [$updated]';
            },
          );
        }
      }

      final now = DateTime.now();
      final timeStr = _formatTime(now);
      final blockHeader = '## $timeStr - $sectionTitle';

      final separator = currentText.endsWith('\n\n')
          ? ''
          : currentText.endsWith('\n')
              ? '\n'
              : '\n\n';

      final newBlock = '''---
$blockHeader
$content
''';

      final updatedContent = '$currentText$separator$newBlock';
      await _storage.writeFile(dailyPath, updatedContent);
      await _ref.read(editorProvider.notifier).reloadCurrentTab();
      await _ref.read(workspaceProvider.notifier).refreshWorkspace();

      return dailyPath;
    } catch (_) {
      return null;
    }
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }

  /// Dispatches actions received from AppWidget or Android App Shortcuts
  Future<void> handleActionUri(String uriStr) async {
    final uri = Uri.tryParse(uriStr);
    if (uri == null) return;

    if (uri.scheme == 'quillpapyrus') {
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();

      if (host == 'quick-note' || path == '/quick-note') {
        await createQuickNote();
      } else if (host == 'daily-note' || path == '/daily-note') {
        await openOrCreateDailyNote();
      } else if (host == 'voice-note' || path == '/voice-note') {
        await openOrCreateDailyNote();
      }
    }
  }
}

final quickNoteServiceProvider = Provider<QuickNoteService>((ref) {
  return QuickNoteService(
    ref,
    ref.read(safStorageServiceProvider),
    ref.read(widgetServiceProvider),
  );
});
