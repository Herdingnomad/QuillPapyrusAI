import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/preview/wikilink_builder.dart';

class MarkdownPreview extends ConsumerWidget {
  const MarkdownPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(editorProvider).activeTab;
    final workspaceState = ref.watch(workspaceProvider);

    if (activeTab == null) {
      return Container(
        color: GruvboxColors.bg,
        child: const Center(
          child: Text(
            'No active file',
            style: TextStyle(color: GruvboxColors.gray),
          ),
        ),
      );
    }

    final content = _preprocessContent(activeTab.content);

    return Container(
      color: GruvboxColors.bg,
      child: Markdown(
        data: content.isEmpty ? '*Empty document*' : content,
        padding: const EdgeInsets.all(16.0),
        selectable: true,
        inlineSyntaxes: [WikilinkSyntax()],
        builders: {
          'wikilink': WikilinkBuilder(
            workspaceRoot: workspaceState.fileTree,
            onTap: (target, resolvedUri) {
              if (resolvedUri != null) {
                final fileName = p.basename(resolvedUri);
                ref.read(editorProvider.notifier).openFile(resolvedUri, fileName);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: GruvboxColors.bg1,
                    content: Text(
                      'Wikilink target "$target" not found in workspace.',
                      style: const TextStyle(color: GruvboxColors.red),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        },
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(
            color: GruvboxColors.green,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          h2: const TextStyle(
            color: GruvboxColors.yellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          h3: const TextStyle(
            color: GruvboxColors.aqua,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          h4: const TextStyle(
            color: GruvboxColors.orange,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          p: const TextStyle(
            color: GruvboxColors.fg,
            fontSize: 14,
            height: 1.6,
          ),
          code: const TextStyle(
            color: GruvboxColors.orange,
            backgroundColor: GruvboxColors.bg1,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
          codeblockDecoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: GruvboxColors.bg3),
          ),
          codeblockPadding: const EdgeInsets.all(12.0),
          blockquote: const TextStyle(
            color: GruvboxColors.fg2,
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
          blockquoteDecoration: const BoxDecoration(
            border: Border(left: BorderSide(color: GruvboxColors.aqua, width: 3.0)),
            color: GruvboxColors.bg1,
          ),
          blockquotePadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          a: const TextStyle(
            color: GruvboxColors.blue,
            decoration: TextDecoration.underline,
          ),
          tableHead: const TextStyle(
            color: GruvboxColors.fg0,
            fontWeight: FontWeight.bold,
          ),
          tableBody: const TextStyle(color: GruvboxColors.fg),
          tableBorder: TableBorder.all(color: GruvboxColors.bg3),
          tableHeadAlign: TextAlign.left,
          tablePadding: const EdgeInsets.all(8.0),
          listBullet: const TextStyle(color: GruvboxColors.yellow),
          checkbox: const TextStyle(color: GruvboxColors.aqua),
          horizontalRuleDecoration: const BoxDecoration(
            border: Border(top: BorderSide(color: GruvboxColors.bg3, width: 1.0)),
          ),
        ),
      ),
    );
  }

  String _preprocessContent(String content) {
    // Curated emoji shortcode replacement
    final emojis = {
      ':smile:': '😄', ':rocket:': '🚀', ':star:': '⭐', ':heart:': '❤️',
      ':fire:': '🔥', ':thumbsup:': '👍', ':thumbsdown:': '👎', ':check:': '✅',
      ':x:': '❌', ':warning:': '⚠️', ':bulb:': '💡', ':memo:': '📝',
      ':bookmark:': '🔖', ':link:': '🔗', ':calendar:': '📅', ':clock:': '🕒',
      ':lock:': '🔒', ':unlock:': '🔓', ':key:': '🔑', ':gear:': '⚙️',
      ':wrench:': '🔧', ':hammer:': '🔨', ':package:': '📦', ':folder:': '📁',
      ':file:': '📄', ':trash:': '🗑️', ':search:': '🔍', ':eye:': '👁️',
      ':bell:': '🔔', ':speaker:': '🔊', ':mute:': '🔇', ':sun:': '☀️',
      ':moon:': '🌙', ':cloud:': '☁️', ':rain:': '🌧️', ':snow:': '❄️',
      ':lightning:': '⚡', ':rainbow:': '🌈', ':wave:': '👋', ':pray:': '🙏',
      ':clap:': '👏', ':muscle:': '💪', ':brain:': '🧠', ':coffee:': '☕',
      ':pizza:': '🍕', ':tada:': '🎉', ':sparkles:': '✨', ':zap:': '⚡',
      ':100:': '💯'
    };

    String processed = content;
    emojis.forEach((shortcode, emoji) {
      processed = processed.replaceAll(shortcode, emoji);
    });

    return processed;
  }
}
