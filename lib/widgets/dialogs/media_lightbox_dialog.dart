import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';

class MediaLightboxDialog extends StatefulWidget {
  final String imagePath;
  final String? title;

  const MediaLightboxDialog({
    super.key,
    required this.imagePath,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    String? title,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => MediaLightboxDialog(
        imagePath: imagePath,
        title: title,
      ),
    );
  }

  @override
  State<MediaLightboxDialog> createState() => _MediaLightboxDialogState();
}

class _MediaLightboxDialogState extends State<MediaLightboxDialog> {
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;
  int? _fileSizeBytes;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
    _loadMetadata();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if (scale != _currentScale) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _loadMetadata() {
    try {
      final file = File(widget.imagePath);
      if (file.existsSync()) {
        setState(() {
          _fileSizeBytes = file.lengthSync();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    HapticFeedback.selectionClick();
    _transformController.value = Matrix4.identity();
  }

  void _zoomIn() {
    HapticFeedback.selectionClick();
    final matrix = _transformController.value.clone();
    matrix.multiply(Matrix4.diagonal3Values(1.3, 1.3, 1.0));
    _transformController.value = matrix;
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    final matrix = _transformController.value.clone();
    matrix.multiply(Matrix4.diagonal3Values(0.75, 0.75, 1.0));
    _transformController.value = matrix;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.title ?? p.basename(widget.imagePath);
    final file = File(widget.imagePath);
    final exists = file.existsSync();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss on backdrop tap if not zoomed
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_currentScale <= 1.05) {
                  Navigator.of(context).pop();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),

          // Main Interactive Zoomable Canvas
          Center(
            child: exists
                ? InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.5,
                    maxScale: 8.0,
                    clipBehavior: Clip.none,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Hero(
                      tag: 'lightbox_${widget.imagePath}',
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => _buildErrorCard(context, 'Failed to decode image file.'),
                      ),
                    ),
                  )
                : _buildErrorCard(context, 'Image file does not exist on disk:\n${widget.imagePath}'),
          ),

          // Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: FrostedChrome(
                    blur: 16,
                    backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GruvboxColors.hairlineBorder, width: 0.75),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.image, size: 18, color: GruvboxColors.aqua),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: GruvboxColors.fg0,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_fileSizeBytes != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: GruvboxColors.bg1,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatFileSize(_fileSizeBytes!),
                                style: TextStyle(
                                  color: GruvboxColors.fg4,
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Close button
                TactilePressable(
                  tooltip: 'Close (Esc)',
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: GruvboxColors.bgHard.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: GruvboxColors.hairlineBorder, width: 0.75),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.close, size: 18, color: GruvboxColors.fg),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Floating Floating Zoom Controller Pill
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                duration: AppMotion.fastTransition,
                opacity: exists ? 1.0 : 0.0,
                child: FrostedChrome(
                  blur: 20,
                  backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GruvboxColors.hairlineBorder, width: 0.75),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TactilePressable(
                          tooltip: 'Zoom Out',
                          onTap: _zoomOut,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.zoom_out, size: 18, color: GruvboxColors.fg4),
                          ),
                        ),
                        TactilePressable(
                          tooltip: 'Reset Zoom (100%)',
                          onTap: _resetZoom,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            child: Text(
                              '${(_currentScale * 100).toInt()}%',
                              style: TextStyle(
                                color: _currentScale != 1.0 ? GruvboxColors.aqua : GruvboxColors.fg,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                        TactilePressable(
                          tooltip: 'Zoom In',
                          onTap: _zoomIn,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.zoom_in, size: 18, color: GruvboxColors.fg4),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          color: GruvboxColors.hairlineBorder,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        TactilePressable(
                          tooltip: 'Copy Path',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Clipboard.setData(ClipboardData(text: widget.imagePath));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Path copied to clipboard: ${p.basename(widget.imagePath)}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.copy_outlined, size: 17, color: GruvboxColors.fg4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GruvboxColors.bgHard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GruvboxColors.red.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 44, color: GruvboxColors.red),
          const SizedBox(height: 12),
          Text(
            'Unable to load image',
            style: TextStyle(color: GruvboxColors.fg0, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
