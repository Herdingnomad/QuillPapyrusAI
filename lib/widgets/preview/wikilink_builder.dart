import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/services/wikilink_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class WikilinkSyntax extends md.InlineSyntax {
  WikilinkSyntax() : super(r'\[\[(.*?)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final rawMatch = match[1]!;
    final element = md.Element.text('wikilink', rawMatch);
    parser.addNode(element);
    return true;
  }
}

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
