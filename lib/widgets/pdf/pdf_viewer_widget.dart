import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

/// Full-featured, on-device PDF viewer widget for Quill & Papyrus AI
/// Works on both Mobile (Android/iOS) and Desktop (Windows/macOS/Linux)
class PdfViewerWidget extends StatefulWidget {
  final String? filePath;
  final Uint8List? pdfBytes;
  final String fileName;
  final VoidCallback? onClose;
  final bool showAppBar;

  const PdfViewerWidget({
    super.key,
    this.filePath,
    this.pdfBytes,
    required this.fileName,
    this.onClose,
    this.showAppBar = false,
  });

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  Uint8List? _bytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdfData();
  }

  @override
  void didUpdateWidget(covariant PdfViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.pdfBytes != widget.pdfBytes) {
      _loadPdfData();
    }
  }

  Future<void> _loadPdfData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.pdfBytes != null) {
        _bytes = widget.pdfBytes;
      } else if (widget.filePath != null) {
        final file = File(widget.filePath!);
        if (await file.exists()) {
          _bytes = await file.readAsBytes();
        } else {
          _error = 'PDF file not found at path: ${widget.filePath}';
        }
      } else {
        _error = 'No PDF data or file path provided.';
      }
    } catch (e) {
      _error = 'Failed to load PDF: $e';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: GruvboxColors.bgHard,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(GruvboxColors.aqua),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Opening ${widget.fileName}...',
                style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _bytes == null) {
      return Container(
        color: GruvboxColors.bgHard,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: GruvboxColors.red),
              const SizedBox(height: 12),
              Text(
                'Unable to render PDF',
                style: TextStyle(color: GruvboxColors.fg0, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _error ?? 'Corrupted or unreadable PDF data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GruvboxColors.bg1,
                  foregroundColor: GruvboxColors.aqua,
                  side: BorderSide(color: GruvboxColors.aqua.withValues(alpha: 0.4)),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                onPressed: _loadPdfData,
              ),
            ],
          ),
        ),
      );
    }

    final viewer = Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: GruvboxColors.bgHard,
        colorScheme: ColorScheme.dark(
          primary: GruvboxColors.aqua,
          surface: GruvboxColors.bg1,
        ),
      ),
      child: PdfPreview(
        build: (PdfPageFormat format) async => _bytes!,
        useActions: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        maxPageWidth: 780,
        pdfFileName: widget.fileName,
        previewPageMargin: const EdgeInsets.all(8.0),
        loadingWidget: Center(
          child: CircularProgressIndicator(color: GruvboxColors.aqua),
        ),
        onError: (context, error) {
          return Center(
            child: Text(
              'PDF Render Error: $error',
              style: TextStyle(color: GruvboxColors.red),
            ),
          );
        },
      ),
    );

    if (!widget.showAppBar) {
      return viewer;
    }

    return Scaffold(
      backgroundColor: GruvboxColors.bgHard,
      appBar: AppBar(
        backgroundColor: GruvboxColors.bg,
        elevation: 0,
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf, color: GruvboxColors.red, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.fileName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: GruvboxColors.fg0, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      body: viewer,
    );
  }
}
