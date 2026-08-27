import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/services/wikilink_service.dart';

void main() {
  group('WikilinkService', () {
    test('finds standard [[wikilinks]] and aliased [[target|display]] links', () {
      const markdown = 'Check [[Overview]] and also [[Architecture|System Design]] for details.';
      final matches = WikilinkService.findWikilinks(markdown);

      expect(matches.length, 2);
      expect(matches[0].target, 'Overview');
      expect(matches[0].displayText, isNull);

      expect(matches[1].target, 'Architecture');
      expect(matches[1].displayText, 'System Design');
    });

    test('resolves wikilink across entire workspace tree (case-insensitive with/without .md)', () {
      const root = FileNode(
        uri: '/workspace',
        name: 'workspace',
        path: '',
        isDirectory: true,
        children: [
          FileNode(
            uri: '/workspace/doc1.md',
            name: 'doc1.md',
            path: 'doc1.md',
            isDirectory: false,
          ),
          FileNode(
            uri: '/workspace/subfolder',
            name: 'subfolder',
            path: 'subfolder',
            isDirectory: true,
            children: [
              FileNode(
                uri: '/workspace/subfolder/Architecture.md',
                name: 'Architecture.md',
                path: 'subfolder/Architecture.md',
                isDirectory: false,
              ),
            ],
          ),
        ],
      );

      final uri1 = WikilinkService.resolveWikilink('doc1', root);
      expect(uri1, '/workspace/doc1.md');

      final uri2 = WikilinkService.resolveWikilink('architecture', root);
      expect(uri2, '/workspace/subfolder/Architecture.md');

      final uri3 = WikilinkService.resolveWikilink('NonExistent', root);
      expect(uri3, isNull);
    });

    test('renders wikilinks into markdown format for resolved targets', () {
      const root = FileNode(
        uri: '/workspace',
        name: 'workspace',
        path: '',
        isDirectory: true,
        children: [
          FileNode(
            uri: '/workspace/Guide.md',
            name: 'Guide.md',
            path: 'Guide.md',
            isDirectory: false,
          ),
        ],
      );

      const input = 'See [[Guide|the guide]] for instructions.';
      final rendered = WikilinkService.renderWikilinksToMarkdown(input, root);
      expect(rendered, 'See [the guide](/workspace/Guide.md) for instructions.');
    });
  });
}
