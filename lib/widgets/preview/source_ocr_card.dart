import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/media_lightbox_dialog.dart';

class SourceOcrCard extends StatefulWidget {
  final String imagePath;
  final String title;
  final String transcribedText;

  const SourceOcrCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.transcribedText,
  });

  @override
  State<SourceOcrCard> createState() => _SourceOcrCardState();
}

class _SourceOcrCardState extends State<SourceOcrCard> {
  bool _isSplitMode = false;

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);
    final fileExists = file.existsSync();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GruvboxColors.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Title and "Verify OCR" Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: GruvboxColors.bg2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: GruvboxColors.bg3, width: 0.75)),
            ),
            child: Row(
              children: [
                Icon(Icons.draw_outlined, size: 16, color: GruvboxColors.yellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: GruvboxColors.fg0,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TactilePressable(
                  tooltip: _isSplitMode ? 'Exit side-by-side inspection' : 'Compare source sketch and transcribed OCR',
                  onTap: () => setState(() => _isSplitMode = !_isSplitMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isSplitMode
                          ? GruvboxColors.aqua.withValues(alpha: 0.2)
                          : GruvboxColors.bg1,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isSplitMode ? GruvboxColors.aqua : GruvboxColors.bg3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSplitMode ? Icons.vertical_split : Icons.compare_arrows,
                          size: 13,
                          color: _isSplitMode ? GruvboxColors.aqua : GruvboxColors.fg4,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isSplitMode ? 'Split OCR Active' : 'Verify OCR',
                          style: TextStyle(
                            color: _isSplitMode ? GruvboxColors.aqua : GruvboxColors.fg4,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Body: Either standard stacked or split side-by-side
          AnimatedSize(
            duration: AppMotion.fastTransition,
            curve: AppMotion.snappyEaseOut,
            child: _isSplitMode ? _buildSplitView(context, file, fileExists) : _buildStackedView(context, file, fileExists),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedView(BuildContext context, File file, bool fileExists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fileExists)
          GestureDetector(
            onTap: () => MediaLightboxDialog.show(context, imagePath: widget.imagePath, title: widget.title),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GruvboxColors.bg3),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Image.file(file, fit: BoxFit.contain),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, size: 12, color: GruvboxColors.fg),
                          const SizedBox(width: 4),
                          Text('Click to zoom', style: TextStyle(color: GruvboxColors.fg, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.transcribedText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              widget.transcribedText,
              style: TextStyle(color: GruvboxColors.fg, fontSize: 13, height: 1.5),
            ),
          ),
      ],
    );
  }

  Widget _buildSplitView(BuildContext context, File file, bool fileExists) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 540;

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: fileExists
                      ? GestureDetector(
                          onTap: () => MediaLightboxDialog.show(context, imagePath: widget.imagePath, title: widget.title),
                          child: Container(
                            height: 280,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GruvboxColors.bg3),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(file, fit: BoxFit.contain),
                          ),
                        )
                      : Text('Source image not found', style: TextStyle(color: GruvboxColors.gray)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 280,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GruvboxColors.bg3),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transcribed Text (OCR)', style: TextStyle(color: GruvboxColors.aqua, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(widget.transcribedText, style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5, height: 1.45)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return _buildStackedView(context, file, fileExists);
        }
      },
    );
  }
}
