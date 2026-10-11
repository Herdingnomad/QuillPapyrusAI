import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/editor_tab.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Editor Tab Navigation and Desktop Shortcuts Tests', () {
    test('Cycles open tabs with nextTab and previousTab', () {
      final notifier = EditorNotifier(SafStorageService());
      
      notifier.state = notifier.state.copyWith(
        tabs: [
          const EditorTab(uri: '/doc1.md', fileName: 'doc1.md', content: '', savedContent: ''),
          const EditorTab(uri: '/doc2.md', fileName: 'doc2.md', content: '', savedContent: ''),
          const EditorTab(uri: '/doc3.md', fileName: 'doc3.md', content: '', savedContent: ''),
        ],
        activeTabIndex: 0,
      );

      notifier.nextTab();
      expect(notifier.state.activeTabIndex, 1);

      notifier.nextTab();
      expect(notifier.state.activeTabIndex, 2);

      // Wrap around
      notifier.nextTab();
      expect(notifier.state.activeTabIndex, 0);

      // Previous tab wrap around
      notifier.previousTab();
      expect(notifier.state.activeTabIndex, 2);
    });

    test('Closes active tab and adjusts index gracefully', () {
      final notifier = EditorNotifier(SafStorageService());
      
      notifier.state = notifier.state.copyWith(
        tabs: [
          const EditorTab(uri: '/doc1.md', fileName: 'doc1.md', content: '', savedContent: ''),
          const EditorTab(uri: '/doc2.md', fileName: 'doc2.md', content: '', savedContent: ''),
        ],
        activeTabIndex: 1,
      );

      notifier.closeActiveTab();
      expect(notifier.state.tabs.length, 1);
      expect(notifier.state.activeTabIndex, 0);
      expect(notifier.state.tabs.first.fileName, 'doc1.md');
    });

    test('closeOtherTabs preserves only the requested tab', () {
      final notifier = EditorNotifier(SafStorageService());
      
      notifier.state = notifier.state.copyWith(
        tabs: [
          const EditorTab(uri: '/doc1.md', fileName: 'doc1.md', content: '', savedContent: ''),
          const EditorTab(uri: '/doc2.md', fileName: 'doc2.md', content: '', savedContent: ''),
          const EditorTab(uri: '/doc3.md', fileName: 'doc3.md', content: '', savedContent: ''),
        ],
        activeTabIndex: 0,
      );

      notifier.closeOtherTabs(1);
      expect(notifier.state.tabs.length, 1);
      expect(notifier.state.activeTabIndex, 0);
      expect(notifier.state.tabs.first.fileName, 'doc2.md');
    });

    test('closeTabsToTheRight closes only subsequent tabs', () {
      final notifier = EditorNotifier(SafStorageService());
      
      notifier.state = notifier.state.copyWith(
        tabs: [
          const EditorTab(uri: '/doc1.md', fileName: 'doc1.md', content: '', savedContent: ''),
          const EditorTab(uri: '/doc2.md', fileName: 'doc2.md', content: '', savedContent: ''),
          const EditorTab(uri: '/doc3.md', fileName: 'doc3.md', content: '', savedContent: ''),
        ],
        activeTabIndex: 2,
      );

      notifier.closeTabsToTheRight(1);
      expect(notifier.state.tabs.length, 2);
      expect(notifier.state.activeTabIndex, 1);
      expect(notifier.state.tabs.last.fileName, 'doc2.md');
    });
  });

  group('QuickNoteService Tests', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.jessiejensen.quill_papyrus_ai/widget'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      tempDir = Directory.systemTemp.createTempSync('quill_quicknote_test_');
      container = ProviderContainer();
      await container.read(workspaceProvider.notifier).loadWorkspace(tempDir.path);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.jessiejensen.quill_papyrus_ai/widget'),
        null,
      );
      container.dispose();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Creates Quick Note and opens it in editor', () async {
      final service = container.read(quickNoteServiceProvider);
      final createdPath = await service.createQuickNote(initialText: 'Meeting notes with DeepMind pair programmer');

      expect(createdPath, isNotNull);
      final file = File(createdPath!);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('tags: [quicknote, inbox]'), isTrue);
      expect(content.contains('Meeting notes with DeepMind pair programmer'), isTrue);
    });

    test('Creates Daily note and opens it in editor', () async {
      final service = container.read(quickNoteServiceProvider);
      final createdPath = await service.openOrCreateDailyNote();

      expect(createdPath, isNotNull);
      final file = File(createdPath!);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('tags: [daily, journal]'), isTrue);
      expect(content.contains('Daily Scratchpad'), isTrue);

      // Calling again opens existing file without re-creating
      final secondPath = await service.openOrCreateDailyNote();
      expect(secondPath, createdPath);
    });

    test('Handles deep link actions correctly', () async {
      final service = container.read(quickNoteServiceProvider);
      await service.handleActionUri('quillpapyrus://quick-note');

      final editorState = container.read(editorProvider);
      expect(editorState.tabs.isNotEmpty, isTrue);
      expect(editorState.tabs.last.fileName.startsWith('Note_'), isTrue);
    });
  });
}
