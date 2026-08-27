import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/chat.dart';
import 'package:quill_papyrus_ai/models/editor_tab.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/workspace_state.dart';

void main() {
  group('Models test', () {
    test('FileNode recursive file count and tree searching', () {
      const tree = FileNode(
        uri: '/root',
        name: 'root',
        path: '',
        isDirectory: true,
        children: [
          FileNode(
            uri: '/root/a.md',
            name: 'a.md',
            path: 'a.md',
            isDirectory: false,
          ),
          FileNode(
            uri: '/root/folder',
            name: 'folder',
            path: 'folder',
            isDirectory: true,
            children: [
              FileNode(
                uri: '/root/folder/b.md',
                name: 'b.md',
                path: 'folder/b.md',
                isDirectory: false,
              ),
              FileNode(
                uri: '/root/folder/c.md',
                name: 'c.md',
                path: 'folder/c.md',
                isDirectory: false,
              ),
            ],
          ),
        ],
      );

      expect(tree.fileCount, 3);
      expect(tree.findByName('b.md')?.uri, '/root/folder/b.md');
      expect(tree.findByUri('/root/folder/c.md')?.name, 'c.md');
      expect(tree.sortedChildren.first.name, 'folder'); // Directories first
    });

    test('EditorTab dirty tracking and id', () {
      const tab = EditorTab(
        uri: '/doc.md',
        fileName: 'doc.md',
        content: 'Initial text',
        savedContent: 'Initial text',
      );

      expect(tab.id, '/doc.md');
      expect(tab.isDirty, isFalse);

      final editedTab = tab.copyWith(content: 'Modified text');
      expect(editedTab.isDirty, isTrue);
    });

    test('WorkspaceState loading/error getters and copyWith', () {
      const state = WorkspaceState();
      expect(state.isLoading, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.hasError, isFalse);

      final loadingState = state.copyWith(isLoading: true);
      expect(loadingState.isLoading, isTrue);

      final loadedState = state.copyWith(
        status: WorkspaceStatus.loaded,
        rootUri: '/ws',
        tags: ['tech'],
      );
      expect(loadedState.isLoaded, isTrue);
      expect(loadedState.tags, ['tech']);
    });

    test('Chat and ChatMessage Equatable', () {
      final now = DateTime.now();
      final chat1 = Chat(id: 'c1', title: 'Chat 1', createdAt: now, updatedAt: now);
      final chat2 = Chat(id: 'c1', title: 'Chat 1', createdAt: now, updatedAt: now);
      expect(chat1, equals(chat2));

      final msg1 = ChatMessage(id: 'm1', chatId: 'c1', sender: MessageSender.user, content: 'Hi', timestamp: now);
      final msg2 = ChatMessage(id: 'm1', chatId: 'c1', sender: MessageSender.user, content: 'Hi', timestamp: now);
      expect(msg1, equals(msg2));
    });
  });
}
