import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SafStorageService storageService;

  setUpAll(() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('quill_persistence_test_');
    storageService = SafStorageService();
    await DatabaseService.instance.clearAllDrafts();
  });

  tearDown(() async {
    await DatabaseService.instance.clearAllDrafts();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Two-Tier Persistence Engine Tests', () {
    test('Tier 1: Hot Exit SQLite draft snapshotting and recovery', () async {
      final testFile = File(p.join(tempDir.path, 'note1.md'));
      await testFile.writeAsString('Original Disk Content', flush: true);

      final notifier = EditorNotifier(storageService);
      addTearDown(() => notifier.dispose());

      await notifier.openFile(testFile.path, 'note1.md');
      expect(notifier.state.tabs.length, 1);
      expect(notifier.state.activeTab?.content, 'Original Disk Content');
      expect(notifier.state.activeTab?.savedContent, 'Original Disk Content');

      // User types new content
      notifier.updateContent('Draft in progress that has not been saved to disk');

      // Wait for 150ms micro-debounce hot-exit snapshot
      await Future.delayed(const Duration(milliseconds: 220));

      final draft = await DatabaseService.instance.getDraft(testFile.path);
      expect(draft, isNotNull);
      expect(draft!['content'], 'Draft in progress that has not been saved to disk');
      expect(draft['file_uri'], testFile.path);

      // Verify disk content has NOT been prematurely modified before debounced write-back (if checked before 500ms)
      // Now simulate a crash/reopen: close tab or new notifier instance
      final freshNotifier = EditorNotifier(storageService);
      addTearDown(() => freshNotifier.dispose());

      // Open the file with uncommitted draft
      await freshNotifier.openFile(testFile.path, 'note1.md');
      expect(freshNotifier.state.tabs.length, 1);
      final restoredTab = freshNotifier.state.activeTab!;

      // Content restored from hot-exit draft
      expect(restoredTab.content, 'Draft in progress that has not been saved to disk');
      // savedContent remains disk content so user sees dirty state
      expect(restoredTab.savedContent, 'Original Disk Content');
      expect(restoredTab.content != restoredTab.savedContent, isTrue);
    });

    test('Tier 2: Debounced Atomic Write-Back writes to disk after 500ms and clears draft', () async {
      final testFile = File(p.join(tempDir.path, 'auto_save_note.md'));
      await testFile.writeAsString('# Title\nInitial.', flush: true);

      bool fileSavedCallbackTriggered = false;
      String? savedUri;
      String? savedContent;

      final notifier = EditorNotifier(
        storageService,
        onFileSaved: (uri, content) {
          fileSavedCallbackTriggered = true;
          savedUri = uri;
          savedContent = content;
        },
      );
      addTearDown(() => notifier.dispose());

      await notifier.openFile(testFile.path, 'auto_save_note.md');
      expect(notifier.state.tabs.length, 1);

      // User types changes
      const updatedText = '# Title\nUpdated content with debounced atomic write-back.';
      notifier.updateContent(updatedText);

      // Verify that after 100ms, the file on disk has NOT updated yet
      await Future.delayed(const Duration(milliseconds: 100));
      expect(await testFile.readAsString(), '# Title\nInitial.');

      // Wait for 500ms debounced write-back duration to complete
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (await testFile.exists()) {
          try {
            if (await testFile.readAsString() == updatedText) break;
          } catch (_) {}
        }
      }

      // Verify file on disk is atomically updated
      final diskContent = await testFile.readAsString();
      expect(diskContent, updatedText);

      // Verify onFileSaved callback was invoked
      expect(fileSavedCallbackTriggered, isTrue);
      expect(savedUri, testFile.path);
      expect(savedContent, updatedText);

      // Verify tab savedContent state matches content (clears dirty dot)
      expect(notifier.state.activeTab?.savedContent, updatedText);

      // Verify Hot Exit draft in SQLite was cleared after successful write-back
      final draft = await DatabaseService.instance.getDraft(testFile.path);
      expect(draft, isNull);
    });

    test('Immediate flushPendingWrites writes all dirty tabs to disk without waiting for timers', () async {
      final fileA = File(p.join(tempDir.path, 'tabA.md'));
      final fileB = File(p.join(tempDir.path, 'tabB.md'));
      await fileA.writeAsString('Initial A', flush: true);
      await fileB.writeAsString('Initial B', flush: true);

      final notifier = EditorNotifier(storageService);
      addTearDown(() => notifier.dispose());

      await notifier.openFile(fileA.path, 'tabA.md');
      await notifier.openFile(fileB.path, 'tabB.md');
      expect(notifier.state.tabs.length, 2);

      // Edit tab B (active)
      notifier.updateContent('Immediate Content B');
      // Switch to tab A and edit
      notifier.switchTab(0);
      notifier.updateContent('Immediate Content A');

      // Immediately flush (e.g. app pause, window close)
      await notifier.flushPendingWrites();

      // Both files must be immediately written to disk
      expect(await fileA.readAsString(), 'Immediate Content A');
      expect(await fileB.readAsString(), 'Immediate Content B');

      // Drafts should be cleared
      expect(await DatabaseService.instance.getDraft(fileA.path), isNull);
      expect(await DatabaseService.instance.getDraft(fileB.path), isNull);
    });

    test('Closing a dirty tab immediately flushes to disk and deletes SQLite draft', () async {
      final testFile = File(p.join(tempDir.path, 'closing_tab.md'));
      await testFile.writeAsString('Start', flush: true);

      final notifier = EditorNotifier(storageService);
      addTearDown(() => notifier.dispose());

      await notifier.openFile(testFile.path, 'closing_tab.md');
      notifier.updateContent('Content before tab close');

      // Close tab immediately
      await notifier.closeTab(0);

      expect(notifier.state.tabs.isEmpty, isTrue);
      // Content written to disk
      expect(await testFile.readAsString(), 'Content before tab close');
      // Draft cleaned
      expect(await DatabaseService.instance.getDraft(testFile.path), isNull);
    });
  });
}
