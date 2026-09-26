import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/ai_model_config.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/rag_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Folder Selection and Contextual Creation Tests', () {
    test('WorkspaceNotifier selectFolder and clearSelectedFolder update state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(workspaceProvider.notifier);
      expect(container.read(workspaceProvider).selectedFolderUri, isNull);

      notifier.selectFolder('/workspace/docs');
      expect(container.read(workspaceProvider).selectedFolderUri, '/workspace/docs');

      notifier.selectFolder('/workspace/notes');
      expect(container.read(workspaceProvider).selectedFolderUri, '/workspace/notes');

      notifier.clearSelectedFolder();
      expect(container.read(workspaceProvider).selectedFolderUri, isNull);
    });

    test('Creating file inside selected folder creates it in that folder and auto-expands directory', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Load mock workspace
      await container.read(workspaceProvider.notifier).pickAndLoadWorkspace();
      final workspace = container.read(workspaceProvider);
      expect(workspace.fileTree, isNotNull);

      final notesDir = workspace.fileTree!.findByName('notes');
      expect(notesDir, isNotNull);
      expect(notesDir!.isDirectory, isTrue);

      // Select the 'notes' folder
      container.read(workspaceProvider.notifier).selectFolder(notesDir.uri);
      expect(container.read(workspaceProvider).selectedFolderUri, notesDir.uri);

      // Create a file targeting the selected folder
      final targetFolderUri = container.read(workspaceProvider).selectedFolderUri!;
      final newFileUri = await container.read(workspaceProvider.notifier).createFile(
        targetFolderUri,
        'chapter1.md',
      );

      expect(newFileUri, isNotNull);

      // The new file should be inside the notes directory in the refreshed tree
      final updatedTree = container.read(workspaceProvider).fileTree;
      final updatedNotesDir = updatedTree?.findByName('notes');
      expect(updatedNotesDir, isNotNull);
      final foundInNotes = updatedNotesDir!.children.any((child) => child.name == 'chapter1.md');
      expect(foundInNotes, isTrue);

      // The target directory should be auto-expanded
      expect(container.read(workspaceProvider).expandedDirs.contains(notesDir.uri), isTrue);
    });

    test('EditorNotifier updateFileUri updates tab uri and fileName upon file move', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final editorNotifier = container.read(editorProvider.notifier);
      await editorNotifier.openFile('/workspace/drafts/post.md', 'post.md');
      expect(container.read(editorProvider).tabs.length, 1);
      expect(container.read(editorProvider).activeTab?.uri, '/workspace/drafts/post.md');
      expect(container.read(editorProvider).activeTab?.fileName, 'post.md');

      // Simulate moving post.md to /workspace/published/post.md
      editorNotifier.updateFileUri('/workspace/drafts/post.md', '/workspace/published/post.md', newFileName: 'post.md');
      expect(container.read(editorProvider).activeTab?.uri, '/workspace/published/post.md');
      expect(container.read(editorProvider).activeTab?.fileName, 'post.md');

      // Simulate renaming post.md to blog_post.md
      editorNotifier.updateFileUri('/workspace/published/post.md', '/workspace/published/blog_post.md', newFileName: 'blog_post.md');
      expect(container.read(editorProvider).activeTab?.uri, '/workspace/published/blog_post.md');
      expect(container.read(editorProvider).activeTab?.fileName, 'blog_post.md');
    });

    test('Moving a file via moveNode updates tree and open editor tabs', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Load mock workspace
      await container.read(workspaceProvider.notifier).pickAndLoadWorkspace();
      final workspace = container.read(workspaceProvider);
      final welcomeNode = workspace.fileTree?.findByName('Welcome.md');
      final notesDir = workspace.fileTree?.findByName('notes');

      expect(welcomeNode, isNotNull);
      expect(notesDir, isNotNull);

      // Open Welcome.md in editor
      await container.read(editorProvider.notifier).openFile(welcomeNode!.uri, welcomeNode.name);
      expect(container.read(editorProvider).activeTab?.uri, welcomeNode.uri);

      // Move Welcome.md into notes directory
      final moved = await container.read(workspaceProvider.notifier).moveNode(welcomeNode.uri, notesDir!.uri);
      expect(moved, isTrue);

      // Verify the tree updated: notes directory now contains Welcome.md
      final updatedTree = container.read(workspaceProvider).fileTree;
      final updatedNotesDir = updatedTree?.findByName('notes');
      expect(updatedNotesDir, isNotNull);
      final welcomeInNotes = updatedNotesDir!.children.firstWhere((c) => c.name == 'Welcome.md');
      expect(welcomeInNotes, isNotNull);

      // Verify open editor tab URI was updated to the new path
      expect(container.read(editorProvider).activeTab?.uri, welcomeInNotes.uri);
      // And target directory was auto-expanded
      expect(container.read(workspaceProvider).expandedDirs.contains(notesDir.uri), isTrue);
    });
  });

  group('Default AI Model Selection Tests', () {
    test('AiNotifier setDefaultModel and isDefaultModel manage default model preferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final aiNotifier = container.read(aiProvider.notifier);

      // Initial state has defaultModelType
      expect(container.read(aiProvider).defaultModelType, GemmaModelType.gemma4E4B);

      // Set default model to gemma4E2B
      await aiNotifier.setDefaultModel(modelType: GemmaModelType.gemma4E2B);
      expect(container.read(aiProvider).defaultModelType, GemmaModelType.gemma4E2B);
      expect(container.read(aiProvider).defaultModelPath, isNull);
      expect(aiNotifier.isDefaultModel(GemmaModelType.gemma4E2B), isTrue);
      expect(aiNotifier.isDefaultModel(GemmaModelType.gemma4E4B), isFalse);

      // Set custom model as default
      const customPath = '/storage/models/custom-gemma.gguf';
      await aiNotifier.setDefaultModel(
        modelType: GemmaModelType.customGGUF,
        customModelPath: customPath,
      );
      expect(container.read(aiProvider).defaultModelType, GemmaModelType.customGGUF);
      expect(container.read(aiProvider).defaultModelPath, customPath);
      expect(aiNotifier.isDefaultModel(GemmaModelType.customGGUF, customPath: customPath), isTrue);
      expect(aiNotifier.isDefaultModel(GemmaModelType.customGGUF, customPath: '/other/path.gguf'), isFalse);
    });
  });

  group('RAG Service Folder Scoping Tests', () {
    test('buildPromptContext formats scoped folder notes vs entire workspace notes', () async {
      final ragService = RagService();

      // Case 1: Scoped to folder "Druid" with scoped content
      final scopedContext = await ragService.buildPromptContext(
        query: 'What spells does the druid know?',
        parentFolder: 'Druid',
        currentDocContent: 'Druid Spells:\n1. Entangle\n2. Barkskin',
        directoryFiles: ['Druid/spells.md', 'Druid/stats.md', 'models/gemma.gguf'],
      );

      expect(scopedContext.contains('Active Document Context (Scoped Folder Notes: Druid)'), isTrue);
      expect(scopedContext.contains('Druid Spells:'), isTrue);
      expect(scopedContext.contains('NOTES IN FOLDER "Druid"'), isTrue);
      expect(scopedContext.contains('- Druid/spells.md'), isTrue);
      expect(scopedContext.contains('- Druid/stats.md'), isTrue);
      // Binary / model files must be excluded
      expect(scopedContext.contains('gemma.gguf'), isFalse);

      // Case 2: Unscoped / entire workspace (no doc active, all folders)
      final workspaceContext = await ragService.buildPromptContext(
        query: 'Summarize campaign notes',
        parentFolder: null,
        directoryFiles: ['Druid/spells.md', 'Paladin/oath.md', 'notes/Welcome.md', 'archive.zip'],
      );

      expect(workspaceContext.contains('WORKSPACE NOTES LIST Across All Folders'), isTrue);
      expect(workspaceContext.contains('- Druid/spells.md'), isTrue);
      expect(workspaceContext.contains('- Paladin/oath.md'), isTrue);
      expect(workspaceContext.contains('- notes/Welcome.md'), isTrue);
      // Archive / zip must be excluded
      expect(workspaceContext.contains('archive.zip'), isFalse);
    });

    test('buildPromptContext returns completely empty string when ragEnabled is false', () async {
      final ragService = RagService();

      final disabledContext = await ragService.buildPromptContext(
        query: 'What spells does the druid know?',
        ragEnabled: false,
        parentFolder: 'Druid',
        currentDocContent: 'Druid Spells:\n1. Entangle\n2. Barkskin',
        directoryFiles: ['Druid/spells.md', 'Druid/stats.md'],
      );

      expect(disabledContext, isEmpty);
    });

    test('AiNotifier toggles ragEnabled state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(aiProvider.notifier);
      expect(container.read(aiProvider).ragEnabled, isTrue);

      notifier.toggleRag();
      expect(container.read(aiProvider).ragEnabled, isFalse);

      notifier.toggleRag();
      expect(container.read(aiProvider).ragEnabled, isTrue);
    });

    test('AiNotifier setContextSize updates context window configuration', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(aiProvider.notifier);
      expect(container.read(aiProvider).config.contextSize, 4096);

      await notifier.setContextSize(8192);
      expect(container.read(aiProvider).config.contextSize, 8192);

      await notifier.setContextSize(2048);
      expect(container.read(aiProvider).config.contextSize, 2048);
    });
  });
}
