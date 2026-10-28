import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quill_papyrus_ai/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfService Tests', () {
    test('Can generate printable PDF document with title and sections', () async {
      final bytes = await PdfService.instance.generatePrintableDocument(
        title: 'The Starlight Chronicle',
        subtitle: 'Volume I',
        author: 'E. Vance',
        content: '# Chapter 1\n\nIt was a crisp autumn twilight when the signal arrived.\n\n* * *\n\nShe looked out across the valley.',
      );

      expect(bytes, isNotEmpty);
      // Verify PDF header magic bytes %PDF-
      expect(utf8.decode(bytes.sublist(0, 4)), equals('%PDF'));
    });

    test('Extracts text from a generated PDF stream', () async {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text('Reflections and morning thoughts on creative writing'),
            );
          },
        ),
      );

      final pdfBytes = await doc.save();
      final extracted = PdfService.instance.extractTextFromPdf(pdfBytes);
      expect(extracted.toLowerCase(), contains('reflections'));
      expect(extracted.toLowerCase(), contains('thoughts'));
    });
  });
}
