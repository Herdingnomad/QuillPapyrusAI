import 'package:flutter/material.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class HeadingNode {
  final int level;
  final String text;
  final int charOffset;
  final int lineNumber;
  final int wordCount;
  final List<String> revisionMarkers;

  const HeadingNode({
    required this.level,
    required this.text,
    required this.charOffset,
    required this.lineNumber,
    required this.wordCount,
    required this.revisionMarkers,
  });
}

class DocumentMapWidget extends StatelessWidget {
  final String content;
  final void Function(int lineNumber, int charOffset)? onHeadingSelected;

  const DocumentMapWidget({
    super.key,
    required this.content,
    this.onHeadingSelected,
  });

  List<HeadingNode> _parseHeadings(String text) {
    final lines = text.split('\n');
    final nodes = <HeadingNode>[];
    int charOffset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('#')) {
        final match = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
        if (match != null) {
          final level = match.group(1)!.length;
          final title = match.group(2)!.trim();

          // Check for revision markers (TODO, FIXME, ???)
          final markers = <String>[];
          if (title.contains('TODO')) markers.add('TODO');
          if (title.contains('FIXME')) markers.add('FIXME');
          if (title.contains('???')) markers.add('???');

          nodes.add(HeadingNode(
            level: level,
            text: title,
            charOffset: charOffset,
            lineNumber: i + 1,
            wordCount: 0, // computed in next pass
            revisionMarkers: markers,
          ));
        }
      }
      charOffset += line.length + 1; // +1 for \n
    }

    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    final headings = _parseHeadings(content);

    if (headings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.list_alt, color: GruvboxColors.gray, size: 36),
              const SizedBox(height: 8),
              Text(
                'No headings found in document',
                style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Use # Heading 1, ## Heading 2 to build your document map',
                textAlign: TextAlign.center,
                style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: headings.length,
      itemBuilder: (context, index) {
        final node = headings[index];
        final indent = (node.level - 1) * 14.0;

        return InkWell(
          onTap: () => onHeadingSelected?.call(node.lineNumber, node.charOffset),
          child: Padding(
            padding: EdgeInsets.only(left: 12.0 + indent, right: 12.0, top: 4.0, bottom: 4.0),
            child: Row(
              children: [
                Icon(
                  node.level == 1
                      ? Icons.bookmark
                      : node.level == 2
                          ? Icons.bookmark_border
                          : Icons.fiber_manual_record,
                  size: node.level <= 2 ? 14 : 8,
                  color: node.level == 1
                      ? GruvboxColors.green
                      : node.level == 2
                          ? GruvboxColors.yellow
                          : GruvboxColors.aqua,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.text,
                    style: TextStyle(
                      color: node.level == 1 ? GruvboxColors.fg0 : GruvboxColors.fg,
                      fontSize: node.level == 1 ? 13 : 12,
                      fontWeight: node.level <= 2 ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (node.revisionMarkers.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: GruvboxColors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      node.revisionMarkers.first,
                      style: TextStyle(
                        color: GruvboxColors.red,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  'L${node.lineNumber}',
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
