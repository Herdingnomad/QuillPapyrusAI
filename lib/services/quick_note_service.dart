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

  /// Opens or creates today's Daily note in `Daily/YYYY-MM-DD.md`
  Future<String?> openOrCreateDailyNote() async {
    try {
      final root = await _ensureWorkspaceRoot();
      final dailyDir = Directory(p.join(root, 'Daily'));
      if (!await dailyDir.exists()) {
        await dailyDir.create(recursive: true);
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = '$dateStr.md';
      final filePath = p.join(dailyDir.path, fileName);

      final file = File(filePath);
      if (!await file.exists()) {
        final content = '''---
title: Daily Note - $dateStr
tags: [daily, journal]
date: $dateStr
---

# Daily Scratchpad — $dateStr

- [ ] 
''';
        await _storage.writeFile(filePath, content);
      }

      await _ref.read(workspaceProvider.notifier).refreshWorkspace();
      await _ref.read(editorProvider.notifier).openFile(filePath, fileName);

      await _widgetService.updateWidgetData(
        title: 'Daily Note ($dateStr)',
        snippet: 'Today\'s active daily scratchpad',
      );

      return filePath;
    } catch (_) {
      return null;
    }
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
