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
                    const Icon(Icons.smart_toy, color: GruvboxColors.aqua, size: 16),
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
                                  style: const TextStyle(
                                    color: GruvboxColors.aqua,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: GruvboxColors.gray, size: 12),
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
                              const SnackBar(
                                backgroundColor: GruvboxColors.bg1,
                                duration: Duration(seconds: 2),
                                content: Text('Unloaded model from RAM — 0% background battery draw', style: TextStyle(color: GruvboxColors.green)),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
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
                                  const SnackBar(
                                    backgroundColor: GruvboxColors.bg1,
                                    duration: Duration(seconds: 2),
                                    content: Text('Model loaded into RAM successfully', style: TextStyle(color: GruvboxColors.green)),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
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
                      icon: const Icon(Icons.add_comment_outlined, color: GruvboxColors.aqua, size: 16),
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
                        icon: const Icon(Icons.history, color: GruvboxColors.gray, size: 16),
                        tooltip: 'Conversation History',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: () => _showChatHistorySheet(context, activeTab),
                      ),
                    // Collapse / Hide AI Panel Button
                    IconButton(
                      icon: const Icon(Icons.last_page, color: GruvboxColors.gray, size: 17),
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
          const Divider(color: GruvboxColors.bg3, height: 1),

          // Context & RAG Status Strip
          Container(
            color: GruvboxColors.bg2,
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
            child: Row(
              children: [
                Icon(
                  activeTab != null ? Icons.description : Icons.folder_open,
                  color: activeTab != null ? GruvboxColors.blue : GruvboxColors.gray,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    activeTab != null ? activeTab.fileName : 'No doc attached',
                    style: const TextStyle(color: GruvboxColors.fg, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => ref.read(aiProvider.notifier).toggleRag(),
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
                            const Icon(Icons.smart_toy_outlined, color: GruvboxColors.aqua, size: 44),
                            const SizedBox(height: 10),
                            const Text(
                              'AI Assistant',
                              style: TextStyle(color: GruvboxColors.fg, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
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
                    style: const TextStyle(color: GruvboxColors.fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ask AI assistant... (Tab to Send)',
                      hintStyle: const TextStyle(color: GruvboxColors.gray, fontSize: 12),
                      filled: true,
                      fillColor: GruvboxColors.bgHard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: const BorderSide(color: GruvboxColors.aqua, width: 1.5),
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
              data: msg.content,
              selectable: false,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: GruvboxColors.fg, fontSize: 12, height: 1.4),
                code: const TextStyle(color: GruvboxColors.orange, backgroundColor: GruvboxColors.bgHard, fontSize: 11),
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
                      Clipboard.setData(ClipboardData(text: msg.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: GruvboxColors.bg1,
                          duration: Duration(seconds: 1),
                          content: Text('Copied response to clipboard', style: TextStyle(color: GruvboxColors.green)),
                        ),
                      );
                    },
                    child: const Row(
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
                      onTap: () => _applyAsInlineDiff(msg.content, activeTab),
                      child: const Row(
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
                      onTap: () => _insertIntoDoc(msg.content, activeTab),
                      child: const Row(
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
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, size: 13, color: GruvboxColors.aqua),
                SizedBox(width: 4),
                Text('AI Assistant (generating...)', style: TextStyle(color: GruvboxColors.aqua, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              buffer.isEmpty ? '...' : buffer,
              style: const TextStyle(color: GruvboxColors.fg, fontSize: 12, height: 1.4),
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
        label: Text(label, style: const TextStyle(color: GruvboxColors.aqua, fontSize: 11)),
        backgroundColor: GruvboxColors.bg1,
        side: const BorderSide(color: GruvboxColors.bg3),
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
      label: Text(prompt, style: const TextStyle(color: GruvboxColors.fg, fontSize: 11)),
      backgroundColor: GruvboxColors.bg1,
      side: const BorderSide(color: GruvboxColors.bg3),
      onPressed: () {
        final activeTab = ref.read(editorProvider).activeTab;
        _inputController.text = prompt;
        _handleSend(activeTab);
      },
    );
  }

  void _handleSend(dynamic activeTab) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();

    final workspaceState = ref.read(workspaceProvider);
    List<String>? directoryFiles;
    if (workspaceState.fileTree != null) {
      directoryFiles = [];
      void collectFiles(FileNode node) {
        final nameLower = node.name.toLowerCase();
        if (nameLower == 'models' || node.name.startsWith('.')) {
          return; // Skip models folder & hidden folders
        }
        if (!node.isDirectory) {
          if (nameLower.endsWith('.md') || nameLower.endsWith('.txt') || nameLower.endsWith('.markdown')) {
            directoryFiles!.add(node.path.isNotEmpty ? node.path : node.name);
          }
        }
        for (final child in node.children) {
          collectFiles(child);
        }
      }
      collectFiles(workspaceState.fileTree!);
    }

    ref.read(aiProvider.notifier).sendMessage(
      text: text,
      currentDocUri: activeTab?.uri,
      currentDocContent: activeTab?.content,
      parentFolder: workspaceState.rootName,
      directoryFiles: directoryFiles,
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
          content: Text('Created inline diff: ${target.title}', style: const TextStyle(color: GruvboxColors.aqua)),
        ),
      );
    } catch (_) {}
  }

  void _insertIntoDoc(String aiText, dynamic activeTab) {
    if (activeTab == null) return;
    try {
      final content = activeTab.content.toString();
      final cleanAi = DiffService.cleanSpecialTokens(aiText);
      final updated = '$content\n\n$cleanAi';
      ref.read(editorProvider.notifier).updateContent(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GruvboxColors.bg1,
          duration: Duration(seconds: 1),
          content: Text('Inserted into active document', style: TextStyle(color: GruvboxColors.green)),
        ),
      );
    } catch (_) {}
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
                  const Icon(Icons.history, color: GruvboxColors.aqua, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
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
              const Divider(color: GruvboxColors.bg3, height: 1),
              Expanded(
                child: allChats.isEmpty
                    ? const Center(
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
                                  const Icon(Icons.description, size: 13, color: GruvboxColors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Chats for ${activeTab?.fileName ?? "Document"} (${docChats.length})',
                                    style: const TextStyle(
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
                                  const Icon(Icons.folder_shared, size: 13, color: GruvboxColors.gray),
                                  const SizedBox(width: 4),
                                  Text(
                                    'All Other Conversations (${otherChats.length})',
                                    style: const TextStyle(
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
          style: const TextStyle(color: GruvboxColors.gray, fontSize: 10),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: GruvboxColors.red, size: 16),
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
    final currentConfig = ref.read(aiProvider).config;

    showModalBottomSheet(
      context: context,
      backgroundColor: GruvboxColors.bg1,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, color: GruvboxColors.aqua),
                  SizedBox(width: 8),
                  Text('On-Device Model Configuration', style: TextStyle(color: GruvboxColors.fg, fontSize: 16, fontWeight: FontWeight.bold)),
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
                    color: ref.watch(aiProvider).isModelLoaded ? GruvboxColors.green : GruvboxColors.bg3,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      ref.watch(aiProvider).isModelLoaded ? Icons.check_circle : Icons.power_settings_new,
                      color: ref.watch(aiProvider).isModelLoaded ? GruvboxColors.green : GruvboxColors.gray,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.watch(aiProvider).isModelLoaded ? 'Model in RAM (Active)' : 'Model Unloaded (0% Battery Draw)',
                            style: TextStyle(
                              color: ref.watch(aiProvider).isModelLoaded ? GruvboxColors.green : GruvboxColors.fg,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ref.watch(aiProvider).isModelLoaded
                                ? 'Unload when not in use to keep phone cool and save battery.'
                                : 'Loads automatically when chatting or tap to preload.',
                            style: const TextStyle(color: GruvboxColors.gray, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ref.watch(aiProvider).isModelLoaded ? GruvboxColors.bg2 : GruvboxColors.aqua,
                        foregroundColor: ref.watch(aiProvider).isModelLoaded ? GruvboxColors.red : GruvboxColors.bgHard,
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
                            const SnackBar(
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
                                const SnackBar(
                                  backgroundColor: GruvboxColors.bg1,
                                  duration: Duration(seconds: 2),
                                  content: Text('Model loaded into RAM successfully', style: TextStyle(color: GruvboxColors.green)),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: GruvboxColors.bg1,
                                  duration: Duration(seconds: 3),
                                  content: Text('No local .gguf model found. Running in offline assistant mode.', style: TextStyle(color: GruvboxColors.yellow)),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        ref.watch(aiProvider).isModelLoaded ? 'Unload' : 'Load',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: GruvboxColors.bg3),
              const SizedBox(height: 8),

              // Auto-detected Local Models Section
              FutureBuilder<List<File>>(
                future: ref.read(aiServiceProvider).findLocalModelFiles(),
                builder: (context, snapshot) {
                  final detected = snapshot.data ?? [];
                  if (detected.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: GruvboxColors.bgHard,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: GruvboxColors.gray, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No .gguf models automatically detected in Download or Documents. Tap "Browse / Select Custom GGUF File" below to pick your model file.',
                              style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: GruvboxColors.green, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'Detected Model Files on Device:',
                            style: TextStyle(
                              color: GruvboxColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...detected.map((file) {
                        final fileName = p.basename(file.path);
                        final isCurrentlyActive = AiService.canonicalizePath(currentConfig.customModelPath ?? '') ==
                            AiService.canonicalizePath(file.path);
                        String fileSizeMB = '0';
                        try {
                          fileSizeMB = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(0);
                        } catch (_) {}

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4.0),
                          decoration: BoxDecoration(
                            color: isCurrentlyActive ? GruvboxColors.bg2 : GruvboxColors.bgHard,
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(
                              color: isCurrentlyActive ? GruvboxColors.aqua : GruvboxColors.bg3,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
                            leading: Icon(
                              isCurrentlyActive ? Icons.radio_button_checked : Icons.file_present,
                              color: isCurrentlyActive ? GruvboxColors.aqua : GruvboxColors.yellow,
                              size: 18,
                            ),
                            title: Text(
                              fileName,
                              style: TextStyle(
                                color: isCurrentlyActive ? GruvboxColors.aqua : GruvboxColors.fg,
                                fontSize: 12,
                                fontWeight: isCurrentlyActive ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${fileSizeMB}MB • ${file.path}',
                              style: const TextStyle(color: GruvboxColors.gray, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isCurrentlyActive
                                ? const Text('ACTIVE', style: TextStyle(color: GruvboxColors.green, fontSize: 10, fontWeight: FontWeight.bold))
                                : const Text('TAP TO USE', style: TextStyle(color: GruvboxColors.aqua, fontSize: 10)),
                            onTap: () {
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
                                  content: Text('Activated model: $fileName', style: const TextStyle(color: GruvboxColors.green)),
                                ),
                              );
                            },
                          ),
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
                            content: Text('Selected GGUF: $path', style: const TextStyle(color: GruvboxColors.green)),
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
        ),
      ),
    );
  }
}
