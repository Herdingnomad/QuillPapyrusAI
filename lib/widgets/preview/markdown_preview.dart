import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/tag_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/asset_resolver_service.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/media_lightbox_dialog.dart';
import 'package:quill_papyrus_ai/widgets/preview/audio_player_card.dart';
import 'package:quill_papyrus_ai/widgets/preview/wikilink_builder.dart';

class MarkdownPreview extends ConsumerWidget {
  const MarkdownPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(editorProvider).activeTab;
    final workspaceState = ref.watch(workspaceProvider);
    final editorFont = ref.watch(layoutProvider.select((s) => s.editorFont));
    final isZenMode = ref.watch(layoutProvider.select((s) => s.isZenMode));
    final isDark = GruvboxColors.activeTheme.isDark;

    if (activeTab == null) {
      return PaperGrainSurface(
        intensity: isZenMode ? 0.0 : 0.04,
        backgroundColor: isZenMode ? Colors.transparent : GruvboxColors.bg,
        isDark: isDark,
        child: Center(
          child: Text(
            'No active file',
            style: AppTypography.uiLabel(GruvboxColors.fgMuted),
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

    final bodyStyle = editorFont.previewBodyStyle(color: GruvboxColors.fg);
    final bool useBookHeadings =
        editorFont == EditorFontFamily.literaryProse || !editorFont.isMonospace;

    TextStyle headingStyle(double size, FontWeight weight, Color color) {
      if (useBookHeadings) {
        return TextStyle(
          fontFamily: AppTypography.serifFamily,
          fontFamilyFallback: const ['Georgia', 'serif'],
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: -0.35,
          height: 1.25,
        );
      }
      return editorFont.editorStyle(
        color: color,
        fontSizeOverride: size * 0.92,
        heightOverride: 1.3,
        fontWeight: weight,
      );
    }

    final Widget previewBody = PaperGrainSurface(
      intensity: isZenMode ? 0.0 : 0.04,
      backgroundColor: isZenMode ? Colors.transparent : GruvboxColors.bg,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (frontMatter != null) _buildFrontMatterCard(context, ref, frontMatter),
          Expanded(
            child: SelectionArea(
              child: Markdown(
                data: content.isEmpty ? '*Empty manuscript*' : content,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
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
                imageBuilder: (uri, title, alt) {
                  final rawUriStr = uri.toString();
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
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        child: GestureDetector(
                          onTap: () {
                            MediaLightboxDialog.show(
                              context,
                              imagePath: resolvedPath,
                              title: title ?? alt ?? p.basename(resolvedPath),
                            );
                          },
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 420),
                            decoration: BoxDecoration(
                              color: GruvboxColors.bg1,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: GruvboxColors.subtleDivider),
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
                  h1: headingStyle(26, FontWeight.w600, GruvboxColors.fg0),
                  h1Padding: const EdgeInsets.only(top: 12, bottom: 8),
                  h2: headingStyle(20.5, FontWeight.w600, GruvboxColors.fg0),
                  h2Padding: const EdgeInsets.only(top: 10, bottom: 6),
                  h3: headingStyle(17, FontWeight.w600, GruvboxColors.fg),
                  h3Padding: const EdgeInsets.only(top: 8, bottom: 4),
                  h4: headingStyle(15, FontWeight.w600, GruvboxColors.fg2),
                  p: bodyStyle,
                  pPadding: const EdgeInsets.only(bottom: 12),
                  strong: bodyStyle.copyWith(
                    color: GruvboxColors.fg0,
                    fontWeight: FontWeight.w700,
                  ),
                  em: bodyStyle.copyWith(
                    color: GruvboxColors.fg2,
                    fontStyle: FontStyle.italic,
                  ),
                  code: AppTypography.codeMono(
                    GruvboxColors.accent,
                    fontSize: 12.5,
                    backgroundColor: GruvboxColors.bg1.withValues(alpha: 0.8),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: GruvboxColors.bgHard.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
                  ),
                  codeblockPadding: const EdgeInsets.all(14.0),
                  blockquote: bodyStyle.copyWith(
                    color: GruvboxColors.fg2,
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: GruvboxColors.accent, width: 2.5),
                    ),
                    color: GruvboxColors.bg1.withValues(alpha: 0.45),
                  ),
                  blockquotePadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
                  a: bodyStyle.copyWith(
                    color: GruvboxColors.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: GruvboxColors.accent.withValues(alpha: 0.55),
                  ),
                  tableHead: AppTypography.uiLabel(
                    GruvboxColors.fg0,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  tableBody: bodyStyle.copyWith(fontSize: 13.5),
                  tableBorder: TableBorder.all(color: GruvboxColors.subtleDivider, width: 0.75),
                  tableHeadAlign: TextAlign.left,
                  tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                  listBullet: bodyStyle.copyWith(color: GruvboxColors.accent),
                  checkbox: TextStyle(color: GruvboxColors.accent),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: GruvboxColors.subtleDivider, width: 1.0),
                    ),
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
              child: FrostedChrome(
                borderRadius: BorderRadius.circular(20),
                backgroundColor: GruvboxColors.bgGlass,
                border: Border.all(color: GruvboxColors.accent.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FountainNibMark(size: 14, color: GruvboxColors.accent),
                    const SizedBox(width: 7),
                    Text(
                      'Edit Note (Ctrl+E)',
                      style: AppTypography.uiLabel(
                        GruvboxColors.fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
      margin: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: GruvboxColors.bgHard.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.title != null) ...[
            Text(
              data.title!,
              style: AppTypography.sectionTitle(
                GruvboxColors.fg0,
                fontSize: 18,
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
                    Icon(Icons.calendar_today_outlined, size: 12.5, color: GruvboxColors.fgMuted),
                    const SizedBox(width: 5),
                    Text(
                      '${data.date != null ? "${data.date!.year.toString().padLeft(4, '0')}-${data.date!.month.toString().padLeft(2, '0')}-${data.date!.day.toString().padLeft(2, '0')}" : ""}${data.dayOfWeek != null ? " (${data.dayOfWeek})" : ""}',
                      style: AppTypography.tabularMetric(
                        GruvboxColors.fgMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (data.mood != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lens_blur_rounded, size: 13, color: GruvboxColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      data.mood!,
                      style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 11),
                    ),
                  ],
                ),
              if (data.status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (data.status!.toLowerCase().contains('complete')
                            ? GruvboxColors.green
                            : GruvboxColors.accent)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: (data.status!.toLowerCase().contains('complete')
                              ? GruvboxColors.green
                              : GruvboxColors.accent)
                          .withValues(alpha: 0.45),
                      width: 0.65,
                    ),
                  ),
                  child: Text(
                    data.status!.toUpperCase(),
                    style: AppTypography.uiLabel(
                      data.status!.toLowerCase().contains('complete')
                          ? GruvboxColors.green
                          : GruvboxColors.accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ).copyWith(letterSpacing: 0.6),
                  ),
                ),
            ],
          ),
          if (data.tags.isNotEmpty || data.topics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: GruvboxColors.subtleDivider, height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 4.0,
              children: [
                ...data.tags.map(
                  (tag) => ActionChip(
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                    padding: EdgeInsets.zero,
                    label: Text(
                      '#$tag',
                      style: AppTypography.uiLabel(GruvboxColors.accent, fontSize: 10.5),
                    ),
                    backgroundColor: GruvboxColors.bg1,
                    side: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
                    onPressed: () {
                      ref.read(activeTagFilterProvider.notifier).state = tag;
                      ref.read(layoutProvider.notifier).setLeftPaneVisible(true);
                    },
                  ),
                ),
                ...data.topics.map(
                  (topic) => ActionChip(
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                    padding: EdgeInsets.zero,
                    label: Text(
                      '@$topic',
                      style: AppTypography.uiLabel(GruvboxColors.fg2, fontSize: 10.5),
                    ),
                    backgroundColor: GruvboxColors.bg1,
                    side: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
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
        border: Border.all(color: GruvboxColors.subtleDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 20, color: GruvboxColors.red),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Image not found: $rawUriStr',
              style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
