import 'package:equatable/equatable.dart';

enum CompilerOutputFormat {
  printPdfHtml,
  epubEbookHtml,
  manuscriptDocxHtml,
  cleanMarkdown,
}

extension CompilerOutputFormatExtension on CompilerOutputFormat {
  String get label {
    switch (this) {
      case CompilerOutputFormat.printPdfHtml:
        return 'Print-Ready PDF / HTML (Mirrored Margins)';
      case CompilerOutputFormat.epubEbookHtml:
        return 'EPUB 3 eBook Package';
      case CompilerOutputFormat.manuscriptDocxHtml:
        return 'Standard Manuscript Format';
      case CompilerOutputFormat.cleanMarkdown:
        return 'Compiled Markdown (.md)';
    }
  }

  String get fileExtension {
    switch (this) {
      case CompilerOutputFormat.printPdfHtml:
      case CompilerOutputFormat.epubEbookHtml:
      case CompilerOutputFormat.manuscriptDocxHtml:
        return '.html';
      case CompilerOutputFormat.cleanMarkdown:
        return '.md';
    }
  }
}

enum ChapterNumberingStyle {
  numeric, // Chapter 1: Title
  words, // Chapter One: Title
  roman, // CHAPTER I: Title
  titleOnly, // Title
  none, // Scene break only
}

class CompilerConfig with Equatable {
  final String bookTitle;
  final String authorName;
  final String? subtitle;
  final String? dedication;
  final String? epigraph;
  final String? acknowledgments;
  final String? aboutAuthor;
  final bool includeTitlePage;
  final bool includeToc;
  final ChapterNumberingStyle numberingStyle;
  final String sceneDividerGlyph;
  final bool stripComments;
  final bool stripFrontmatter;
  final bool stripTodoMarkers;
  final CompilerOutputFormat outputFormat;

  const CompilerConfig({
    required this.bookTitle,
    required this.authorName,
    this.subtitle,
    this.dedication,
    this.epigraph,
    this.acknowledgments,
    this.aboutAuthor,
    this.includeTitlePage = true,
    this.includeToc = true,
    this.numberingStyle = ChapterNumberingStyle.words,
    this.sceneDividerGlyph = '* * *',
    this.stripComments = true,
    this.stripFrontmatter = true,
    this.stripTodoMarkers = true,
    this.outputFormat = CompilerOutputFormat.printPdfHtml,
  });

  CompilerConfig copyWith({
    String? bookTitle,
    String? authorName,
    String? subtitle,
    String? dedication,
    String? epigraph,
    String? acknowledgments,
    String? aboutAuthor,
    bool? includeTitlePage,
    bool? includeToc,
    ChapterNumberingStyle? numberingStyle,
    String? sceneDividerGlyph,
    bool? stripComments,
    bool? stripFrontmatter,
    bool? stripTodoMarkers,
    CompilerOutputFormat? outputFormat,
  }) {
    return CompilerConfig(
      bookTitle: bookTitle ?? this.bookTitle,
      authorName: authorName ?? this.authorName,
      subtitle: subtitle ?? this.subtitle,
      dedication: dedication ?? this.dedication,
      epigraph: epigraph ?? this.epigraph,
      acknowledgments: acknowledgments ?? this.acknowledgments,
      aboutAuthor: aboutAuthor ?? this.aboutAuthor,
      includeTitlePage: includeTitlePage ?? this.includeTitlePage,
      includeToc: includeToc ?? this.includeToc,
      numberingStyle: numberingStyle ?? this.numberingStyle,
      sceneDividerGlyph: sceneDividerGlyph ?? this.sceneDividerGlyph,
      stripComments: stripComments ?? this.stripComments,
      stripFrontmatter: stripFrontmatter ?? this.stripFrontmatter,
      stripTodoMarkers: stripTodoMarkers ?? this.stripTodoMarkers,
      outputFormat: outputFormat ?? this.outputFormat,
    );
  }

  @override
  List<Object?> get props => [
        bookTitle,
        authorName,
        subtitle,
        dedication,
        epigraph,
        acknowledgments,
        aboutAuthor,
        includeTitlePage,
        includeToc,
        numberingStyle,
        sceneDividerGlyph,
        stripComments,
        stripFrontmatter,
        stripTodoMarkers,
        outputFormat,
      ];
}
