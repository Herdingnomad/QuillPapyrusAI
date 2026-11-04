import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/pdf_service.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal dialog that interfaces with the native Windows Camera application
/// in Document Scanning mode, tracks camera captures in real-time from Camera Roll,
/// and compiles captured pages into a high-resolution PDF document.
class WindowsCameraScanDialog extends ConsumerStatefulWidget {
  final String targetFolderUri;
  final List<Directory>? overrideCandidateDirs;
  final Future<bool> Function()? onLaunchCamera;
  final bool autoPoll;

  const WindowsCameraScanDialog({
    super.key,
    required this.targetFolderUri,
    this.overrideCandidateDirs,
    this.onLaunchCamera,
    this.autoPoll = true,
  });

  /// Displays the Windows Camera Document Scanner dialog and returns the created PDF URI
  static Future<String?> show(
    BuildContext context, {
    required String targetFolderUri,
    List<Directory>? overrideCandidateDirs,
    Future<bool> Function()? onLaunchCamera,
    bool autoPoll = true,
  }) {
    return showDialog<String?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => WindowsCameraScanDialog(
        targetFolderUri: targetFolderUri,
        overrideCandidateDirs: overrideCandidateDirs,
        onLaunchCamera: onLaunchCamera,
        autoPoll: autoPoll,
      ),
    );
  }

  @override
  ConsumerState<WindowsCameraScanDialog> createState() => WindowsCameraScanDialogState();
}

class WindowsCameraScanDialogState extends ConsumerState<WindowsCameraScanDialog> {
  final List<File> _capturedFiles = [];
  final Set<String> _seenPaths = {};
  List<Directory> _candidateDirs = [];
  Timer? _pollTimer;
  DateTime _baselineTime = DateTime.now();

  bool _isCompiling = false;
  bool _cameraLaunched = false;
  String? _errorMessage;
  String? _lastCapturedName;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _initScanner() {
    _baselineTime = DateTime.now().subtract(const Duration(seconds: 1));
    _candidateDirs = widget.overrideCandidateDirs ?? _resolveCameraRollDirectories();

    // Ensure the primary Camera Roll directory exists so Windows Camera saves cleanly
    for (final dir in _candidateDirs) {
      if (dir.path.endsWith('Camera Roll')) {
        try {
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
        } catch (_) {}
      }
    }

    // Catalog existing baseline files so we only capture new ones
    for (final dir in _candidateDirs) {
      if (dir.existsSync()) {
        try {
          final entities = dir.listSync(followLinks: false);
          for (final entity in entities) {
            if (entity is File) {
              _seenPaths.add(entity.path.toLowerCase());
            }
          }
        } catch (_) {}
      }
    }

    // Launch Windows Camera and start polling
    _launchCamera();
    if (widget.autoPoll) {
      _pollTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
        pollForNewCaptures();
      });
    }
  }

  List<Directory> _resolveCameraRollDirectories() {
    final dirs = <Directory>[];
    final userProfile = Platform.environment['USERPROFILE'];

    if (userProfile != null && userProfile.isNotEmpty) {
      // Standard Camera Roll
      dirs.add(Directory(p.join(userProfile, 'Pictures', 'Camera Roll')));
      // Pictures root (if Camera Roll isn't redirected)
      dirs.add(Directory(p.join(userProfile, 'Pictures')));

      // OneDrive Picture paths if active
      final oneDrive = Platform.environment['OneDrive'] ?? p.join(userProfile, 'OneDrive');
      dirs.add(Directory(p.join(oneDrive, 'Pictures', 'Camera Roll')));
      dirs.add(Directory(p.join(oneDrive, 'Pictures')));
    }

    return dirs;
  }

  Future<void> _launchCamera() async {
    setState(() => _errorMessage = null);

    if (widget.onLaunchCamera != null) {
      final success = await widget.onLaunchCamera!();
      if (mounted) setState(() => _cameraLaunched = success);
      return;
    }

    try {
      final uri = Uri.parse('microsoft.windows.camera:');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) setState(() => _cameraLaunched = true);
        return;
      }
    } catch (_) {}

    // Fallback: spawn via cmd /c start
    try {
      final result = await Process.run('cmd', ['/c', 'start', 'microsoft.windows.camera:']);
      if (mounted) {
        setState(() => _cameraLaunched = result.exitCode == 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraLaunched = false;
          _errorMessage = 'Could not launch Windows Camera automatically. Please open it from Start.';
        });
      }
    }
  }

  void pollForNewCaptures() {
    if (_isCompiling || !mounted) return;

    final imageExtensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff'};
    File? newlyFound;

    for (final dir in _candidateDirs) {
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync(followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            final lowerPath = entity.path.toLowerCase();

            if (imageExtensions.contains(ext) && !_seenPaths.contains(lowerPath)) {
              try {
                final stat = entity.statSync();
                // Check if file was modified after baseline and has finished writing (>1KB)
                if (stat.modified.isAfter(_baselineTime) && stat.size > 1024) {
                  _seenPaths.add(lowerPath);
                  newlyFound = entity;
                  break;
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      if (newlyFound != null) break;
    }

    if (newlyFound != null && mounted) {
      setState(() {
        _capturedFiles.add(newlyFound!);
        _lastCapturedName = p.basename(newlyFound.path);
        _errorMessage = null;
      });
    }
  }

  Future<void> _pickImageFromFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        dialogTitle: 'Select Document Scan Image',
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'tiff'],
      );

      if (result.isNotEmpty) {
        for (final picked in result) {
          if (picked.path != null) {
            final file = File(picked.path!);
            if (file.existsSync()) {
              _seenPaths.add(file.path.toLowerCase());
              _capturedFiles.add(file);
            }
          }
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to select image: $e');
      }
    }
  }

  void _removePage(int index) {
    if (index >= 0 && index < _capturedFiles.length) {
      setState(() {
        _capturedFiles.removeAt(index);
      });
    }
  }

  Future<void> compileAndSave() async {
    if (_capturedFiles.isEmpty || _isCompiling) return;

    setState(() {
      _isCompiling = true;
      _errorMessage = null;
    });

    try {
      // 1. Read all captured image files into byte buffers
      final imageBytesList = <Uint8List>[];
      for (final file in _capturedFiles) {
        final bytes = await file.readAsBytes();
        imageBytesList.add(bytes);
      }

      // 2. Generate multi-page PDF document
      final pdfBytes = await PdfService.instance.generatePdfFromScannedImages(imageBytesList);

      // 3. Save to target workspace folder
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'Scan_$dateSlug.pdf';

      final storage = ref.read(safStorageServiceProvider);
      final createdUri = await storage.createFile(widget.targetFolderUri, fileName);
      await storage.writeBytes(createdUri, pdfBytes);

      // 4. Refresh workspace and open the new PDF tab
      await ref.read(workspaceProvider.notifier).refreshWorkspace();
      await ref.read(editorProvider.notifier).openFile(createdUri, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document scanned & saved as $fileName (${_capturedFiles.length} pages)'),
            duration: const Duration(seconds: 4),
            backgroundColor: GruvboxColors.bg2,
          ),
        );
        Navigator.of(context).pop(createdUri);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompiling = false;
          _errorMessage = 'Failed to compile and save PDF: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: GruvboxColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GruvboxColors.bg3, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _buildGuidanceCard(),
              const SizedBox(height: 14),
              _buildPagesSection(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _buildErrorBanner(),
              ],
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: GruvboxColors.aqua.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.document_scanner_outlined, color: GruvboxColors.aqua, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Windows Camera Document Scanner',
                    style: TextStyle(
                      color: GruvboxColors.fg,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: GruvboxColors.green.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: GruvboxColors.green.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Text(
                      'Windows Native',
                      style: TextStyle(
                        color: GruvboxColors.green,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Uses Windows Camera with native Document mode edge-detection & perspective correction',
                style: TextStyle(color: GruvboxColors.fgMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: GruvboxColors.fgMuted, size: 20),
          tooltip: 'Cancel scan',
          onPressed: _isCompiling ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GruvboxColors.bg2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _cameraLaunched ? GruvboxColors.green : GruvboxColors.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_cameraLaunched ? GruvboxColors.green : GruvboxColors.yellow).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cameraLaunched
                          ? 'Windows Camera is active. Switch to "Document" mode.'
                          : 'Opening Windows Camera...',
                      style: TextStyle(
                        color: GruvboxColors.fg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'On the right-side camera bar in Windows Camera, select "Document" mode to enable real-time page boundary detection, perspective straightening, and contrast boost. Each photo you take will appear here automatically.',
                      style: TextStyle(
                        color: GruvboxColors.fg2,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              TactilePressable(
                onTap: _launchCamera,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GruvboxColors.bg3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.launch, size: 13, color: GruvboxColors.aqua),
                      const SizedBox(width: 5),
                      Text(
                        'Re-open Windows Camera',
                        style: TextStyle(color: GruvboxColors.aqua, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              TactilePressable(
                onTap: _pickImageFromFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GruvboxColors.bg3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 13, color: GruvboxColors.fg2),
                      const SizedBox(width: 5),
                      Text(
                        'Add Image from Disk...',
                        style: TextStyle(color: GruvboxColors.fg2, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagesSection() {
    if (_capturedFiles.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GruvboxColors.bg1.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GruvboxColors.bg2, strokeAlign: BorderSide.strokeAlignInside),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner, color: GruvboxColors.fgMuted.withValues(alpha: 0.7), size: 40),
            const SizedBox(height: 10),
            Text(
              'Waiting for camera captures...',
              style: TextStyle(color: GruvboxColors.fg, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Snap a page in Windows Camera or click "Add Image from Disk".\nMultiple pages will be ordered and compiled into a single PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GruvboxColors.fgMuted, fontSize: 11.5, height: 1.35),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Captured Pages (${_capturedFiles.length})',
                    style: TextStyle(
                      color: GruvboxColors.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_lastCapturedName != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '• Added $_lastCapturedName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: GruvboxColors.green, fontSize: 11.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TactilePressable(
              onTap: () => setState(() => _capturedFiles.clear()),
              child: Text(
                'Clear All',
                style: TextStyle(color: GruvboxColors.red, fontSize: 11.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _capturedFiles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final file = _capturedFiles[index];
              return _buildPageCard(file, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageCard(File file, int index) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GruvboxColors.bg3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(Icons.broken_image_outlined, color: GruvboxColors.fgMuted),
              ),
            ),
          ),
          // Top gradient overlay with page badge and remove button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Page ${index + 1}',
                      style: TextStyle(
                        color: GruvboxColors.aqua,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TactilePressable(
                    onTap: () => _removePage(index),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: GruvboxColors.red, size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom filename pill
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Text(
                p.basename(file.path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GruvboxColors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GruvboxColors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: GruvboxColors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: GruvboxColors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final pageCount = _capturedFiles.length;
    final canCompile = pageCount > 0 && !_isCompiling;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(
          pageCount == 0
              ? 'Waiting for first scan...'
              : '$pageCount ${pageCount == 1 ? 'page' : 'pages'} ready to compile',
          style: TextStyle(
            color: pageCount == 0 ? GruvboxColors.fgMuted : GruvboxColors.fg,
            fontSize: 12,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _isCompiling ? null : () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: GruvboxColors.fgMuted, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            TactilePressable(
              onTap: canCompile ? compileAndSave : null,
              child: AnimatedContainer(
                duration: AppMotion.pressFeedback,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: canCompile ? GruvboxColors.aqua : GruvboxColors.bg2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isCompiling) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Compiling PDF...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 15,
                        color: canCompile ? GruvboxColors.bgHard : GruvboxColors.fgMuted,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        pageCount <= 1 ? 'Save as PDF' : 'Compile $pageCount Pages to PDF',
                        style: TextStyle(
                          color: canCompile ? GruvboxColors.bgHard : GruvboxColors.fgMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
