import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/ingest_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';

class IngestDropzoneDialog extends ConsumerStatefulWidget {
  const IngestDropzoneDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const IngestDropzoneDialog(),
    );
  }

  @override
  ConsumerState<IngestDropzoneDialog> createState() => _IngestDropzoneDialogState();
}

class _IngestDropzoneDialogState extends ConsumerState<IngestDropzoneDialog> {
  String _selectedMedium = 'Kindle Scribe';
  bool _isProcessing = false;
  String _currentStage = '';
  IngestResult? _lastResult;
  String? _errorMessage;

  Future<void> _pickAndIngestFile() async {
    if (_isProcessing) return;
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        dialogTitle: 'Select Journal Export or Photo',
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );

      if (result.isEmpty || result.first.path == null) {
        return;
      }

      final path = result.first.path!;
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _lastResult = null;
        _currentStage = 'Starting ingestion...';
      });

      final ingestRes = await ref.read(ingestServiceProvider).ingestFile(
        filePath: path,
        sourceMedium: _selectedMedium,
        onProgress: (stage) {
          if (mounted) {
            setState(() => _currentStage = stage);
          }
        },
      );

      if (!mounted) return;

      if (ingestRes != null) {
        setState(() {
          _isProcessing = false;
          _lastResult = ingestRes;
          _currentStage = 'Ingested successfully!';
        });
        HapticFeedback.mediumImpact();
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to ingest selected file.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Ingest error: $e';
        });
      }
    }
  }

  Future<void> _scanDropzone() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _lastResult = null;
      _currentStage = 'Scanning /Inbox-Dropzone...';
    });

    try {
      final results = await ref.read(ingestServiceProvider).scanAndIngestDropzone(
        onProgress: (stage) {
          if (mounted) {
            setState(() => _currentStage = stage);
          }
        },
      );

      if (!mounted) return;

      if (results.isNotEmpty) {
        setState(() {
          _isProcessing = false;
          _lastResult = results.first;
          _currentStage = 'Ingested ${results.length} item(s) from Dropzone!';
        });
        HapticFeedback.mediumImpact();
      } else {
        setState(() {
          _isProcessing = false;
          _currentStage = 'No files found in /Inbox-Dropzone folder.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Scan error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: FrostedChrome(
          blur: 24,
          backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GruvboxColors.hairlineBorder, width: 0.75),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: GruvboxColors.aqua.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.auto_awesome, color: GruvboxColors.aqua, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unified Journal Ingestion',
                            style: TextStyle(
                              color: GruvboxColors.fg0,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Gemma 4 E2B Vision & Artwork Pipeline',
                            style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TactilePressable(
                      tooltip: 'Close',
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.close, size: 20, color: GruvboxColors.gray),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Medium Selector
                Text(
                  'Source Medium',
                  style: TextStyle(color: GruvboxColors.fg4, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMediumChip('Kindle Scribe', Icons.tablet_android),
                    const SizedBox(width: 8),
                    _buildMediumChip('Paper Journal', Icons.menu_book),
                    const SizedBox(width: 8),
                    _buildMediumChip('OneNote', Icons.note_outlined),
                  ],
                ),
                const SizedBox(height: 18),

                // Ingest Action Cards
                Row(
                  children: [
                    Expanded(
                      child: TactilePressable(
                        tooltip: 'Choose an image or PDF to ingest',
                        onTap: _isProcessing ? null : _pickAndIngestFile,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg1,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GruvboxColors.aqua.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.file_upload_outlined, size: 28, color: GruvboxColors.aqua),
                              const SizedBox(height: 8),
                              Text(
                                'Select File',
                                style: TextStyle(color: GruvboxColors.fg0, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PDF or Image',
                                style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TactilePressable(
                        tooltip: 'Ingest all files inside /Inbox-Dropzone',
                        onTap: _isProcessing ? null : _scanDropzone,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg1,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GruvboxColors.yellow.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.folder_special_outlined, size: 28, color: GruvboxColors.yellow),
                              const SizedBox(height: 8),
                              Text(
                                'Scan Dropzone',
                                style: TextStyle(color: GruvboxColors.fg0, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '/Inbox-Dropzone',
                                style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Progress / Results View
                if (_isProcessing)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg1,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GruvboxColors.bg3),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: GruvboxColors.aqua),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _currentStage,
                            style: TextStyle(color: GruvboxColors.aqua, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GruvboxColors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GruvboxColors.red.withValues(alpha: 0.4)),
                    ),
                    child: Text(_errorMessage!, style: TextStyle(color: GruvboxColors.red, fontSize: 11)),
                  )
                else if (_lastResult != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GruvboxColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GruvboxColors.green.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: GruvboxColors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Successfully processed!',
                              style: TextStyle(color: GruvboxColors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Cropped artwork: ${_lastResult!.croppedArtworkPaths.length} sketch(es)\n• Transcribed notes appended to daily log',
                          style: TextStyle(color: GruvboxColors.fg2, fontSize: 11, height: 1.4),
                        ),
                        if (_lastResult!.targetDailyLogPath != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TactilePressable(
                              tooltip: 'Open Daily Log',
                              onTap: () {
                                final path = _lastResult!.targetDailyLogPath!;
                                ref.read(editorProvider.notifier).openFile(path, p.basename(path));
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: GruvboxColors.green,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'View Daily Log',
                                  style: TextStyle(color: GruvboxColors.bgHard, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediumChip(String label, IconData icon) {
    final isSelected = _selectedMedium == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMedium = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? GruvboxColors.aqua.withValues(alpha: 0.15) : GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? GruvboxColors.aqua : GruvboxColors.bg3,
              width: isSelected ? 1.25 : 0.75,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? GruvboxColors.aqua : GruvboxColors.fg4),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? GruvboxColors.aqua : GruvboxColors.fg4,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
