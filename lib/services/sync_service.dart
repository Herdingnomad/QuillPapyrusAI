import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/sync_models.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const String defaultWindowsSyncPath = r'C:\Users\jessi\OneDrive\Autosync\Journal-Log';
  static const String primaryAndroidSyncPath = '/storage/emulated/0/Autosync/Journal-Log';
  static const String fallbackAndroidSyncPath = '/storage/emulated/0/Documents/Journal-Log';
  static const String defaultAndroidSyncPath = primaryAndroidSyncPath;

  String? _customSyncPath;
  StreamSubscription<FileSystemEvent>? _watcherSub;
  Timer? _debounceTimer;

  String get effectiveSyncPath {
    if (_customSyncPath != null && _customSyncPath!.isNotEmpty) {
      return _customSyncPath!;
    }
    if (Platform.isWindows) {
      return defaultWindowsSyncPath;
    } else {
      if (Directory(primaryAndroidSyncPath).existsSync()) {
        return primaryAndroidSyncPath;
      }
      if (Directory(fallbackAndroidSyncPath).existsSync()) {
        return fallbackAndroidSyncPath;
      }
      return primaryAndroidSyncPath;
    }
  }

  /// Discovers existing known sync directories on the host device
  List<String> getDiscoveredSyncPaths() {
    final paths = <String>[];
    if (Platform.isAndroid) {
      if (Directory(primaryAndroidSyncPath).existsSync()) paths.add(primaryAndroidSyncPath);
      if (Directory(fallbackAndroidSyncPath).existsSync()) paths.add(fallbackAndroidSyncPath);
    } else if (Platform.isWindows) {
      if (Directory(defaultWindowsSyncPath).existsSync()) paths.add(defaultWindowsSyncPath);
      final alt = r'C:\Users\jessi\OneDrive\Documents\Journal-Log';
      if (Directory(alt).existsSync()) paths.add(alt);
    }
    return paths;
  }

  bool get isSyncPathAvailable {
    try {
      final dir = Directory(effectiveSyncPath);
      return dir.existsSync();
    } catch (_) {
      return false;
    }
  }

  void setCustomSyncPath(String? path) {
    _customSyncPath = path;
  }

  /// Calculates SHA-256 hash of a string
  String computeHash(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// Writes file atomically using temporary swap to prevent OneDrive sync corruption
  Future<void> writeAtomic(String filePath, String content) async {
    final file = File(filePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final tempFile = File('$filePath.quill_tmp_${DateTime.now().millisecondsSinceEpoch}');
    try {
      await tempFile.writeAsString(content, flush: true);
      // Atomic rename / replace
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await tempFile.rename(filePath);
    } catch (e) {
      // Fallback to direct write if rename fails
      try {
        await file.writeAsString(content, flush: true);
      } finally {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }
    }
  }

  /// Performs full bidirectional reconciliation between workspace and sync folder
  Future<SyncResult> performSync({
    required String localWorkspacePath,
    void Function(String message)? onProgress,
  }) async {
    final now = DateTime.now();
    final syncDir = Directory(effectiveSyncPath);
    final localDir = Directory(localWorkspacePath);

    if (!await syncDir.exists()) {
      try {
        await syncDir.create(recursive: true);
      } catch (e) {
        return SyncResult(
          success: false,
          errorMessage: 'Sync target directory does not exist and could not be created: $e',
          timestamp: now,
        );
      }
    }

    if (!await localDir.exists()) {
      return SyncResult(
        success: false,
        errorMessage: 'Local workspace directory does not exist: $localWorkspacePath',
        timestamp: now,
      );
    }

    // If local workspace is the sync directory itself, update manifest and return
    final isSameFolder = p.canonicalize(syncDir.path) == p.canonicalize(localDir.path);
    if (isSameFolder) {
      return await _scanAndIndexFolder(syncDir.path);
    }

    final manifest = await DatabaseService.instance.getSyncManifest();
    final List<SyncConflict> conflicts = [];
    int checkedCount = 0;
    int syncedCount = 0;

    try {
      // 1. Gather all local markdown and text files
      final localFiles = await _gatherFiles(localDir);
      // 2. Gather all sync folder files
      final remoteFiles = await _gatherFiles(syncDir);

      final allRelativePaths = {...localFiles.keys, ...remoteFiles.keys};
      checkedCount = allRelativePaths.length;

      for (final relPath in allRelativePaths) {
        final localFile = localFiles[relPath];
        final remoteFile = remoteFiles[relPath];
        final entry = manifest[relPath];

        if (localFile != null && remoteFile != null) {
          final localContent = await localFile.readAsString();
          final remoteContent = await remoteFile.readAsString();
          final localHash = computeHash(localContent);
          final remoteHash = computeHash(remoteContent);

          if (localHash == remoteHash) {
            // Both are identical, update manifest
            await _updateManifest(relPath, localHash, localFile);
            continue;
          }

          if (entry != null) {
            final baseHash = entry.sha256Hash;
            final localChanged = localHash != baseHash;
            final remoteChanged = remoteHash != baseHash;

            if (localChanged && !remoteChanged) {
              // Local updated -> push to remote
              await writeAtomic(remoteFile.path, localContent);
              await _updateManifest(relPath, localHash, localFile);
              syncedCount++;
            } else if (!localChanged && remoteChanged) {
              // Remote updated -> pull to local
              await writeAtomic(localFile.path, remoteContent);
              await _updateManifest(relPath, remoteHash, remoteFile);
              syncedCount++;
            } else if (localChanged && remoteChanged) {
              // Both changed offline! Non-destructive conflict handling
              final timestampStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
              final conflictFileName = '${p.withoutExtension(relPath)}.conflict.$timestampStr${p.extension(relPath)}';
              final conflictFilePath = p.join(localDir.path, conflictFileName);

              // Write remote version as conflict copy locally
              await writeAtomic(conflictFilePath, remoteContent);
              conflicts.add(SyncConflict(
                relativePath: relPath,
                localUri: localFile.path,
                conflictUri: conflictFilePath,
                timestamp: now,
              ));
            }
          } else {
            // No prior manifest record, compare modified dates
            final localStat = await localFile.stat();
            final remoteStat = await remoteFile.stat();
            if (localStat.modified.isAfter(remoteStat.modified)) {
              await writeAtomic(remoteFile.path, localContent);
              await _updateManifest(relPath, localHash, localFile);
            } else {
              await writeAtomic(localFile.path, remoteContent);
              await _updateManifest(relPath, remoteHash, remoteFile);
            }
            syncedCount++;
          }
        } else if (localFile != null && remoteFile == null) {
          // Exists only locally -> copy to sync target
          final targetPath = p.join(syncDir.path, relPath);
          final content = await localFile.readAsString();
          await writeAtomic(targetPath, content);
          await _updateManifest(relPath, computeHash(content), localFile);
          syncedCount++;
        } else if (localFile == null && remoteFile != null) {
          // Exists only in sync target -> copy to local workspace
          final targetPath = p.join(localDir.path, relPath);
          final content = await remoteFile.readAsString();
          await writeAtomic(targetPath, content);
          await _updateManifest(relPath, computeHash(content), remoteFile);
          syncedCount++;
        }
      }

      return SyncResult(
        success: true,
        filesChecked: checkedCount,
        filesSynced: syncedCount,
        conflicts: conflicts,
        timestamp: now,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        filesChecked: checkedCount,
        filesSynced: syncedCount,
        conflicts: conflicts,
        errorMessage: e.toString(),
        timestamp: now,
      );
    }
  }

  Future<SyncResult> _scanAndIndexFolder(String folderPath) async {
    final now = DateTime.now();
    final dir = Directory(folderPath);
    final files = await _gatherFiles(dir);

    for (final entry in files.entries) {
      try {
        final content = await entry.value.readAsString();
        final hash = computeHash(content);
        await _updateManifest(entry.key, hash, entry.value);
      } catch (_) {}
    }

    return SyncResult(
      success: true,
      filesChecked: files.length,
      filesSynced: 0,
      timestamp: now,
    );
  }

  /// Safely copies any newer or missing markdown files from source to destination directory
  Future<int> reconcileFolders({required String sourcePath, required String targetPath}) async {
    final srcDir = Directory(sourcePath);
    final dstDir = Directory(targetPath);
    if (!await srcDir.exists() || !await dstDir.exists()) return 0;

    int mergedCount = 0;
    final srcFiles = await _gatherFiles(srcDir);
    final dstFiles = await _gatherFiles(dstDir);

    for (final entry in srcFiles.entries) {
      final rel = entry.key;
      final srcFile = entry.value;
      final dstFile = dstFiles[rel];

      if (dstFile == null) {
        final targetFilePath = p.join(dstDir.path, rel);
        final content = await srcFile.readAsString();
        await writeAtomic(targetFilePath, content);
        mergedCount++;
      } else {
        final srcStat = await srcFile.stat();
        final dstStat = await dstFile.stat();
        if (srcStat.modified.isAfter(dstStat.modified)) {
          final srcContent = await srcFile.readAsString();
          final dstContent = await dstFile.readAsString();
          if (computeHash(srcContent) != computeHash(dstContent)) {
            await writeAtomic(dstFile.path, srcContent);
            mergedCount++;
          }
        }
      }
    }
    return mergedCount;
  }

  Future<void> _updateManifest(String relPath, String hash, File file) async {
    final stat = await file.stat();
    await DatabaseService.instance.updateSyncManifestEntry(SyncManifestEntry(
      relativePath: relPath,
      sha256Hash: hash,
      lastModified: stat.modified.millisecondsSinceEpoch,
      fileSize: stat.size,
      syncTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<Map<String, File>> _gatherFiles(Directory root) async {
    final Map<String, File> result = {};
    if (!await root.exists()) return result;

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final name = p.basename(entity.path);
        // Exclude hidden files, temp files, and model files
        if (name.startsWith('.') ||
            name.contains('.quill_tmp_') ||
            name.endsWith('.gguf') ||
            name.endsWith('.bin')) {
          continue;
        }
        final relPath = p.relative(entity.path, from: root.path).replaceAll(r'\', '/');
        result[relPath] = entity;
      }
    }
    return result;
  }

  /// Starts live file system watcher on the sync folder with 400ms debouncing
  void startWatcher({required VoidCallback onChange}) {
    stopWatcher();
    final dir = Directory(effectiveSyncPath);
    if (!dir.existsSync()) return;

    try {
      _watcherSub = dir.watch(recursive: true).listen((event) {
        final baseName = p.basename(event.path);
        if (baseName.startsWith('.') || baseName.contains('.quill_tmp_')) return;

        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 400), () {
          onChange();
        });
      });
    } catch (_) {}
  }

  void stopWatcher() {
    _debounceTimer?.cancel();
    _watcherSub?.cancel();
    _watcherSub = null;
  }
}
