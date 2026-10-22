import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/manuscript_metadata.dart';
import 'package:quill_papyrus_ai/models/scrivenings_model.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';

class ScriveningsService {
  ScriveningsService._();
  static final ScriveningsService instance = ScriveningsService._();

  static const String sectionDividerPrefix = '<!-- === SCENE: ';

  /// Assembles multiple modular files into a continuous scrolling virtual document
  Future<StitchedDocument> buildStitchedDocument(
    List<FileNode> nodes,
    SafStorageService storage,
  ) async {
    final segments = <ScriveningsSegment>[];
    final sb = StringBuffer();
    int currentOffset = 0;

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node.isDirectory) continue;

      final rawContent = await storage.readFile(node.uri);
      final metadata = ManuscriptMetadata.extractFromMarkdown(rawContent, fallbackTitle: node.name);

      final banner = '\n$sectionDividerPrefix${node.name} === -->\n';
      sb.write(banner);
      currentOffset += banner.length;

      final segmentStart = currentOffset;
      sb.write(rawContent);
      currentOffset += rawContent.length;
      final segmentEnd = currentOffset;

      sb.write('\n\n');
      currentOffset += 2;

      segments.add(ScriveningsSegment(
        fileUri: node.uri,
        fileName: node.name,
        title: metadata.title.isNotEmpty ? metadata.title : node.name,
        content: rawContent,
        startOffset: segmentStart,
        endOffset: segmentEnd,
        metadata: metadata,
      ));
    }

    return StitchedDocument(
      segments: segments,
      stitchedContent: sb.toString(),
    );
  }

  /// Saves edited segment content back to its source file on disk
  Future<void> flushSegmentToDisk(
    ScriveningsSegment segment,
    String updatedContent,
    SafStorageService storage,
  ) async {
    await storage.writeFile(segment.fileUri, updatedContent);
  }
}
