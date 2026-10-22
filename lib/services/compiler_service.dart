import 'package:markdown/markdown.dart' as md;
import 'package:quill_papyrus_ai/models/compiler_config.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/manuscript_metadata.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';

class CompiledDocument {
  final String content;
  final int totalWords;
  final int chapterCount;
  final String suggestedFileName;

  const CompiledDocument({
    required this.content,
    required this.totalWords,
    required this.chapterCount,
    required this.suggestedFileName,
  });
}

class CompilerService {
  CompilerService._();
  static final CompilerService instance = CompilerService._();

  static const List<String> wordNumbers = [
    'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen', 'Twenty',
    'Twenty-One', 'Twenty-Two', 'Twenty-Three', 'Twenty-Four', 'Twenty-Five', 'Twenty-Six', 'Twenty-Seven', 'Twenty-Eight', 'Twenty-Nine', 'Thirty',
  ];

  static const List<String> romanNumerals = [
    'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X',
    'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX',
    'XXI', 'XXII', 'XXIII', 'XXIV', 'XXV', 'XXVI', 'XXVII', 'XXVIII', 'XXIX', 'XXX',
  ];

  String _formatChapterTitle(int index, String rawTitle, ChapterNumberingStyle style) {
    switch (style) {
      case ChapterNumberingStyle.numeric:
        return 'Chapter ${index + 1}: $rawTitle';
      case ChapterNumberingStyle.words:
        final numStr = index < wordNumbers.length ? wordNumbers[index] : '${index + 1}';
        return 'Chapter $numStr: $rawTitle';
      case ChapterNumberingStyle.roman:
        final romStr = index < romanNumerals.length ? romanNumerals[index] : '${index + 1}';
        return 'CHAPTER $romStr: $rawTitle';
      case ChapterNumberingStyle.titleOnly:
        return rawTitle;
      case ChapterNumberingStyle.none:
        return '';
    }
  }

  /// Strips internal non-printing comments, CriticMarkup, and front-matter
  String sanitizeMarkdown(String input, CompilerConfig config) {
    var text = input;

    // Strip frontmatter
    if (config.stripFrontmatter) {
      final trimmed = text.trimLeft();
      if (trimmed.startsWith('---')) {
        final closeIdx = trimmed.indexOf('---', 3);
        if (closeIdx != -1) {
          text = trimmed.substring(closeIdx + 3).trimLeft();
        }
      }
    }

    // Strip HTML comments <!-- ... -->
    if (config.stripComments) {
      text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
      // Strip CriticMarkup
      text = text.replaceAll(RegExp(r'\{--[\s\S]*?--\}'), ''); // deletions
      text = text.replaceAllMapped(RegExp(r'\{\+\+([\s\S]*?)\+\+\}'), (m) => m[1] ?? ''); // accept additions
      text = text.replaceAll(RegExp(r'\{>>[\s\S]*?<<\}'), ''); // remarks
      text = text.replaceAllMapped(RegExp(r'\{==([\s\S]*?)==\}'), (m) => m[1] ?? ''); // unwrap highlights
    }

    // Strip TODO/FIXME markers
    if (config.stripTodoMarkers) {
      text = text.replaceAll(RegExp(r'^\s*-\s*\[\s*\]\s*TODO.*$', multiLine: true), '');
      text = text.replaceAll(RegExp(r'\b(TODO|FIXME|\?\?\?):?.*$', multiLine: true), '');
    }

    return text.trim();
  }

  /// Compiles multiple files into a production artifact
  Future<CompiledDocument> compileManuscript({
    required List<FileNode> files,
    required SafStorageService storage,
    required CompilerConfig config,
  }) async {
    final chapters = <Map<String, String>>[];
    int totalWords = 0;

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      if (file.isDirectory) continue;

      final raw = await storage.readFile(file.uri);
      final meta = ManuscriptMetadata.extractFromMarkdown(raw, fallbackTitle: file.name);
      final sanitized = sanitizeMarkdown(raw, config);
      final words = sanitized.trim().isEmpty ? 0 : sanitized.trim().split(RegExp(r'\s+')).length;
      totalWords += words;

      final title = _formatChapterTitle(chapters.length, meta.title, config.numberingStyle);
      chapters.add({
        'title': title,
        'body': sanitized,
      });
    }

    String output;
    switch (config.outputFormat) {
      case CompilerOutputFormat.cleanMarkdown:
        output = _buildCleanMarkdown(chapters, config);
        break;
      case CompilerOutputFormat.manuscriptDocxHtml:
        output = _buildStandardManuscriptHtml(chapters, config, totalWords);
        break;
      case CompilerOutputFormat.printPdfHtml:
      case CompilerOutputFormat.epubEbookHtml:
        output = _buildPrintPdfHtml(chapters, config, totalWords);
        break;
    }

    final sanitizedSlug = config.bookTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    final fileName = '$sanitizedSlug${config.outputFormat.fileExtension}';

    return CompiledDocument(
      content: output,
      totalWords: totalWords,
      chapterCount: chapters.length,
      suggestedFileName: fileName,
    );
  }

  String _buildCleanMarkdown(List<Map<String, String>> chapters, CompilerConfig config) {
    final sb = StringBuffer();

    if (config.includeTitlePage) {
      sb.writeln('# ${config.bookTitle}\n');
      if (config.subtitle != null && config.subtitle!.isNotEmpty) {
        sb.writeln('### ${config.subtitle}\n');
      }
      sb.writeln('**By ${config.authorName}**\n\n---\n');
    }

    if (config.dedication != null && config.dedication!.isNotEmpty) {
      sb.writeln('*${config.dedication}*\n\n---\n');
    }

    if (config.epigraph != null && config.epigraph!.isNotEmpty) {
      sb.writeln('> ${config.epigraph}\n\n---\n');
    }

    for (final ch in chapters) {
      if (ch['title']!.isNotEmpty) {
        sb.writeln('# ${ch['title']}\n');
      }
      sb.writeln(ch['body']);
      sb.writeln('\n\n${config.sceneDividerGlyph}\n\n');
    }

    if (config.acknowledgments != null && config.acknowledgments!.isNotEmpty) {
      sb.writeln('# Acknowledgments\n');
      sb.writeln(config.acknowledgments);
      sb.writeln('\n');
    }

    if (config.aboutAuthor != null && config.aboutAuthor!.isNotEmpty) {
      sb.writeln('# About the Author\n');
      sb.writeln(config.aboutAuthor);
    }

    return sb.toString();
  }

  String _buildPrintPdfHtml(List<Map<String, String>> chapters, CompilerConfig config, int totalWords) {
    final sb = StringBuffer();

    sb.writeln('''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${config.bookTitle}</title>
<style>
  @page {
    size: 6in 9in;
    margin-top: 0.75in;
    margin-bottom: 0.75in;
  }
  @page :left {
    margin-left: 0.5in;
    margin-right: 0.75in; /* gutter */
    @top-left {
      content: "${config.bookTitle}";
      font-style: italic;
      font-size: 9pt;
      font-family: Georgia, serif;
    }
    @bottom-center {
      content: counter(page);
      font-size: 9pt;
      font-family: Georgia, serif;
    }
  }
  @page :right {
    margin-left: 0.75in; /* gutter */
    margin-right: 0.5in;
    @top-right {
      content: "${config.authorName}";
      font-style: italic;
      font-size: 9pt;
      font-family: Georgia, serif;
    }
    @bottom-center {
      content: counter(page);
      font-size: 9pt;
      font-family: Georgia, serif;
    }
  }

  body {
    font-family: Georgia, Cambria, "Times New Roman", serif;
    font-size: 11pt;
    line-height: 1.45;
    color: #111;
    margin: 0;
    padding: 20px;
  }

  .title-page {
    page-break-after: always;
    text-align: center;
    padding-top: 2.5in;
  }
  .title-page h1 {
    font-size: 26pt;
    font-weight: normal;
    letter-spacing: 1px;
    margin-bottom: 8px;
  }
  .title-page .subtitle {
    font-size: 14pt;
    font-style: italic;
    color: #555;
    margin-bottom: 30px;
  }
  .title-page .author {
    font-size: 14pt;
    letter-spacing: 0.5px;
  }

  .chapter {
    page-break-before: always;
  }
  .chapter-header {
    text-align: center;
    margin-top: 1.5in;
    margin-bottom: 0.8in;
    font-size: 18pt;
    font-weight: normal;
    letter-spacing: 0.5px;
  }

  /* Fiction Manuscript Indentation Rules */
  p {
    margin: 0;
    text-indent: 0.35in;
    text-align: justify;
  }
  /* Suppress indent on first paragraph of chapter */
  .chapter-header + p,
  h1 + p,
  h2 + p,
  h3 + p {
    text-indent: 0 !important;
  }
  /* Suppress indent after scene break */
  .scene-divider + p {
    text-indent: 0 !important;
  }

  .scene-divider {
    text-align: center;
    margin: 1.2em 0;
    text-indent: 0;
    font-size: 12pt;
    letter-spacing: 2px;
  }
</style>
</head>
<body>
''');

    // Title page
    if (config.includeTitlePage) {
      sb.writeln('''<div class="title-page">
  <h1>${config.bookTitle}</h1>
  ${config.subtitle != null && config.subtitle!.isNotEmpty ? '<div class="subtitle">${config.subtitle}</div>' : ''}
  <div class="author">${config.authorName}</div>
</div>''');
    }

    // Chapters
    for (final ch in chapters) {
      sb.writeln('<div class="chapter">');
      if (ch['title']!.isNotEmpty) {
        sb.writeln('<h2 class="chapter-header">${ch['title']}</h2>');
      }

      final htmlBody = md.markdownToHtml(
        ch['body']!,
        extensionSet: md.ExtensionSet.gitHubFlavored,
      );
      sb.writeln(htmlBody);
      sb.writeln('</div>');
    }

    sb.writeln('</body></html>');
    return sb.toString();
  }

  String _buildStandardManuscriptHtml(List<Map<String, String>> chapters, CompilerConfig config, int totalWords) {
    final sb = StringBuffer();
    final wordCountApprox = ((totalWords + 50) ~/ 100) * 100;

    sb.writeln('''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${config.bookTitle} - Manuscript</title>
<style>
  @page {
    size: 8.5in 11in;
    margin: 1in;
    @top-right {
      content: "${config.authorName} / ${config.bookTitle} / " counter(page);
      font-family: "Courier New", Courier, monospace;
      font-size: 12pt;
    }
  }
  body {
    font-family: "Courier New", Courier, monospace;
    font-size: 12pt;
    line-height: 2.0; /* double space */
    margin: 0;
    padding: 1in;
    color: black;
  }
  .header-block {
    margin-bottom: 2in;
    line-height: 1.2;
  }
  .title-block {
    text-align: center;
    margin-bottom: 2in;
  }
  p {
    margin: 0;
    text-indent: 0.5in;
  }
  .chapter-break {
    page-break-before: always;
    text-align: center;
    margin-top: 1.5in;
    margin-bottom: 1in;
  }
  .scene-break {
    text-align: center;
    text-indent: 0;
    margin: 1em 0;
  }
</style>
</head>
<body>
<div class="header-block">
  ${config.authorName}<br>
  Approx. $wordCountApprox words
</div>
<div class="title-block">
  <strong>${config.bookTitle.toUpperCase()}</strong><br>
  by<br>
  ${config.authorName}
</div>
''');

    for (final ch in chapters) {
      sb.writeln('<div class="chapter-break"><strong>${ch['title']!.toUpperCase()}</strong></div>');
      final htmlBody = md.markdownToHtml(
        ch['body']!,
        extensionSet: md.ExtensionSet.gitHubFlavored,
      );
      sb.writeln(htmlBody);
    }

    sb.writeln('</body></html>');
    return sb.toString();
  }
}
