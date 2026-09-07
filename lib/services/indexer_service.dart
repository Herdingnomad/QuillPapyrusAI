import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';

class DocumentChunk {
  final String heading;
  final String content;
  final int level;

  DocumentChunk({
    required this.heading,
    required this.content,
    required this.level,
  });
}

class SearchResult {
  final String fileUri;
  final String fileName;
  final String parentFolder;
  final String headingContext;
  final String snippet;
  final String tags;

  SearchResult({
    required this.fileUri,
    required this.fileName,
    required this.parentFolder,
    required this.headingContext,
    required this.snippet,
    required this.tags,
  });
}

class IndexerService {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<void> indexFile(String fileUri, String fileName, String parentFolder, String content) async {
    await _dbService.deleteFromWorkspaceIndex(fileUri);

    final frontMatter = FrontMatterService.parse(content);
    final tags = frontMatter?.tags.join(',') ?? '';
    final plainContent = FrontMatterService.stripFrontMatter(content);
    
    final chunks = _chunkByHeadings(plainContent);
    
    for (final chunk in chunks) {
      await _dbService.upsertWorkspaceIndex(
        fileUri: fileUri,
        fileName: fileName,
        parentFolder: parentFolder,
        headingContext: chunk.heading,
        content: chunk.content,
        tags: tags,
      );
    }
  }

  Future<void> indexWorkspace(FileNode root, SafStorageService storage) async {
    await _dbService.clearWorkspaceIndex();

    Future<void> processNode(FileNode node, String currentParent) async {
      final nameLower = node.name.toLowerCase();
      if (nameLower == 'models' || node.name.startsWith('.')) {
        return; // Skip models folder and hidden folders
      }

      if (node.isDirectory) {
        for (final child in node.children) {
          await processNode(child, node.name);
        }
      } else if (nameLower.endsWith('.md')) {
        final content = await storage.readFile(node.uri);
        await indexFile(node.uri, node.name, currentParent, content);
      }
    }

    await processNode(root, 'root');
  }

  Future<void> removeFile(String fileUri) async {
    await _dbService.deleteFromWorkspaceIndex(fileUri);
  }

  Future<List<SearchResult>> search(String query, {String? parentFolder}) async {
    final results = await _dbService.searchWorkspace(query, parentFolder: parentFolder);
    
    return results.map((row) {
      return SearchResult(
        fileUri: row['file_uri']?.toString() ?? '',
        fileName: row['file_name']?.toString() ?? '',
        parentFolder: row['parent_folder']?.toString() ?? '',
        headingContext: row['heading_context']?.toString() ?? '',
        snippet: row['content']?.toString() ?? '',
        tags: row['tags']?.toString() ?? '',
      );
    }).toList();
  }

  List<DocumentChunk> _chunkByHeadings(String content) {
    final chunks = <DocumentChunk>[];
    final lines = content.split('\n');
    
    String currentHeading = 'Document Start';
    int currentLevel = 0;
    final currentContent = StringBuffer();
    
    for (final line in lines) {
      final match = RegExp(r'^(#{1,6})\s+(.*)').firstMatch(line);
      
      if (match != null) {
        if (currentContent.isNotEmpty) {
          chunks.add(DocumentChunk(
            heading: currentHeading,
            content: currentContent.toString().trim(),
            level: currentLevel,
          ));
          currentContent.clear();
        }
        
        currentLevel = match.group(1)!.length;
        currentHeading = match.group(2)!;
      } else {
        currentContent.writeln(line);
      }
    }
    
    if (currentContent.isNotEmpty) {
      chunks.add(DocumentChunk(
        heading: currentHeading,
        content: currentContent.toString().trim(),
        level: currentLevel,
      ));
    }
    
    return chunks.isNotEmpty ? chunks : [DocumentChunk(heading: 'Document Start', content: content, level: 0)];
  }
}
