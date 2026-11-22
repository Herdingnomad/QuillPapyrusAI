import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/services/asset_resolver_service.dart';
import 'package:quill_papyrus_ai/services/wikilink_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/media_lightbox_dialog.dart';
import 'package:quill_papyrus_ai/widgets/preview/audio_player_card.dart';

/// Matches Obsidian-style media embed wikilinks: `![[image.png]]` or `![[audio.m4a]]`
class MediaWikilinkSyntax extends md.InlineSyntax {
  MediaWikilinkSyntax() : super(r'!\[\[(.*?)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final rawMatch = match[1]!;
    final element = md.Element.text('media_wikilink', rawMatch);
    parser.addNode(element);
    return true;
  }
}

/// Matches standard document wikilinks: `[[Note Name]]` or `[[Target|Display Text]]`
class WikilinkSyntax extends md.InlineSyntax {
  WikilinkSyntax() : super(r'(?<!\!)\[\[(.*?)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final rawMatch = match[1]!;
    final element = md.Element.text('wikilink', rawMatch);
    parser.addNode(element);
    return true;
  }
}

/// Builder for media embed wikilinks: `![[...]]`
class MediaWikilinkBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final FileNode? workspaceRoot;
  final String? currentDocUri;

  MediaWikilinkBuilder({
    required this.context,
    this.workspaceRoot,
    this.currentDocUri,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final raw = element.textContent;
    String target = raw;
    double? customWidth;

    if (raw.contains('|')) {
      final parts = raw.split('|');
      target = parts[0].trim();
      final widthParam = parts.length > 1 ? double.tryParse(parts[1].trim()) : null;
      if (widthParam != null && widthParam > 0) {
        customWidth = widthParam;
      }
    }

    // Resolve path using AssetResolverService
    final resolvedPath = AssetResolverService.resolvePath(
      rawPath: target,
      currentDocUri: currentDocUri,
      workspaceRoot: workspaceRoot?.uri,
      workspaceTree: workspaceRoot,
    );

    if (resolvedPath != null && AssetResolverService.isAudio(resolvedPath)) {
      return AudioPlayerCard(
        audioPath: resolvedPath,
        title: p.basename(target),
      );
    }

    if (resolvedPath != null && AssetResolverService.isImage(resolvedPath)) {
      final file = File(resolvedPath);
      final exists = file.existsSync();

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: GestureDetector(
          onTap: () {
            MediaLightboxDialog.show(
              context,
              imagePath: resolvedPath,
              title: p.basename(target),
            );
          },
          child: Container(
            width: customWidth,
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: GruvboxColors.bg1,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: GruvboxColors.bg3),
            ),
            clipBehavior: Clip.antiAlias,
            child: exists
                ? Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.file(file, fit: BoxFit.contain),
                      Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, size: 12, color: GruvboxColors.fg),
                            const SizedBox(width: 4),
                            Text(
                              p.basename(target),
                              style: TextStyle(color: GruvboxColors.fg, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, size: 28, color: GruvboxColors.red),
                        const SizedBox(height: 6),
                        Text(
                          'Media file not found: $target',
                          style: TextStyle(color: GruvboxColors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }

    // Default fallback if unknown media type
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GruvboxColors.bg3),
      ),
      child: Text(
        '![[$target]]',
        style: TextStyle(color: GruvboxColors.fg4, fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

/// Builder for standard document wikilinks: `[[...]]`
class WikilinkBuilder extends MarkdownElementBuilder {
  final Function(String target, String? resolvedUri) onTap;
  final FileNode? workspaceRoot;

  WikilinkBuilder({
    required this.onTap,
    this.workspaceRoot,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final raw = element.textContent;
    String target = raw;
    String display = raw;

    if (raw.contains('|')) {
      final parts = raw.split('|');
      target = parts[0].trim();
      display = parts.length > 1 ? parts[1].trim() : target;
    }

    final resolvedUri = workspaceRoot != null
        ? WikilinkService.resolveWikilink(target, workspaceRoot!)
        : null;
    final isResolved = resolvedUri != null || workspaceRoot == null;

    return Tooltip(
      message: isResolved
          ? 'Open $target'
          : 'File "$target" not found in workspace',
      child: InkWell(
        onTap: () => onTap(target, resolvedUri),
        child: Text(
          display,
          style: TextStyle(
            color: isResolved ? GruvboxColors.blue : GruvboxColors.red,
            decoration: TextDecoration.underline,
            decorationStyle: isResolved ? TextDecorationStyle.solid : TextDecorationStyle.dashed,
            fontSize: preferredStyle?.fontSize ?? 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
