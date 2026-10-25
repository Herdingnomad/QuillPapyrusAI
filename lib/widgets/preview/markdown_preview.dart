import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/tag_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'dart:io';
import 'package:quill_papyrus_ai/services/asset_resolver_service.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/media_lightbox_dialog.dart';
import 'package:quill_papyrus_ai/widgets/preview/audio_player_card.dart';
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
        child: Center(
          child: Text(
            'No active file',
            style: TextStyle(color: GruvboxColors.gray),
          ),
        ),
      );
    }

    final frontMatter = FrontMatterService.parse(activeTab.content);
    final rawContent = frontMatter != null
        ? FrontMatterService.stripFrontMatter(activeTab.content)
        : activeTab.content;
    final content = _preprocessContent(rawContent);

    final isPreviewOnly = ref.watch(editorProvider).viewMode == EditorViewMode.preview;

    final Widget previewBody = Container(
      color: GruvboxColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (frontMatter != null) _buildFrontMatterCard(context, ref, frontMatter),
          Expanded(
            child: SelectionArea(
              child: Markdown(
                data: content.isEmpty ? '*Empty document*' : content,
                padding: const EdgeInsets.all(16.0),
                selectable: false,
                inlineSyntaxes: [
                  MediaWikilinkSyntax(),
                  WikilinkSyntax(),
                ],
                builders: {
                  'media_wikilink': MediaWikilinkBuilder(
                    context: context,
                    workspaceRoot: workspaceState.fileTree,
                    currentDocUri: activeTab.uri,
                  ),
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
                              style: TextStyle(color: GruvboxColors.red),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                },
                sizedImageBuilder: (config) {
                  final rawUriStr = config.uri.toString();
                  final title = config.title;
                  final alt = config.alt;
                  final resolvedPath = AssetResolverService.resolvePath(
                    rawPath: rawUriStr,
                    currentDocUri: activeTab.uri,
                    workspaceRoot: workspaceState.rootUri,
                    workspaceTree: workspaceState.fileTree,
                  );

                  if (resolvedPath != null && AssetResolverService.isAudio(resolvedPath)) {
                    return AudioPlayerCard(
                      audioPath: resolvedPath,
                      title: title ?? alt ?? p.basename(resolvedPath),
                    );
                  }

                  if (resolvedPath != null) {
                    final file = File(resolvedPath);
                    if (file.existsSync()) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            MediaLightboxDialog.show(
                              context,
                              imagePath: resolvedPath,
                              title: title ?? alt ?? p.basename(resolvedPath),
                            );
                          },
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 400),
                            decoration: BoxDecoration(
                              color: GruvboxColors.bg1,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: GruvboxColors.bg3),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
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
                                        title ?? alt ?? p.basename(resolvedPath),
                                        style: TextStyle(color: GruvboxColors.fg, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  }

                  if (rawUriStr.startsWith('http://') || rawUriStr.startsWith('https://')) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: Image.network(
                        rawUriStr,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => _buildImageError(rawUriStr),
                      ),
                    );
                  }

                  return _buildImageError(rawUriStr);
                },
                styleSheet: MarkdownStyleSheet(
                  h1: TextStyle(
                    color: GruvboxColors.green,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: TextStyle(
                    color: GruvboxColors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: TextStyle(
                    color: GruvboxColors.aqua,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  h4: TextStyle(
                    color: GruvboxColors.orange,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  p: TextStyle(
                    color: GruvboxColors.fg,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  code: TextStyle(
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
                  blockquote: TextStyle(
                    color: GruvboxColors.fg2,
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(left: BorderSide(color: GruvboxColors.aqua, width: 3.0)),
                    color: GruvboxColors.bg1,
                  ),
                  blockquotePadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  a: TextStyle(
                    color: GruvboxColors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  tableHead: TextStyle(
                    color: GruvboxColors.fg0,
                    fontWeight: FontWeight.bold,
                  ),
                  tableBody: TextStyle(color: GruvboxColors.fg),
                  tableBorder: TableBorder.all(color: GruvboxColors.bg3),
                  tableHeadAlign: TextAlign.left,
                  tablePadding: const EdgeInsets.all(8.0),
                  listBullet: TextStyle(color: GruvboxColors.yellow),
                  checkbox: TextStyle(color: GruvboxColors.aqua),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(top: BorderSide(color: GruvboxColors.bg3, width: 1.0)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!isPreviewOnly) {
      return previewBody;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: () {
              ref.read(editorProvider.notifier).setViewMode(EditorViewMode.source);
            },
            child: previewBody,
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                ref.read(editorProvider.notifier).setViewMode(EditorViewMode.source);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: GruvboxColors.bg1.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GruvboxColors.aqua.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 18, color: GruvboxColors.aqua),
                    const SizedBox(width: 6),
                    Text(
                      'Edit Note (Ctrl+E)',
                      style: TextStyle(
                        color: GruvboxColors.fg,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrontMatterCard(BuildContext context, WidgetRef ref, FrontMatterData data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: GruvboxColors.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.title != null) ...[
            Text(
              data.title!,
              style: TextStyle(
                color: GruvboxColors.fg0,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 12.0,
            runSpacing: 6.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (data.date != null || data.dayOfWeek != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: GruvboxColors.aqua),
                    const SizedBox(width: 4),
                    Text(
                      '${data.date != null ? "${data.date!.year.toString().padLeft(4, '0')}-${data.date!.month.toString().padLeft(2, '0')}-${data.date!.day.toString().padLeft(2, '0')}" : ""}${data.dayOfWeek != null ? " (${data.dayOfWeek})" : ""}',
                      style: TextStyle(color: GruvboxColors.fg4, fontSize: 11),
                    ),
                  ],
                ),
              if (data.mood != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sentiment_satisfied_alt, size: 14, color: GruvboxColors.yellow),
                    const SizedBox(width: 4),
                    Text(
                      data.mood!,
                      style: TextStyle(color: GruvboxColors.fg4, fontSize: 11),
                    ),
                  ],
                ),
              if (data.status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (data.status!.toLowerCase().contains('complete')
                            ? GruvboxColors.green
                            : GruvboxColors.orange)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: data.status!.toLowerCase().contains('complete')
                          ? GruvboxColors.green
                          : GruvboxColors.orange,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    data.status!,
                    style: TextStyle(
                      color: data.status!.toLowerCase().contains('complete')
                          ? GruvboxColors.green
                          : GruvboxColors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (data.tags.isNotEmpty || data.topics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: GruvboxColors.bg3, height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 4.0,
              children: [
                ...data.tags.map(
                  (tag) => ActionChip(
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.zero,
                    label: Text('#$tag', style: TextStyle(color: GruvboxColors.aqua, fontSize: 10)),
                    backgroundColor: GruvboxColors.bg2,
                    side: BorderSide(color: GruvboxColors.bg3),
                    onPressed: () {
                      ref.read(activeTagFilterProvider.notifier).state = tag;
                      ref.read(layoutProvider.notifier).setLeftPaneVisible(true);
                    },
                  ),
                ),
                ...data.topics.map(
                  (topic) => ActionChip(
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.zero,
                    label: Text('@$topic', style: TextStyle(color: GruvboxColors.purple, fontSize: 10)),
                    backgroundColor: GruvboxColors.bg2,
                    side: BorderSide(color: GruvboxColors.bg3),
                    onPressed: () {
                      ref.read(activeTopicFilterProvider.notifier).state = topic;
                      ref.read(layoutProvider.notifier).setLeftPaneVisible(true);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
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

  Widget _buildImageError(String rawUriStr) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: GruvboxColors.bg3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 20, color: GruvboxColors.red),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Image not found: $rawUriStr',
              style: TextStyle(color: GruvboxColors.fg4, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

