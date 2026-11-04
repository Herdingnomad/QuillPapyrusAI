import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Service providing on-device PDF utilities:
/// 1. Digital text extraction from PDF streams
/// 2. High-resolution rasterization of PDF pages to JPG images
/// 3. Native print spooler integration and document formatting
class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  /// Extracts readable text strings from a PDF document's uncompressed or FlateDecode streams
  String extractTextFromPdf(Uint8List pdfBytes) {
    try {
      final buffer = StringBuffer();
      final length = pdfBytes.length;
      int offset = 0;

      while (offset < length) {
        // Find stream token: 'stream\r\n' or 'stream\n'
        final streamIdx = _indexOfBytes(pdfBytes, [115, 116, 114, 101, 97, 109], offset);
        if (streamIdx == -1) break;

        // Skip 'stream' and following newline
        int streamStart = streamIdx + 6;
        if (streamStart < length && pdfBytes[streamStart] == 13) streamStart++; // \r
        if (streamStart < length && pdfBytes[streamStart] == 10) streamStart++; // \n

        // Find endstream token: 'endstream'
        final endIdx = _indexOfBytes(pdfBytes, [101, 110, 100, 115, 116, 114, 101, 97, 109], streamStart);
        if (endIdx == -1) break;

        final rawStreamBytes = pdfBytes.sublist(streamStart, endIdx);

        // Attempt Flate / zlib decompression first
        List<int>? decompressed;
        try {
          decompressed = zlib.decode(rawStreamBytes);
        } catch (_) {
          // If not compressed, use raw stream
          decompressed = rawStreamBytes;
        }

        if (decompressed.isNotEmpty) {
          final streamText = _extractTextTokensFromStream(decompressed);
          if (streamText.isNotEmpty) {
            buffer.writeln(streamText);
          }
        }

        offset = endIdx + 9;
      }

      final extracted = buffer.toString().trim();
      return _cleanExtractedText(extracted);
    } catch (e) {
      debugPrint('PdfService.extractTextFromPdf error: $e');
      return '';
    }
  }

  /// Parses text from PDF graphics stream operators (Tj, TJ, ', ")
  String _extractTextTokensFromStream(List<int> streamBytes) {
    try {
      final streamStr = latin1.decode(streamBytes);
      final textBuffer = StringBuffer();

      // Match parenthesized text followed by Tj, ', or ": (Text) Tj
      final singleStringRegex = RegExp(r'\((.*?)\)\s*(?:Tj|\x27|\x22)');
      for (final match in singleStringRegex.allMatches(streamStr)) {
        final raw = match.group(1);
        if (raw != null && raw.isNotEmpty) {
          textBuffer.write('${_unescapePdfString(raw)} ');
        }
      }

      // Match array of strings for TJ operator: [(Text) 20 (More)] TJ
      final arrayRegex = RegExp(r'\[(.*?)\]\s*TJ');
      for (final match in arrayRegex.allMatches(streamStr)) {
        final inner = match.group(1);
        if (inner != null) {
          final innerTokens = RegExp(r'\((.*?)\)').allMatches(inner);
          for (final token in innerTokens) {
            final str = token.group(1);
            if (str != null && str.isNotEmpty) {
              textBuffer.write('${_unescapePdfString(str)} ');
            }
          }
          textBuffer.writeln();
        }
      }

      return textBuffer.toString().trim();
    } catch (_) {
      return '';
    }
  }

  String _unescapePdfString(String str) {
    return str
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }

  String _cleanExtractedText(String text) {
    if (text.isEmpty) return '';
    // Normalize excessive multiple spaces and empty lines
    var cleaned = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  int _indexOfBytes(Uint8List data, List<int> pattern, int start) {
    if (pattern.isEmpty || start + pattern.length > data.length) return -1;
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  /// Rasterizes PDF document pages into high-resolution JPG images.
  /// Returns a list of JPG byte buffers, one for each rendered page.
  Future<List<Uint8List>> rasterizePdfPages({
    required Uint8List pdfBytes,
    int maxPages = 4,
    double dpi = 150.0,
  }) async {
    final jpgList = <Uint8List>[];

    try {
      int pageCount = 0;
      await for (final rasterPage in Printing.raster(pdfBytes, dpi: dpi)) {
        if (pageCount >= maxPages) break;

        final pngBytes = await rasterPage.toPng();
        final decodedImage = img_lib.decodeImage(pngBytes);
        if (decodedImage != null) {
          final jpgBytes = Uint8List.fromList(
            img_lib.encodeJpg(decodedImage, quality: 90),
          );
          jpgList.add(jpgBytes);
        }
        pageCount++;
      }
    } catch (e) {
      debugPrint('PdfService.rasterizePdfPages error: $e');
    }

    return jpgList;
  }

  /// Builds a publication-standard PDF document from clean markdown or plain text
  Future<Uint8List> generatePrintableDocument({
    required String title,
    required String content,
    String? author,
    String? subtitle,
    PdfPageFormat pageFormat = PdfPageFormat.letter,
  }) async {
    final doc = pw.Document();

    // Standard manuscript styles (Courier/Serif, 1-inch margins, running headers)
    final titleStyle = pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold);
    final subtitleStyle = pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic);
    final heading1Style = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
    final heading2Style = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
    final bodyStyle = const pw.TextStyle(fontSize: 11, lineSpacing: 4);

    final lines = content.split('\n');
    final contentWidgets = <pw.Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        contentWidgets.add(pw.SizedBox(height: 8));
      } else if (trimmed.startsWith('# ')) {
        contentWidgets.add(pw.SizedBox(height: 14));
        contentWidgets.add(pw.Text(trimmed.substring(2).trim(), style: heading1Style));
        contentWidgets.add(pw.SizedBox(height: 6));
      } else if (trimmed.startsWith('## ')) {
        contentWidgets.add(pw.SizedBox(height: 10));
        contentWidgets.add(pw.Text(trimmed.substring(3).trim(), style: heading2Style));
        contentWidgets.add(pw.SizedBox(height: 4));
      } else if (trimmed.startsWith('### ')) {
        contentWidgets.add(pw.SizedBox(height: 8));
        contentWidgets.add(pw.Text(trimmed.substring(4).trim(), style: heading2Style));
        contentWidgets.add(pw.SizedBox(height: 4));
      } else if (trimmed == '* * *' || trimmed == '***' || trimmed == '---' || trimmed == '#') {
        contentWidgets.add(pw.SizedBox(height: 10));
        contentWidgets.add(
          pw.Center(
            child: pw.Text('*  *  *', style: pw.TextStyle(letterSpacing: 4, fontStyle: pw.FontStyle.italic)),
          ),
        );
        contentWidgets.add(pw.SizedBox(height: 10));
      } else {
        // Standard paragraph
        contentWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6.0),
            child: pw.Text(trimmed, style: bodyStyle),
          ),
        );
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(72), // 1-inch standard print margin
        header: (pw.Context context) {
          if (context.pageNumber == 1) return pw.Container();
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 16.0),
            child: pw.Text(
              '$title / ${author ?? 'Author'} / ${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 16.0),
            child: pw.Text(
              '${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
        build: (pw.Context context) => [
          // Title banner on page 1
          pw.Center(
            child: pw.Column(
              children: [
                pw.SizedBox(height: 20),
                pw.Text(title, style: titleStyle, textAlign: pw.TextAlign.center),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(subtitle, style: subtitleStyle, textAlign: pw.TextAlign.center),
                ],
                if (author != null && author.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text('By $author', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
                pw.SizedBox(height: 24),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 20),
              ],
            ),
          ),
          ...contentWidgets,
        ],
      ),
    );

    return doc.save();
  }

  /// Spools a printable document directly to the native system print dialog
  Future<bool> printDocument({
    required String title,
    required String content,
    String? author,
    String? subtitle,
  }) async {
    try {
      return await Printing.layoutPdf(
        name: '$title.pdf',
        onLayout: (PdfPageFormat format) async {
          return await generatePrintableDocument(
            title: title,
            content: content,
            author: author,
            subtitle: subtitle,
            pageFormat: format,
          );
        },
      );
    } catch (e) {
      debugPrint('PdfService.printDocument error: $e');
      return false;
    }
  }

  /// Spools raw PDF bytes directly to the system printer
  Future<bool> printPdfBytes({
    required Uint8List pdfBytes,
    required String documentName,
  }) async {
    try {
      return await Printing.layoutPdf(
        name: documentName,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      debugPrint('PdfService.printPdfBytes error: $e');
      return false;
    }
  }

  /// Compiles a list of image byte buffers (e.g. from camera document scanning)
  /// into a multi-page PDF document preserving resolution and aspect ratio.
  Future<Uint8List> generatePdfFromScannedImages(List<Uint8List> imageBytesList) async {
    final doc = pw.Document();

    for (final bytes in imageBytesList) {
      final img = img_lib.decodeImage(bytes);
      final double width = (img != null && img.width > 0) ? img.width.toDouble() : PdfPageFormat.a4.width;
      final double height = (img != null && img.height > 0) ? img.height.toDouble() : PdfPageFormat.a4.height;
      final pageFormat = PdfPageFormat(width, height);

      final pdfImage = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}
