import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quill_papyrus_ai/models/compiler_config.dart';
import 'package:quill_papyrus_ai/models/editor_tab.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/services/compiler_service.dart';
import 'package:quill_papyrus_ai/services/pdf_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';
import 'package:quill_papyrus_ai/widgets/pdf/pdf_viewer_widget.dart';

class MockStorageService extends SafStorageService {
  final Map<String, String> files = {};

  @override
  Future<String> readFile(String uri) async {
    if (files.containsKey(uri)) return files[uri]!;
    return '# Chapter Sample\n\nSome text content.';
  }

  @override
  Future<void> writeFile(String uri, String content) async {
    files[uri] = content;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompilerService Folder & Single File Tests', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
      storage.files['/vault/Chapters/Ch1.md'] = '''---
title: The Awakening
---
# The Awakening
It was the dawn of a new era.''';
      storage.files['/vault/Chapters/Ch2.md'] = '''# The Journey
They set off down the path.''';
      storage.files['/vault/Notes/Scratch.md'] = '''# Ideas
Just some scratch notes.''';
    });

    test('Compiles only selected folder files', () async {
      final ch1 = FileNode(name: 'Ch1.md', uri: '/vault/Chapters/Ch1.md', path: '/vault/Chapters/Ch1.md', isDirectory: false);
      final ch2 = FileNode(name: 'Ch2.md', uri: '/vault/Chapters/Ch2.md', path: '/vault/Chapters/Ch2.md', isDirectory: false);

      final doc = await CompilerService.instance.compileManuscript(
        files: [ch1, ch2],
        storage: storage,
        config: const CompilerConfig(
          bookTitle: 'Chronicles',
          authorName: 'Alex Mercer',
          stripFrontmatter: true,
        ),
      );

      expect(doc.chapterCount, equals(2));
      expect(doc.totalWords, greaterThan(10));
      expect(doc.content, contains('The Awakening'));
      expect(doc.content, contains('The Journey'));
      expect(doc.content, isNot(contains('Scratch notes')));
    });

    test('Compiles single file correctly', () async {
      final ch1 = FileNode(name: 'Ch1.md', uri: '/vault/Chapters/Ch1.md', path: '/vault/Chapters/Ch1.md', isDirectory: false);

      final doc = await CompilerService.instance.compileManuscript(
        files: [ch1],
        storage: storage,
        config: const CompilerConfig(
          bookTitle: 'Single Chapter',
          authorName: 'Alex Mercer',
          stripFrontmatter: true,
        ),
      );

      expect(doc.chapterCount, equals(1));
      expect(doc.content, contains('The Awakening'));
    });
  });

  group('PdfService Text & Printable Generation', () {
    test('Generates printable document with title and author', () async {
      final docBytes = await PdfService.instance.generatePrintableDocument(
        title: 'Anthology of Voices',
        author: 'J. Nomad',
        content: '# Part I\n\nThe story began in the desert.',
      );

      expect(docBytes, isNotEmpty);
      expect(docBytes.length, greaterThan(100));
      expect(utf8.decode(docBytes.sublist(0, 4)), equals('%PDF'));
    });
  });

  group('EditorTab PDF Support Tests', () {
    test('EditorTab recognizes .pdf files and prevents dirty state', () {
      const tab = EditorTab(
        uri: '/storage/sample.pdf',
        fileName: 'sample.pdf',
        content: '/storage/sample.pdf',
        savedContent: '/storage/sample.pdf',
      );

      expect(tab.isPdf, isTrue);
      expect(tab.isDirty, isFalse);
    });

    test('EditorTab recognizes .md files as non-pdf', () {
      const tab = EditorTab(
        uri: '/storage/sample.md',
        fileName: 'sample.md',
        content: '# Note',
        savedContent: '# Note',
      );

      expect(tab.isPdf, isFalse);
    });
  });

  group('PdfViewerWidget Rendering Test', () {
    testWidgets('Renders PdfViewerWidget with PDF byte data without throwing', (tester) async {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (pw.Context ctx) => pw.Center(child: pw.Text('In-App PDF View')),
        ),
      );
      final bytes = await doc.save();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfViewerWidget(
              pdfBytes: bytes,
              fileName: 'sample_doc.pdf',
              showAppBar: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PdfViewerWidget), findsOneWidget);
    });
  });
}
