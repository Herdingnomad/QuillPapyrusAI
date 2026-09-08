import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';

class SafStorageService {
  static const MethodChannel _channel = MethodChannel('com.herdingnomadstudios.quill_papyrus_ai/storage_permissions');

  /// Checks if Android has All Files Access (MANAGE_EXTERNAL_STORAGE)
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('hasStoragePermission');
      return granted ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Requests Android All Files Access settings page
  Future<void> requestStoragePermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestStoragePermission');
    } catch (_) {}
  }

  /// Normalizes paths returned by Android SAF/FilePickers (e.g. content://, primary:...)
  String normalizePath(String rawPath) {
    var path = rawPath.trim();

    // Check for percent encoding
    try {
      path = Uri.decodeFull(path);
    } catch (_) {}

    // Handle primary storage prefix
    if (path.contains('primary:')) {
      final sub = path.substring(path.indexOf('primary:') + 'primary:'.length);
      final cleanSub = sub.replaceAll(RegExp(r'^/+'), '');
      return '/storage/emulated/0/$cleanSub';
    }

    if (path.contains('tree/primary:')) {
      final sub = path.substring(path.indexOf('tree/primary:') + 'tree/primary:'.length);
      final cleanSub = sub.replaceAll(RegExp(r'^/+'), '');
      return '/storage/emulated/0/$cleanSub';
    }

    // Handle raw content URIs pointing to document trees
    if (path.startsWith('content://')) {
      // Extract encoded relative path if available
      final match = RegExp(r'document/([^/?]+)').firstMatch(path);
      if (match != null) {
        var docId = Uri.decodeComponent(match.group(1)!);
        if (docId.startsWith('primary:')) {
          docId = docId.substring('primary:'.length);
          return '/storage/emulated/0/$docId';
        }
      }
    }

    return path;
  }

  /// Prompts the user with a system folder picker to select any folder on internal or external storage.
  /// If cancelled or on error, falls back to the persistent default internal storage workspace.
  Future<String?> pickDirectory({bool forcePicker = false}) async {
    // Check permission first on Android
    if (Platform.isAndroid) {
      final hasPerm = await hasStoragePermission();
      if (!hasPerm) {
        await requestStoragePermission();
      }
    }

    try {
      final selectedPath = await FilePickerPlatform.instance.getDirectoryPath(
        dialogTitle: 'Select Workspace Folder',
      );

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final normalized = normalizePath(selectedPath);
        final dir = Directory(normalized);
        if (!await dir.exists()) {
          try {
            await dir.create(recursive: true);
          } catch (_) {}
        }
        return normalized;
      } else if (forcePicker) {
        return null;
      }
    } catch (_) {
      // Fallback if picker fails or unavailable (e.g. headless tests)
      return await getDefaultWorkspacePath();
    }

    // Default persistent internal storage folder
    return await getDefaultWorkspacePath();
  }

  /// Gets or creates the default persistent workspace in internal storage
  Future<String> getDefaultWorkspacePath() async {
    Directory targetDir;

    if (Platform.isAndroid) {
      // Prefer standard accessible Documents folder on Android device
      final androidDocs = Directory('/storage/emulated/0/Documents/QuillPapyrus');
      try {
        if (!await androidDocs.exists()) {
          await androidDocs.create(recursive: true);
        }
        targetDir = androidDocs;
      } catch (_) {
        // Fallback to app documents
        final appDoc = await getApplicationDocumentsDirectory();
        targetDir = Directory(p.join(appDoc.path, 'QuillPapyrus'));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      }
    } else {
      try {
        final appDoc = await getApplicationDocumentsDirectory();
        targetDir = Directory(p.join(appDoc.path, 'QuillPapyrus'));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      } catch (_) {
        targetDir = Directory.systemTemp.createTempSync('quill_papyrus_ws_');
      }
    }

    // Populate initial welcome note if empty
    try {
      final entries = await targetDir.list().toList();
      if (entries.isEmpty) {
        await _createInitialNotes(targetDir.path);
      }
    } catch (_) {}

    return targetDir.path;
  }

  Future<void> _createInitialNotes(String rootPath) async {
    try {
      final welcomeFile = File(p.join(rootPath, 'Welcome.md'));
      await welcomeFile.writeAsString('''---
title: Welcome to Quill & Papyrus AI
tags: [getting-started, notes]
date: 2026-08-26
---

# Welcome to Quill & Papyrus AI :sparkles:

Quill & Papyrus AI is an on-device, offline-first Markdown IDE for Android.

## Features
- **Gruvbox Dark** theme
- Adaptive 3-pane layout for foldable devices
- Full GFM Markdown preview with [[Notes|wikilinks]]
- Front-matter and tag extraction
- On-device local AI assistant

## Quick Tasks
- [x] Create project
- [x] Implement Gruvbox theme
- [x] Implement 3-pane layout
- [ ] Test on emulator
''', flush: true);

      final notesDir = Directory(p.join(rootPath, 'notes'));
      await notesDir.create(recursive: true);
      final notesFile = File(p.join(notesDir.path, 'Notes.md'));
      await notesFile.writeAsString('''---
title: Sample Notes
tags: [sample, ideas]
---

# Sample Notes :memo:

This is a linked document via [[Welcome|Welcome File]].

Enjoy writing with Quill & Papyrus!
''', flush: true);
    } catch (_) {}
  }

  Future<List<FileNode>> listDirectory(String uri) async {
    final cleanPath = normalizePath(uri);
    final directory = Directory(cleanPath);
    if (!await directory.exists()) return [];

    final List<FileNode> nodes = [];
    try {
      final entities = await directory.list(followLinks: false).toList();

      for (var entity in entities) {
        // Skip hidden files/directories (starting with dot) or dedicated models folder
        final name = p.basename(entity.path);
        final lower = name.toLowerCase();
        if (name.startsWith('.') || lower == 'models' || lower.endsWith('.gguf') || lower.endsWith('.bin')) {
          continue;
        }

        try {
          final isDir = entity is Directory;
          final stat = await entity.stat();

          nodes.add(FileNode(
            uri: entity.path,
            name: name,
            path: p.relative(entity.path, from: cleanPath),
            isDirectory: isDir,
            lastModified: stat.modified,
            sizeBytes: isDir ? null : stat.size,
            children: isDir ? await listDirectory(entity.path) : [],
          ));
        } catch (_) {}
      }
    } catch (e) {
      // If permission is required on Android, attempt to notify
      return [];
    }
    return nodes;
  }

  Future<String> readFile(String uri) async {
    final cleanPath = normalizePath(uri);
    final file = File(cleanPath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<void> writeFile(String uri, String content) async {
    final cleanPath = normalizePath(uri);
    final file = File(cleanPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content, flush: true);
  }

  Future<String> createFile(String directoryUri, String fileName) async {
    final cleanDirPath = normalizePath(directoryUri);
    final newFilePath = p.join(cleanDirPath, fileName);
    final file = File(newFilePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.create(recursive: true);
    return newFilePath;
  }

  Future<String> createDirectory(String parentUri, String dirName) async {
    final cleanDirPath = normalizePath(parentUri);
    final newDirPath = p.join(cleanDirPath, dirName);
    final dir = Directory(newDirPath);
    await dir.create(recursive: true);
    return newDirPath;
  }

  Future<void> deleteFile(String uri) async {
    await deleteNode(uri);
  }

  Future<void> deleteNode(String uri) async {
    final cleanPath = normalizePath(uri);
    final file = File(cleanPath);
    if (await file.exists()) {
      await file.delete();
      return;
    }
    final dir = Directory(cleanPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> renameFile(String uri, String newName) async {
    await renameNode(uri, newName);
  }

  Future<void> renameNode(String uri, String newName) async {
    final cleanPath = normalizePath(uri);
    final file = File(cleanPath);
    if (await file.exists()) {
      final newPath = p.join(p.dirname(cleanPath), newName);
      await file.rename(newPath);
      return;
    }
    final dir = Directory(cleanPath);
    if (await dir.exists()) {
      final newPath = p.join(p.dirname(cleanPath), newName);
      await dir.rename(newPath);
    }
  }

  /// Moves a file or folder into target destination directory
  Future<String?> moveNode(String sourceUri, String targetDirUri) async {
    final cleanSource = normalizePath(sourceUri);
    final cleanTarget = normalizePath(targetDirUri);

    final name = p.basename(cleanSource);
    final newPath = p.join(cleanTarget, name);
    if (cleanSource == newPath) return cleanSource;

    // Prevent moving a folder into itself or its own subfolder
    if (cleanTarget.startsWith(cleanSource)) return null;

    final file = File(cleanSource);
    if (await file.exists()) {
      await file.rename(newPath);
      return newPath;
    }
    final dir = Directory(cleanSource);
    if (await dir.exists()) {
      await dir.rename(newPath);
      return newPath;
    }
    return null;
  }

  Future<FileNode> buildFileTree(String rootUri) async {
    final cleanPath = normalizePath(rootUri);
    final name = p.basename(cleanPath);
    final children = await listDirectory(cleanPath);

    return FileNode(
      uri: cleanPath,
      name: name.isEmpty ? 'Workspace' : name,
      path: '',
      isDirectory: true,
      children: children,
    );
  }

  Future<FileNode> getDirectoryTree(String rootUri) async {
    return await buildFileTree(rootUri);
  }
}
