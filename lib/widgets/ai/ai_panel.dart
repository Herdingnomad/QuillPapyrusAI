import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/ai_model_config.dart';
import 'package:quill_papyrus_ai/models/chat.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/diff_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/ai_service.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({super.key});

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _sendFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputFocusNode.onKeyEvent = _handleInputKey;
    _sendFocusNode.onKeyEvent = _handleSendKey;
    _sendFocusNode.addListener(_onSendFocusChanged);
  }

  void _onSendFocusChanged() {
    if (mounted) setState(() {});
  }

  KeyEventResult _handleInputKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _sendFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
        final activeTab = ref.read(editorProvider).activeTab;
        _handleSend(activeTab);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSendKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        final activeTab = ref.read(editorProvider).activeTab;
        _handleSend(activeTab);
        _inputFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _inputFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _sendFocusNode.removeListener(_onSendFocusChanged);
    _inputFocusNode.dispose();
    _sendFocusNode.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool immediate = false}) {
    try {
      if (_scrollController.hasClients && _scrollController.position.hasContentDimensions) {
        final target = _scrollController.position.maxScrollExtent;
        if (immediate) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AiState>(aiProvider, (previous, next) {
      if (next.messages.length != (previous?.messages.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(immediate: false));
      } else if (next.isStreaming && next.streamingBuffer != previous?.streamingBuffer) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(immediate: true));
      }
    });

    final aiState = ref.watch(aiProvider);
    final editorState = ref.watch(editorProvider);
    final activeTab = editorState.activeTab;

    return Material(
      color: GruvboxColors.bgHard,
      child: Column(
        children: [
          // Header Bar
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isVeryNarrow = headerConstraints.maxWidth < 225;
              final isUltraNarrow = headerConstraints.maxWidth < 190;

              return Container(
                height: 38,
                color: GruvboxColors.bg1,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy, color: GruvboxColors.aqua, size: 16),
                    const SizedBox(width: 4),
                    // Model Badge / Switcher (Flexible so it shrinks if pane is narrow)
                    Flexible(
                      child: InkWell(
                        onTap: () => _showModelConfigSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: GruvboxColors.bg2,
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(color: GruvboxColors.bg3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  aiState.config.modelType.shortName,
                                  style: TextStyle(
                                    color: GruvboxColors.aqua,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, color: GruvboxColors.gray, size: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // RAM / Memory Unload Button
                    if (!isUltraNarrow)
                      IconButton(
                        icon: Icon(
                          aiState.isModelLoaded ? Icons.memory : Icons.memory_outlined,
                          color: aiState.isModelLoaded ? GruvboxColors.green : GruvboxColors.gray,
                          size: 16,
                        ),
                        tooltip: aiState.isModelLoaded
                            ? 'Model in RAM (Active) — Tap to Unload & Save Battery'
                            : 'Model Unloaded (0% Battery) — Tap to Preload',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: () async {
                          if (aiState.isModelLoaded) {
                            ref.read(aiProvider.notifier).unloadModel();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GruvboxColors.bg1,
                                duration: Duration(seconds: 2),
                                content: Text('Unloaded model from RAM — 0% background battery draw', style: TextStyle(color: GruvboxColors.green)),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GruvboxColors.bg1,
                                duration: Duration(seconds: 2),
                                content: Text('Loading model into RAM...', style: TextStyle(color: GruvboxColors.aqua)),
                              ),
                            );
                            final success = await ref.read(aiProvider.notifier).loadModel();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: GruvboxColors.bg1,
                                    duration: Duration(seconds: 2),
                                    content: Text('Model loaded into RAM successfully', style: TextStyle(color: GruvboxColors.green)),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: GruvboxColors.bg1,
                                    duration: Duration(seconds: 3),
                                    content: Text('No local .gguf model found. Running in offline assistant mode.', style: TextStyle(color: GruvboxColors.yellow)),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    // New Chat Button
                    IconButton(
                      icon: Icon(Icons.add_comment_outlined, color: GruvboxColors.aqua, size: 16),
                      tooltip: 'New Chat',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () {
                        ref.read(aiProvider.notifier).startNewChat();
                      },
                    ),
                    // Chat History Button
                    if (!isVeryNarrow)
                      IconButton(
                        icon: Icon(Icons.history, color: GruvboxColors.gray, size: 16),
                        tooltip: 'Conversation History',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: () => _showChatHistorySheet(context, activeTab),
                      ),
                    // Collapse / Hide AI Panel Button
                    IconButton(
                      icon: Icon(Icons.last_page, color: GruvboxColors.gray, size: 17),
                      tooltip: 'Hide AI Panel (Ctrl+J)',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => ref.read(layoutProvider.notifier).setRightPaneVisible(false),
                    ),
                  ],
                ),
              );
            },
          ),
          Divider(color: GruvboxColors.bg3, height: 1),

          // Context & Scope Status Strip
          Builder(
            builder: (context) {
              final workspaceState = ref.watch(workspaceProvider);
              final selectedFolderUri = workspaceState.selectedFolderUri;
              final selectedFolderNode = selectedFolderUri != null
                  ? workspaceState.fileTree?.findByUri(selectedFolderUri)
                  : null;
              final isFolderScoped = selectedFolderNode != null && selectedFolderNode.isDirectory;
              final folderDisplayName = isFolderScoped ? selectedFolderNode.name : 'All Folders';

              return Container(
                color: GruvboxColors.bg2,
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                child: Row(
                  children: [
                    // Active Document indicator (if open)
                    if (activeTab != null) ...[
                      Opacity(
                        opacity: aiState.ragEnabled ? 1.0 : 0.45,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description,
                                color: aiState.ragEnabled ? GruvboxColors.blue : GruvboxColors.gray,
                                size: 12),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                activeTab.fileName,
                                style: TextStyle(
                                  color: aiState.ragEnabled ? GruvboxColors.fg : GruvboxColors.gray,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Interactive Folder Scope Pill
                    Flexible(
                      child: InkWell(
                        onTap: aiState.ragEnabled ? () => _showFolderScopePicker(context, ref) : null,
                        borderRadius: BorderRadius.circular(4.0),
                        child: Opacity(
                          opacity: aiState.ragEnabled ? 1.0 : 0.45,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: isFolderScoped && aiState.ragEnabled
                                  ? GruvboxColors.yellow.withValues(alpha: 0.15)
                                  : GruvboxColors.bgHard,
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                color: isFolderScoped && aiState.ragEnabled
                                    ? GruvboxColors.yellow
                                    : GruvboxColors.bg3,
                                width: isFolderScoped && aiState.ragEnabled ? 1.0 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFolderScoped ? Icons.folder : Icons.folder_copy_outlined,
                                  color: isFolderScoped && aiState.ragEnabled
                                      ? GruvboxColors.yellow
                                      : GruvboxColors.gray,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    !aiState.ragEnabled
                                        ? 'Scope: Disabled'
                                        : (activeTab != null ? folderDisplayName : 'Scope: $folderDisplayName'),
                                    style: TextStyle(
                                      color: isFolderScoped && aiState.ragEnabled
                                          ? GruvboxColors.yellow
                                          : (activeTab != null ? GruvboxColors.gray : GruvboxColors.fg),
                                      fontSize: 10,
                                      fontWeight: isFolderScoped && aiState.ragEnabled
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (aiState.ragEnabled) ...[
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: isFolderScoped ? GruvboxColors.yellow : GruvboxColors.gray,
                                    size: 12,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (isFolderScoped && aiState.ragEnabled) ...[
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () {
                          ref.read(workspaceProvider.notifier).clearSelectedFolder();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: GruvboxColors.bg1,
                              duration: const Duration(seconds: 1),
                              content: Text('Switched AI scope to Entire Workspace (All Folders)', style: TextStyle(color: GruvboxColors.fg)),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(Icons.close, size: 12, color: GruvboxColors.gray),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // RAG Toggle
                    InkWell(
                      onTap: () {
                        final willBeEnabled = !aiState.ragEnabled;
                        ref.read(aiProvider.notifier).toggleRag();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: GruvboxColors.bg1,
                            duration: const Duration(seconds: 1),
                            content: Text(
                              willBeEnabled
                                  ? 'RAG Enabled: AI will use workspace notes and folder scope'
                                  : 'RAG Disabled: AI will not access workspace files',
                              style: TextStyle(color: GruvboxColors.fg),
                            ),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: aiState.ragEnabled ? GruvboxColors.green : GruvboxColors.gray,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            aiState.ragEnabled ? 'RAG' : 'Off',
                            style: TextStyle(
                              color: aiState.ragEnabled ? GruvboxColors.green : GruvboxColors.gray,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Quick Action Prompt Chips
          if (activeTab != null && aiState.messages.isEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(8.0, 6.0, 8.0, 2.0),
              color: GruvboxColors.bgHard,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _quickPromptChip('🏷️ AI Frontmatter', 'Generate full YAML frontmatter for this active document with title, date, mood, tags, topics, and status.'),
                    _quickPromptChip('📑 New Template', 'Generate a complete markdown document template with YAML frontmatter and structured sections.'),
                    _quickPromptChip('📝 Summarize Note', 'Summarize this active document into key bullet points.'),
                    _quickPromptChip('⚡ Action Checklist', 'Extract an actionable checklist (- [ ] task) with clear steps from this document.'),
                    _quickPromptChip('🌾 Farm / Livestock Log', 'Create a structured farm management, livestock health, and pasture rotation log template.'),
                    _quickPromptChip('📊 Format as Table', 'Format the key data and points in this note into a clean Markdown table.'),
                    _quickPromptChip('🔗 Link Connections', 'Suggest [[Wikilinks]] and frontmatter tags to connect this note with other workspace ideas.'),
                    _quickPromptChip('✨ Polish & Phrasing', 'Review and polish the phrasing, grammar, and markdown formatting of this note.'),
                  ],
                ),
              ),
            ),

          // Chat Messages List
          Expanded(
            child: Container(
              color: GruvboxColors.bg,
              child: aiState.messages.isEmpty && !aiState.isStreaming
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.smart_toy_outlined, color: GruvboxColors.aqua, size: 44),
                            const SizedBox(height: 10),
                            Text(
                              'AI Assistant',
                              style: TextStyle(color: GruvboxColors.fg, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '100% On-Device • Directory-Aware RAG • Private & Offline',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                _samplePromptChip('🏷️ Generate document frontmatter'),
                                _samplePromptChip('☕ Daily journal entry template'),
                                _samplePromptChip('🌾 Farm & pasture rotation plan'),
                                _samplePromptChip('📝 Summarize active document'),
                                _samplePromptChip('⚡ Extract checklist from note'),
                                _samplePromptChip('🔗 How do [[Wikilinks]] work?'),
                                _samplePromptChip('📋 Create a project plan template'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : SelectionArea(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        itemCount: aiState.messages.length + (aiState.isStreaming ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < aiState.messages.length) {
                            final msg = aiState.messages[index];
                            return _buildMessageBubble(msg, activeTab);
                          } else {
                            // Streaming partial bubble
                            return _buildStreamingBubble(aiState.streamingBuffer);
                          }
                        },
                      ),
                    ),
            ),
          ),

          // Input Bar
          Container(
            color: GruvboxColors.bg1,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ask AI assistant... (Tab to Send)',
                      hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                      filled: true,
                      fillColor: GruvboxColors.bgHard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide(color: GruvboxColors.aqua, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (val) {
                      _handleSend(activeTab);
                      _inputFocusNode.requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Focus(
                  focusNode: _sendFocusNode,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _sendFocusNode.hasFocus
                          ? GruvboxColors.aqua.withValues(alpha: 0.25)
                          : Colors.transparent,
                      border: _sendFocusNode.hasFocus
                          ? Border.all(color: GruvboxColors.aqua, width: 2.0)
                          : Border.all(color: Colors.transparent, width: 2.0),
                    ),
                    child: IconButton(
                      icon: Icon(
                        aiState.isStreaming ? Icons.hourglass_top : Icons.send,
                        color: _sendFocusNode.hasFocus
                            ? GruvboxColors.aqua
                            : (aiState.isStreaming ? GruvboxColors.yellow : GruvboxColors.aqua),
                        size: 20,
                      ),
                      tooltip: 'Send (Tab to focus, Enter/Space to send)',
                      onPressed: aiState.isStreaming
                          ? null
                          : () {
                              _handleSend(activeTab);
                              _inputFocusNode.requestFocus();
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, dynamic activeTab) {
    final isUser = msg.sender == MessageSender.user;
    final cleanMsg = DiffService.repairMissingSpaces(
      DiffService.cleanSpecialTokens(msg.content),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isUser ? GruvboxColors.bg2 : GruvboxColors.bg1,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isUser ? GruvboxColors.blue.withValues(alpha: 0.4) : GruvboxColors.bg3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  size: 13,
                  color: isUser ? GruvboxColors.blue : GruvboxColors.aqua,
                ),
                const SizedBox(width: 4),
                Text(
                  isUser ? 'You' : 'AI Assistant',
                  style: TextStyle(
                    color: isUser ? GruvboxColors.blue : GruvboxColors.aqua,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            MarkdownBody(
              data: cleanMsg,
              selectable: false,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: GruvboxColors.fg, fontSize: 12, height: 1.4),
                code: TextStyle(color: GruvboxColors.orange, backgroundColor: GruvboxColors.bgHard, fontSize: 11),
                codeblockDecoration: BoxDecoration(
                  color: GruvboxColors.bgHard,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Copy button
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: cleanMsg));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: GruvboxColors.bg1,
                          duration: Duration(seconds: 1),
                          content: Text('Copied response to clipboard', style: TextStyle(color: GruvboxColors.green)),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 12, color: GruvboxColors.gray),
                        SizedBox(width: 2),
                        Text('Copy', style: TextStyle(color: GruvboxColors.gray, fontSize: 10)),
                      ],
                    ),
                  ),
                  if (activeTab != null) ...[
                    const SizedBox(width: 12),
                    // Apply as Inline Diff
                    InkWell(
                      onTap: () => _applyAsInlineDiff(cleanMsg, activeTab),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high, size: 12, color: GruvboxColors.aqua),
                          SizedBox(width: 2),
                          Text('Inline Diff', style: TextStyle(color: GruvboxColors.aqua, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Insert into document
                    InkWell(
                      onTap: () => _insertIntoDoc(cleanMsg, activeTab),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.input, size: 12, color: GruvboxColors.yellow),
                          SizedBox(width: 2),
                          Text('Insert', style: TextStyle(color: GruvboxColors.yellow, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingBubble(String buffer) {
    final cleanBuffer = DiffService.repairMissingSpaces(
      DiffService.cleanSpecialTokens(buffer),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: GruvboxColors.bg1,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: GruvboxColors.aqua.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, size: 13, color: GruvboxColors.aqua),
                SizedBox(width: 4),
                Text('AI Assistant (generating...)', style: TextStyle(color: GruvboxColors.aqua, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              cleanBuffer.isEmpty ? '...' : cleanBuffer,
              style: TextStyle(color: GruvboxColors.fg, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickPromptChip(String label, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.zero,
        label: Text(label, style: TextStyle(color: GruvboxColors.aqua, fontSize: 11)),
        backgroundColor: GruvboxColors.bg1,
        side: BorderSide(color: GruvboxColors.bg3),
        onPressed: () {
          final activeTab = ref.read(editorProvider).activeTab;
          _inputController.text = prompt;
          _handleSend(activeTab);
        },
      ),
    );
  }

  Widget _samplePromptChip(String prompt) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(prompt, style: TextStyle(color: GruvboxColors.fg, fontSize: 11)),
      backgroundColor: GruvboxColors.bg1,
      side: BorderSide(color: GruvboxColors.bg3),
      onPressed: () {
        final activeTab = ref.read(editorProvider).activeTab;
        _inputController.text = prompt;
        _handleSend(activeTab);
      },
    );
  }

  void _handleSend(dynamic activeTab) async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();

    final aiState = ref.read(aiProvider);
    final isRag = aiState.ragEnabled;

    final workspaceState = ref.read(workspaceProvider);

    List<String>? directoryFiles;
    String? scopedFolderName;
    String? docContent;
    String? docUri;

    if (isRag) {
      final selectedFolderUri = workspaceState.selectedFolderUri;
      FileNode? targetScopeNode;

      if (selectedFolderUri != null && workspaceState.fileTree != null) {
        targetScopeNode = workspaceState.fileTree!.findByUri(selectedFolderUri);
        if (targetScopeNode != null && targetScopeNode.isDirectory) {
          scopedFolderName = targetScopeNode.name;
        }
      }

      final rootScope = targetScopeNode ?? workspaceState.fileTree;
      List<FileNode> scopedMarkdownFiles = [];

      if (rootScope != null) {
        directoryFiles = [];
        void collectFiles(FileNode node) {
          final nameLower = node.name.toLowerCase();
          if (nameLower == 'models' || node.name.startsWith('.')) {
            return; // Skip models folder & hidden folders
          }
          if (!node.isDirectory) {
            final isIgnored = nameLower.startsWith('.') ||
                nameLower.endsWith('.gguf') ||
                nameLower.endsWith('.bin') ||
                nameLower.endsWith('.apk') ||
                nameLower.endsWith('.db') ||
                nameLower.endsWith('.zip') ||
                nameLower.endsWith('.tar');
            if (!isIgnored) {
              directoryFiles!.add(node.path.isNotEmpty ? node.path : node.name);
              if (nameLower.endsWith('.md') || nameLower.endsWith('.txt') || nameLower.endsWith('.markdown')) {
                scopedMarkdownFiles.add(node);
              }
            }
          }
          for (final child in node.children) {
            collectFiles(child);
          }
        }
        collectFiles(rootScope);
      }

      // When no document is actively open in the editor, preload the contents of notes
      // from the currently scoped folder (or workspace) directly into prompt context
      docContent = activeTab?.content;
      docUri = activeTab?.uri;

      if (docContent == null && scopedMarkdownFiles.isNotEmpty) {
        final storage = ref.read(safStorageServiceProvider);
        final notesBuffer = StringBuffer();
        int charsUsed = 0;
        const maxChars = 5000;

        for (final fileNode in scopedMarkdownFiles) {
          if (charsUsed >= maxChars) break;
          try {
            final content = await storage.readFile(fileNode.uri);
            final clean = FrontMatterService.stripFrontMatter(content).trim();
            if (clean.isNotEmpty) {
              final budgetRemaining = maxChars - charsUsed;
              final snippet = clean.length > budgetRemaining
                  ? '${clean.substring(0, budgetRemaining)}\n...[truncated]'
                  : clean;
              final relName = fileNode.path.isNotEmpty ? fileNode.path : fileNode.name;
              notesBuffer.writeln('--- Note: $relName ---');
              notesBuffer.writeln(snippet);
              notesBuffer.writeln();
              charsUsed += snippet.length;
            }
          } catch (_) {}
        }
        if (notesBuffer.isNotEmpty) {
          docContent = notesBuffer.toString();
        }
      }
    }

    ref.read(aiProvider.notifier).sendMessage(
      text: text,
      currentDocUri: isRag ? docUri : null,
      currentDocContent: isRag ? docContent : null,
      parentFolder: isRag ? scopedFolderName : null,
      directoryFiles: isRag ? directoryFiles : null,
    );
  }

  void _applyAsInlineDiff(String aiText, dynamic activeTab) {
    if (activeTab == null) return;
    try {
      final content = activeTab.content.toString();
      final cleanContent = DiffService.extractCleanAiContent(aiText);
      final target = DiffService.findTargetRange(
        documentContent: content,
        replacementText: cleanContent,
      );

      final proposal = DiffService.createProposal(
        originalFullText: content,
        proposedReplacement: cleanContent,
        selectionStart: target.start,
        selectionEnd: target.end,
        actionTitle: target.title,
      );

      ref.read(diffProvider.notifier).showProposal(proposal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          duration: const Duration(seconds: 1),
          content: Text('Created inline diff: ${target.title}', style: TextStyle(color: GruvboxColors.aqua)),
        ),
      );
    } catch (_) {}
  }

  void _insertIntoDoc(String aiText, dynamic activeTab) {
    if (activeTab == null) return;
    try {
      final content = activeTab.content.toString();
      final cleanAi = DiffService.repairMissingSpaces(
        DiffService.cleanSpecialTokens(aiText),
      );
      final updated = '$content\n\n$cleanAi';
      ref.read(editorProvider.notifier).updateContent(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          duration: Duration(seconds: 1),
          content: Text('Inserted into active document', style: TextStyle(color: GruvboxColors.green)),
        ),
      );
    } catch (_) {}
  }

  void _showFolderScopePicker(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.read(workspaceProvider);
    final root = workspaceState.fileTree;
    if (root == null) return;

    final folders = <FileNode>[];
    void collectDirs(FileNode node) {
      if (node.isDirectory) {
        final lower = node.name.toLowerCase();
        if (lower != 'models' && !node.name.startsWith('.')) {
          if (node.uri != root.uri) {
            folders.add(node);
          }
          for (final c in node.children) {
            collectDirs(c);
          }
        }
      }
    }
    collectDirs(root);

    final selectedFolderUri = workspaceState.selectedFolderUri;

    showModalBottomSheet(
      context: context,
      backgroundColor: GruvboxColors.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_shared, color: GruvboxColors.yellow, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select AI Working Scope',
                            style: TextStyle(color: GruvboxColors.fg, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Choose which folder the AI references when answering questions',
                            style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: GruvboxColors.gray, size: 16),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: GruvboxColors.bg3),
                const SizedBox(height: 4),

                // Option 1: Entire Workspace (All Folders)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  leading: Icon(
                    Icons.folder_copy,
                    color: selectedFolderUri == null ? GruvboxColors.yellow : GruvboxColors.gray,
                    size: 20,
                  ),
                  title: Text(
                    'Entire Workspace (All Folders)',
                    style: TextStyle(
                      color: selectedFolderUri == null ? GruvboxColors.yellow : GruvboxColors.fg,
                      fontSize: 12,
                      fontWeight: selectedFolderUri == null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'AI references notes across all folders in the workspace',
                    style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
                  ),
                  trailing: selectedFolderUri == null
                      ? Icon(Icons.check, color: GruvboxColors.yellow, size: 18)
                      : null,
                  onTap: () {
                    ref.read(workspaceProvider.notifier).clearSelectedFolder();
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GruvboxColors.bg1,
                        duration: const Duration(seconds: 1),
                        content: Text('Switched AI scope to Entire Workspace (All Folders)', style: TextStyle(color: GruvboxColors.green)),
                      ),
                    );
                  },
                ),

                // Option 2..N: Individual folders
                if (folders.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text(
                      'Specific Folders:',
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final dir = folders[index];
                        final isSelected = selectedFolderUri == dir.uri;
                        final noteCount = dir.children.where((c) => !c.isDirectory && (c.name.endsWith('.md') || c.name.endsWith('.txt'))).length;

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                          leading: Icon(
                            Icons.folder,
                            color: isSelected ? GruvboxColors.yellow : GruvboxColors.gray,
                            size: 20,
                          ),
                          title: Text(
                            dir.path.isNotEmpty ? dir.path : dir.name,
                            style: TextStyle(
                              color: isSelected ? GruvboxColors.yellow : GruvboxColors.fg,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '$noteCount markdown note${noteCount == 1 ? '' : 's'}',
                            style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check, color: GruvboxColors.yellow, size: 18)
                              : null,
                          onTap: () {
                            ref.read(workspaceProvider.notifier).selectFolder(dir.uri);
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GruvboxColors.bg1,
                                duration: const Duration(seconds: 1),
                                content: Text('Switched AI scope to "${dir.name}"', style: TextStyle(color: GruvboxColors.green)),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChatHistorySheet(BuildContext context, dynamic activeTab) {
    final aiState = ref.read(aiProvider);
    final allChats = aiState.conversations;
    final currentDocUri = activeTab?.uri;

    // Filter chats for this document vs all other workspace chats
    final docChats = currentDocUri != null
        ? allChats.where((c) => c.linkedDocUri == currentDocUri).toList()
        : <Chat>[];
    final otherChats = currentDocUri != null
        ? allChats.where((c) => c.linkedDocUri != currentDocUri).toList()
        : allChats;

    showModalBottomSheet(
      context: context,
      backgroundColor: GruvboxColors.bg1,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: GruvboxColors.aqua, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conversation History',
                      style: TextStyle(
                        color: GruvboxColors.fg,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GruvboxColors.bg2,
                      foregroundColor: GruvboxColors.aqua,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('New Chat', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      ref.read(aiProvider.notifier).startNewChat(linkedDocUri: currentDocUri);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: GruvboxColors.bg3, height: 1),
              Expanded(
                child: allChats.isEmpty
                    ? Center(
                        child: Text(
                          'No saved conversations yet.',
                          style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                        ),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (docChats.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.description, size: 13, color: GruvboxColors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Chats for ${activeTab?.fileName ?? "Document"} (${docChats.length})',
                                    style: TextStyle(
                                      color: GruvboxColors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...docChats.map((c) => _buildChatHistoryTile(sheetCtx, c, aiState.activeChatId)),
                            const SizedBox(height: 8),
                          ],
                          if (otherChats.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.folder_shared, size: 13, color: GruvboxColors.gray),
                                  const SizedBox(width: 4),
                                  Text(
                                    'All Other Conversations (${otherChats.length})',
                                    style: TextStyle(
                                      color: GruvboxColors.gray,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...otherChats.map((c) => _buildChatHistoryTile(sheetCtx, c, aiState.activeChatId)),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatHistoryTile(BuildContext sheetCtx, Chat chat, String? activeChatId) {
    final isActive = chat.id == activeChatId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      decoration: BoxDecoration(
        color: isActive ? GruvboxColors.bg2 : GruvboxColors.bgHard,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isActive ? GruvboxColors.aqua : GruvboxColors.bg3,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
        leading: Icon(
          isActive ? Icons.chat : Icons.chat_bubble_outline,
          color: isActive ? GruvboxColors.aqua : GruvboxColors.gray,
          size: 16,
        ),
        title: Text(
          chat.title,
          style: TextStyle(
            color: isActive ? GruvboxColors.aqua : GruvboxColors.fg,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Updated: ${_formatDate(chat.updatedAt)}',
          style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: GruvboxColors.red, size: 16),
          tooltip: 'Delete Chat',
          onPressed: () {
            ref.read(aiProvider.notifier).deleteChat(chat.id);
            Navigator.pop(sheetCtx);
          },
        ),
        onTap: () {
          ref.read(aiProvider.notifier).switchChat(chat.id);
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showModelConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GruvboxColors.bg1,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final aiState = ref.watch(aiProvider);
            final currentConfig = aiState.config;
            final defaultType = aiState.defaultModelType;
            final defaultPath = aiState.defaultModelPath;

            String defaultDisplayName;
            if (defaultPath != null && defaultPath.isNotEmpty) {
              final lp = defaultPath.toLowerCase();
              final base = p.basename(defaultPath);
              if (defaultType == GemmaModelType.gemma4E4B || lp.contains('4b') || lp.contains('4-e4b')) {
                defaultDisplayName = '${GemmaModelType.gemma4E4B.displayName} ($base)';
              } else if (defaultType == GemmaModelType.gemma4E2B || lp.contains('2b') || lp.contains('4-e2b')) {
                defaultDisplayName = '${GemmaModelType.gemma4E2B.displayName} ($base)';
              } else {
                defaultDisplayName = base;
              }
            } else {
              defaultDisplayName = defaultType.displayName;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: GruvboxColors.aqua),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Model Configuration',
                          style: TextStyle(color: GruvboxColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: GruvboxColors.gray, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // RAM & Battery Control Card
                  Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bgHard,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: aiState.isModelLoaded ? GruvboxColors.green : GruvboxColors.bg3,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          aiState.isModelLoaded ? Icons.check_circle : Icons.power_settings_new,
                          color: aiState.isModelLoaded ? GruvboxColors.green : GruvboxColors.gray,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                aiState.isModelLoaded ? 'Model in RAM (Active)' : 'Model Unloaded (0% Battery Draw)',
                                style: TextStyle(
                                  color: aiState.isModelLoaded ? GruvboxColors.green : GruvboxColors.fg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                aiState.isModelLoaded
                                    ? 'Unload when not in use to keep phone cool and save battery.'
                                    : 'Loads automatically when chatting or tap to preload.',
                                style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: aiState.isModelLoaded ? GruvboxColors.bg2 : GruvboxColors.aqua,
                            foregroundColor: aiState.isModelLoaded ? GruvboxColors.red : GruvboxColors.bgHard,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () async {
                            if (ref.read(aiProvider).isModelLoaded) {
                              ref.read(aiProvider.notifier).unloadModel();
                              Navigator.pop(sheetCtx);
                            } else {
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: GruvboxColors.bg1,
                                  duration: const Duration(seconds: 2),
                                  content: Text('Loading model into RAM...', style: TextStyle(color: GruvboxColors.aqua)),
                                ),
                              );
                              final success = await ref.read(aiProvider.notifier).loadModel();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: GruvboxColors.bg1,
                                      duration: const Duration(seconds: 2),
                                      content: Text('Model loaded into RAM successfully', style: TextStyle(color: GruvboxColors.green)),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: GruvboxColors.bg1,
                                      duration: const Duration(seconds: 3),
                                      content: Text('No local .gguf model found. Running in offline assistant mode.', style: TextStyle(color: GruvboxColors.yellow)),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: Text(
                            aiState.isModelLoaded ? 'Unload' : 'Load',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Current Default Model Banner Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg2,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: GruvboxColors.yellow.withValues(alpha: 0.6), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: GruvboxColors.yellow, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEFAULT MODEL (LOADED ON LAUNCH)',
                                style: TextStyle(
                                  color: GruvboxColors.yellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                defaultDisplayName,
                                style: TextStyle(
                                  color: GruvboxColors.fg0,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap "★" on any model below to select it as your default.',
                                style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Context Window Size Card
                  Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bgHard,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: GruvboxColors.bg3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.layers, color: GruvboxColors.purple, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Context Window (Memory & File Capacity)',
                              style: TextStyle(color: GruvboxColors.fg, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Controls how many tokens (notes, folder file listings, conversation history) the on-device AI can process at once.',
                          style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _contextSizeChip(sheetCtx, ref, currentConfig.contextSize, 2048, '2048', 'Compact'),
                            const SizedBox(width: 6),
                            _contextSizeChip(sheetCtx, ref, currentConfig.contextSize, 4096, '4096 ★', 'Standard'),
                            const SizedBox(width: 6),
                            _contextSizeChip(sheetCtx, ref, currentConfig.contextSize, 8192, '8192', 'Expanded'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: GruvboxColors.bg3),
                  const SizedBox(height: 8),

                  // Unified Models Section (Deduplicated)
                  FutureBuilder<List<File>>(
                    future: ref.read(aiServiceProvider).findLocalModelFiles(),
                    builder: (context, snapshot) {
                      final detected = snapshot.data ?? [];

                      // Correlate detected files with presets
                      File? file4B;
                      File? file2B;
                      final otherFiles = <File>[];

                      for (final f in detected) {
                        final lp = f.path.toLowerCase();
                        if (file4B == null && (lp.contains('4b') || lp.contains('4-e4b'))) {
                          file4B = f;
                        } else if (file2B == null && (lp.contains('2b') || lp.contains('4-e2b'))) {
                          file2B = f;
                        } else {
                          otherFiles.add(f);
                        }
                      }

                      // Include any custom model path manually browsed if not already in list
                      if (currentConfig.customModelPath != null && currentConfig.customModelPath!.isNotEmpty) {
                        final customPath = currentConfig.customModelPath!;
                        final isAlreadyInList = detected.any((f) =>
                            AiService.canonicalizePath(f.path) == AiService.canonicalizePath(customPath));
                        if (!isAlreadyInList) {
                          final f = File(customPath);
                          if (f.existsSync()) {
                            otherFiles.add(f);
                          }
                        }
                      }

                      final totalDetected = (file4B != null ? 1 : 0) + (file2B != null ? 1 : 0) + otherFiles.length;

                      bool isModelActive({required GemmaModelType modelType, String? customPath}) {
                        if (customPath != null &&
                            currentConfig.customModelPath != null &&
                            currentConfig.customModelPath!.isNotEmpty) {
                          if (AiService.canonicalizePath(currentConfig.customModelPath!) ==
                              AiService.canonicalizePath(customPath)) {
                            return true;
                          }
                        }
                        if (currentConfig.modelType == modelType) {
                          if (customPath == null ||
                              currentConfig.customModelPath == null ||
                              currentConfig.customModelPath!.isEmpty) {
                            return true;
                          }
                        }
                        return false;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                totalDetected > 0 ? Icons.check_circle : Icons.info_outline,
                                color: totalDetected > 0 ? GruvboxColors.green : GruvboxColors.gray,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                totalDetected > 0 ? 'Available Models ($totalDetected):' : 'Available Models:',
                                style: TextStyle(
                                  color: totalDetected > 0 ? GruvboxColors.green : GruvboxColors.fg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // 1. Standard Model (4B Balanced)
                          _buildModelOptionTile(
                            context: context,
                            ref: ref,
                            title: GemmaModelType.gemma4E4B.displayName,
                            subtitle: file4B != null
                                ? '${p.basename(file4B.path)} • ${(file4B.lengthSync() / (1024 * 1024)).toStringAsFixed(0)}MB'
                                : '4B parameters • Best reasoning & analysis (Requires .gguf file)',
                            isActive: isModelActive(
                              modelType: GemmaModelType.gemma4E4B,
                              customPath: file4B?.path,
                            ),
                            isDefault: ref.read(aiProvider.notifier).isDefaultModel(
                              GemmaModelType.gemma4E4B,
                              customPath: file4B?.path,
                            ),
                            onActivate: () {
                              ref.read(aiProvider.notifier).setModelConfig(
                                    currentConfig.copyWith(
                                      modelType: GemmaModelType.gemma4E4B,
                                      customModelPath: file4B?.path ?? '',
                                    ),
                                  );
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: GruvboxColors.bg1,
                                  content: Text('Activated: ${GemmaModelType.gemma4E4B.displayName}', style: TextStyle(color: GruvboxColors.green)),
                                ),
                              );
                            },
                            onSetDefault: () async {
                              await ref.read(aiProvider.notifier).setDefaultModel(
                                    modelType: GemmaModelType.gemma4E4B,
                                    customModelPath: file4B?.path,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: GruvboxColors.bg1,
                                    content: Text('Set "${GemmaModelType.gemma4E4B.displayName}" as default model', style: TextStyle(color: GruvboxColors.yellow)),
                                  ),
                                );
                              }
                            },
                          ),

                          // 2. Lightweight Model (2B Fast)
                          _buildModelOptionTile(
                            context: context,
                            ref: ref,
                            title: GemmaModelType.gemma4E2B.displayName,
                            subtitle: file2B != null
                                ? '${p.basename(file2B.path)} • ${(file2B.lengthSync() / (1024 * 1024)).toStringAsFixed(0)}MB'
                                : '2B parameters • Low RAM usage & faster inference (Requires .gguf file)',
                            isActive: isModelActive(
                              modelType: GemmaModelType.gemma4E2B,
                              customPath: file2B?.path,
                            ),
                            isDefault: ref.read(aiProvider.notifier).isDefaultModel(
                              GemmaModelType.gemma4E2B,
                              customPath: file2B?.path,
                            ),
                            onActivate: () {
                              ref.read(aiProvider.notifier).setModelConfig(
                                    currentConfig.copyWith(
                                      modelType: GemmaModelType.gemma4E2B,
                                      customModelPath: file2B?.path ?? '',
                                    ),
                                  );
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: GruvboxColors.bg1,
                                  content: Text('Activated: ${GemmaModelType.gemma4E2B.displayName}', style: TextStyle(color: GruvboxColors.green)),
                                ),
                              );
                            },
                            onSetDefault: () async {
                              await ref.read(aiProvider.notifier).setDefaultModel(
                                    modelType: GemmaModelType.gemma4E2B,
                                    customModelPath: file2B?.path,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: GruvboxColors.bg1,
                                    content: Text('Set "${GemmaModelType.gemma4E2B.displayName}" as default model', style: TextStyle(color: GruvboxColors.yellow)),
                                  ),
                                );
                              }
                            },
                          ),

                          // 3. Other custom local .gguf files
                          ...otherFiles.map((file) {
                            final fileName = p.basename(file.path);
                            final isCurrentlyActive = isModelActive(
                              modelType: GemmaModelType.customGGUF,
                              customPath: file.path,
                            );
                            final isDefault = ref.read(aiProvider.notifier).isDefaultModel(
                                  GemmaModelType.customGGUF,
                                  customPath: file.path,
                                );
                            String fileSizeMB = '0';
                            try {
                              fileSizeMB = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(0);
                            } catch (_) {}

                            return _buildModelOptionTile(
                              context: context,
                              ref: ref,
                              title: fileName,
                              subtitle: '${fileSizeMB}MB • ${file.path}',
                              isActive: isCurrentlyActive,
                              isDefault: isDefault,
                              onActivate: () {
                                ref.read(aiProvider.notifier).setModelConfig(
                                      currentConfig.copyWith(
                                        modelType: GemmaModelType.customGGUF,
                                        customModelPath: file.path,
                                      ),
                                    );
                                Navigator.pop(sheetCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: GruvboxColors.bg1,
                                    content: Text('Activated model: $fileName', style: TextStyle(color: GruvboxColors.green)),
                                  ),
                                );
                              },
                              onSetDefault: () async {
                                await ref.read(aiProvider.notifier).setDefaultModel(
                                      modelType: GemmaModelType.customGGUF,
                                      customModelPath: file.path,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: GruvboxColors.bg1,
                                      content: Text('Set "$fileName" as default model', style: TextStyle(color: GruvboxColors.yellow)),
                                    ),
                                  );
                                }
                              },
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),

                  // Button to pick a local .gguf file from device
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GruvboxColors.bg2,
                      foregroundColor: GruvboxColors.aqua,
                      minimumSize: const Size(double.infinity, 38),
                    ),
                    icon: const Icon(Icons.file_open, size: 16),
                    label: const Text('Browse / Select Custom GGUF File...'),
                    onPressed: () async {
                      try {
                        final result = await FilePickerPlatform.instance.pickFiles(
                          dialogTitle: 'Select GGUF Model File',
                          type: FileType.custom,
                          allowedExtensions: ['gguf', 'bin', 'task'],
                        );
                        if (result.isNotEmpty && result.first.path != null) {
                          final path = result.first.path!;
                          final fileName = p.basename(path);
                          ref.read(aiProvider.notifier).setModelConfig(
                                currentConfig.copyWith(
                                  modelType: GemmaModelType.customGGUF,
                                  customModelPath: path,
                                ),
                              );
                          if (context.mounted) {
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GruvboxColors.bg1,
                                content: Text('Selected GGUF: $fileName', style: TextStyle(color: GruvboxColors.green)),
                                action: SnackBarAction(
                                  label: 'SET DEFAULT',
                                  textColor: GruvboxColors.yellow,
                                  onPressed: () {
                                    ref.read(aiProvider.notifier).setDefaultModel(
                                          modelType: GemmaModelType.customGGUF,
                                          customModelPath: path,
                                        );
                                  },
                                ),
                              ),
                            );
                          }
                        }
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModelOptionTile({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDefault,
    required VoidCallback onActivate,
    required VoidCallback onSetDefault,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      decoration: BoxDecoration(
        color: isActive ? GruvboxColors.bg2 : GruvboxColors.bgHard,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isActive
              ? GruvboxColors.aqua
              : (isDefault ? GruvboxColors.yellow.withValues(alpha: 0.6) : GruvboxColors.bg3),
          width: (isActive || isDefault) ? 1.4 : 1.0,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
        leading: Icon(
          isActive
              ? Icons.radio_button_checked
              : (isDefault ? Icons.star : Icons.radio_button_unchecked),
          color: isActive
              ? GruvboxColors.aqua
              : (isDefault ? GruvboxColors.yellow : GruvboxColors.gray),
          size: 18,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? GruvboxColors.aqua : (isDefault ? GruvboxColors.yellow : GruvboxColors.fg),
            fontSize: 13,
            fontWeight: (isActive || isDefault) ? FontWeight.bold : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: GruvboxColors.aqua.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: GruvboxColors.aqua),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(color: GruvboxColors.aqua, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            if (isDefault)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: GruvboxColors.yellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: GruvboxColors.yellow),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 10, color: GruvboxColors.yellow),
                    const SizedBox(width: 2),
                    Text(
                      'DEFAULT',
                      style: TextStyle(color: GruvboxColors.yellow, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: Icon(
                isDefault ? Icons.star : Icons.star_border,
                size: 18,
                color: isDefault ? GruvboxColors.yellow : GruvboxColors.gray,
              ),
              tooltip: isDefault ? 'Current Default Model' : 'Set as Default Model',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onSetDefault,
            ),
          ],
        ),
        onTap: onActivate,
      ),
    );
  }

  Widget _contextSizeChip(BuildContext ctx, WidgetRef ref, int currentSize, int targetSize, String label, String subtitle) {
    final isSelected = currentSize == targetSize;
    return Expanded(
      child: InkWell(
        onTap: () async {
          await ref.read(aiProvider.notifier).setContextSize(targetSize);
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                backgroundColor: GruvboxColors.bg1,
                duration: const Duration(seconds: 2),
                content: Text('Context window set to $targetSize tokens (KV cache reallocated)', style: TextStyle(color: GruvboxColors.green)),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(4.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: isSelected ? GruvboxColors.purple.withValues(alpha: 0.2) : GruvboxColors.bg2,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: isSelected ? GruvboxColors.purple : GruvboxColors.bg3,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? GruvboxColors.purple : GruvboxColors.fg,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? GruvboxColors.fg : GruvboxColors.gray,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
