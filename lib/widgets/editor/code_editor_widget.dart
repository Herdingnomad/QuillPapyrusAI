import 'dart:async' show Timer;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:quill_papyrus_ai/models/search_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/services/grammar_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/quick_open_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/global_search_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/snapshot_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/editor/find_replace_bar.dart';
import 'package:quill_papyrus_ai/widgets/editor/markdown_toolbar.dart';
import 'package:quill_papyrus_ai/widgets/editor/mobile_keyboard_accessory_bar.dart';
import 'package:quill_papyrus_ai/providers/find_replace_provider.dart';
import 'package:quill_papyrus_ai/providers/pacing_provider.dart';

class CodeEditorWidget extends ConsumerStatefulWidget {
  const CodeEditorWidget({super.key});

  @override
  ConsumerState<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends ConsumerState<CodeEditorWidget> {
  late MarkdownTextEditingController _controller;
  late UndoHistoryController _undoController;
  final ScrollController _scrollController = ScrollController();
  int _currentLine = 1;
  String? _lastLoadedUri;
  bool _isUpdatingFromProvider = false;
  int _lastWordCount = 0;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownTextEditingController();
    _undoController = UndoHistoryController();
    _controller.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncFromProvider();
      }
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _undoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToOffset(int offset) {
    if (!_scrollController.hasClients) return;
    final text = _controller.text;
    if (offset < 0 || offset > text.length) return;
    final textBefore = text.substring(0, offset);
    final linesBefore = '\n'.allMatches(textBefore).length;
    final targetY = (linesBefore * 22.0 - 60.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetY,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _syncFromProvider() {
    final activeTab = ref.read(editorProvider).activeTab;
    if (activeTab != null && activeTab.uri != _lastLoadedUri) {
      _lastLoadedUri = activeTab.uri;
      if (_controller.text != activeTab.content) {
        _isUpdatingFromProvider = true;
        _controller.text = activeTab.content;
        _controller.grammarIssues = GrammarService.instance.analyze(activeTab.content);
        _lastWordCount = activeTab.content.trim().isEmpty ? 0 : activeTab.content.trim().split(RegExp(r'\s+')).length;
        _isUpdatingFromProvider = false;
      }
    }
  }

  void _onTextChanged() {
    if (_isUpdatingFromProvider) return;

    final text = _controller.text;
    final selection = _controller.selection;

    // Track pacing words delta
    final currentWordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    if (_lastLoadedUri != null && _lastWordCount != currentWordCount) {
      ref.read(pacingProvider.notifier).logEditDelta(_lastWordCount, currentWordCount);
      _lastWordCount = currentWordCount;
    }

    int line = 1;
    int column = 1;

    if (selection.isValid && selection.baseOffset >= 0) {
      final safeOffset = selection.baseOffset.clamp(0, text.length);
      final textBeforeCursor = text.substring(0, safeOffset);
      final newLines = '\n'.allMatches(textBeforeCursor).length;
      line = newLines + 1;

      final lastNewLineIndex = textBeforeCursor.lastIndexOf('\n');
      column = safeOffset - (lastNewLineIndex == -1 ? 0 : lastNewLineIndex + 1) + 1;
    }

    if (_currentLine != line) {
      setState(() {
        _currentLine = line;
      });
    }

    // Refresh grammar & spelling issues as author types
    _controller.grammarIssues = GrammarService.instance.analyze(text);

    ref.read(editorProvider.notifier).updateContent(text);
    ref.read(editorProvider.notifier).updateCursor(line, column);
  }

  void _indent() {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    if (selection.isCollapsed) {
      final offset = selection.baseOffset;
      final text = _controller.text;
      final newText = text.replaceRange(offset, offset, '  ');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 2),
      );
      ref.read(editorProvider.notifier).updateContent(newText);
    } else {
      final text = _controller.text;
      final start = selection.start;
      final end = selection.end;

      final startLineIdx = text.lastIndexOf('\n', start - 1) + 1;
      final endLineIdx = text.indexOf('\n', end);
      final actualEnd = endLineIdx == -1 ? text.length : endLineIdx;

      final block = text.substring(startLineIdx, actualEnd);
      final lines = block.split('\n');
      final indentedLines = lines.map((l) => '  $l').join('\n');

      final newText = text.replaceRange(startLineIdx, actualEnd, indentedLines);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: startLineIdx,
          extentOffset: startLineIdx + indentedLines.length,
        ),
      );
      ref.read(editorProvider.notifier).updateContent(newText);
    }
  }

  void _outdent() {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final text = _controller.text;
    final start = selection.start;
    final end = selection.end;

    final startLineIdx = text.lastIndexOf('\n', start - 1) + 1;
    final endLineIdx = text.indexOf('\n', end);
    final actualEnd = endLineIdx == -1 ? text.length : endLineIdx;

    final block = text.substring(startLineIdx, actualEnd);
    final lines = block.split('\n');
    final outdentedLines = lines.map((l) {
      if (l.startsWith('  ')) return l.substring(2);
      if (l.startsWith(' ')) return l.substring(1);
      if (l.startsWith('\t')) return l.substring(1);
      return l;
    }).join('\n');

    final newText = text.replaceRange(startLineIdx, actualEnd, outdentedLines);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: startLineIdx,
        extentOffset: startLineIdx + outdentedLines.length,
      ),
    );
    ref.read(editorProvider.notifier).updateContent(newText);
  }

  void _toggleCheckboxOrQuote() {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final text = _controller.text;
    final offset = selection.baseOffset;
    final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
    final lineEndIdx = text.indexOf('\n', offset);
    final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
    final line = text.substring(lineStart, lineEnd);

    String newLine;
    if (line.startsWith('- [ ] ')) {
      newLine = line.replaceFirst('- [ ] ', '- [x] ');
    } else if (line.startsWith('- [x] ')) {
      newLine = line.replaceFirst('- [x] ', '');
    } else if (line.startsWith('- ')) {
      newLine = line.replaceFirst('- ', '- [ ] ');
    } else {
      newLine = '- [ ] $line';
    }

    final newText = text.replaceRange(lineStart, lineEnd, newLine);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + newLine.length),
    );
    ref.read(editorProvider.notifier).updateContent(newText);
  }

  Future<void> _runAiAction(String action) async {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final selectedText = _controller.text.substring(selection.start, selection.end);
    final fullText = _controller.text;

    final activeTab = ref.read(editorProvider).activeTab;
    final aiService = ref.read(aiServiceProvider);
    final aiConfig = ref.read(aiProvider).config;

    if (!aiService.isModelLoaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            content: Text('Load a Gemma 4 model first in AI Assistant (Ctrl+J)', style: TextStyle(color: GruvboxColors.orange)),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          content: Text('Generating AI edit...', style: TextStyle(color: GruvboxColors.aqua)),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      final result = await aiService.generateQuickEdit(
        action: action,
        selectedText: selectedText,
        surroundingContext: fullText,
        config: aiConfig,
        currentDocUri: activeTab?.uri,
      );

      final cleanResult = DiffService.extractCleanAiContent(result);
      final finalContent = cleanResult.isNotEmpty ? cleanResult : result;

      final newText = fullText.replaceRange(selection.start, selection.end, finalContent);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + finalContent.length),
      );
      ref.read(editorProvider.notifier).updateContent(newText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            content: Text('AI error: $e', style: TextStyle(color: GruvboxColors.red)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for tab switches, external content modifications, or grammar highlight navigation
    ref.listen<EditorState>(editorProvider, (previous, next) {
      final prevTab = previous?.activeTab;
      final nextTab = next.activeTab;
      if (nextTab != null) {
        final isUriChanged = prevTab?.uri != nextTab.uri || _lastLoadedUri != nextTab.uri;
        if (isUriChanged || _controller.text != nextTab.content) {
          _lastLoadedUri = nextTab.uri;
          if (_controller.text != nextTab.content) {
            _isUpdatingFromProvider = true;
            final currentSelection = _controller.selection;
            _controller.text = nextTab.content;
            _controller.grammarIssues = GrammarService.instance.analyze(nextTab.content);
            if (currentSelection.isValid && currentSelection.end <= nextTab.content.length) {
              _controller.selection = currentSelection;
            }
            _isUpdatingFromProvider = false;
          }
        }
      }

      // Highlight and jump to target issue/change range
      if (next.highlightVersion != previous?.highlightVersion && next.activeHighlightRange != null) {
        final range = next.activeHighlightRange!;
        _controller.activeHighlightRange = range;
        _controller.activeHighlightColor = next.activeHighlightColor;
        if (range.isValid && range.start <= _controller.text.length) {
          final clampedStart = range.start.clamp(0, _controller.text.length);
          final clampedEnd = range.end.clamp(0, _controller.text.length);
          _controller.selection = TextSelection(
            baseOffset: clampedStart,
            extentOffset: clampedEnd,
          );
          _scrollToOffset(clampedStart);
        }
        _controller.notifyListeners();

        if (next.isReplacementHighlight) {
          _highlightTimer?.cancel();
          _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
            if (mounted) {
              _controller.activeHighlightRange = null;
              _controller.activeHighlightColor = null;
              _controller.notifyListeners();
              ref.read(editorProvider.notifier).clearHighlight();
            }
          });
        }
      }
    });

    // Listen for Find & Replace in-document search matches and arrows navigation
    ref.listen<FindReplaceState>(findReplaceProvider, (previous, next) {
      if (next.isVisible && next.matches.isNotEmpty) {
        _controller.searchMatches = next.matches;
        _controller.currentSearchMatchIndex = next.currentMatchIndex;
        final match = next.currentMatch;
        if (match != null) {
          _scrollToOffset(match.startOffset);
        }
      } else {
        _controller.searchMatches = [];
        _controller.currentSearchMatchIndex = -1;
      }
      _controller.notifyListeners();
    });

    final textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      color: GruvboxColors.fg,
      height: 1.5,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          if (_undoController.value.canUndo) {
            _undoController.undo();
          } else {
            ref.read(editorProvider.notifier).undo();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          if (_undoController.value.canRedo) {
            _undoController.redo();
          } else {
            ref.read(editorProvider.notifier).redo();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
          if (_undoController.value.canRedo) {
            _undoController.redo();
          } else {
            ref.read(editorProvider.notifier).redo();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          ref.read(editorProvider.notifier).saveActiveFile();
        },
        // Quick Open: Ctrl+P / Cmd+P & Ctrl+O / Cmd+O
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          QuickOpenDialog.show(context);
        },
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          QuickOpenDialog.show(context);
        },
        // Close Active Tab: Ctrl+W
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
          ref.read(editorProvider.notifier).closeActiveTab();
        },
        // Cycle Open Tabs: Ctrl+Tab & Ctrl+Shift+Tab
        const SingleActivator(LogicalKeyboardKey.tab, control: true): () {
          ref.read(editorProvider.notifier).nextTab();
        },
        const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): () {
          ref.read(editorProvider.notifier).previousTab();
        },
        // Indent / Outdent
        const SingleActivator(LogicalKeyboardKey.tab): _indent,
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): _outdent,
        // Toggle Markdown Checklist: Ctrl+/
        const SingleActivator(LogicalKeyboardKey.slash, control: true): _toggleCheckboxOrQuote,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          ref.read(layoutProvider.notifier).toggleLeftPane();
        },
        const SingleActivator(LogicalKeyboardKey.keyJ, control: true): () {
          ref.read(layoutProvider.notifier).toggleRightPane();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          ref.read(findReplaceProvider.notifier).openFind(
                replaceMode: false,
                currentBuffer: _controller.text,
              );
        },
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () {
          ref.read(findReplaceProvider.notifier).openFind(
                replaceMode: true,
                currentBuffer: _controller.text,
              );
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): () {
          final activeTab = ref.read(editorProvider).activeTab;
          if (activeTab != null) {
            SnapshotManagerDialog.show(
              context,
              fileUri: activeTab.uri,
              fileName: activeTab.fileName,
              currentContent: _controller.text,
            );
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true): () {
          GlobalSearchDialog.show(context);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (ref.read(findReplaceProvider).isVisible) {
            ref.read(findReplaceProvider.notifier).close();
          } else if (ref.read(layoutProvider).isZenMode) {
            ref.read(layoutProvider.notifier).exitZenMode();
          }
        },
      },
      child: Builder(
        builder: (context) {
          final isZenMode = ref.watch(layoutProvider).isZenMode;
          return Container(
            color: isZenMode ? Colors.transparent : GruvboxColors.bgHard,
            child: Column(
              children: [
                // Find & Replace Docked Bar
                FindReplaceBar(
                  editorController: _controller,
                  onScrollToMatch: (start, end) {
                    _scrollToOffset(start);
                  },
                ),
                // Formatting toolbar (hidden in Zen Mode for 100% clean canvas)
                if (!isZenMode) ...[
                  MarkdownToolbar(
                    controller: _controller,
                    undoController: _undoController,
                    onSave: () {
                      ref.read(editorProvider.notifier).saveActiveFile();
                      final activeTab = ref.read(editorProvider).activeTab;
                      if (activeTab != null && context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: GruvboxColors.bg1,
                            duration: const Duration(seconds: 1),
                            content: Text(
                              'Saved ${activeTab.fileName}',
                              style: TextStyle(color: GruvboxColors.green),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  Divider(color: GruvboxColors.bg3, height: 1),
                ],

                // Editor & Gutter
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final gutterWidth = isZenMode ? 0.0 : 44.0;
                      // Calculate available width for text inside the editor padding
                      final editorWidth = (constraints.maxWidth - gutterWidth - (isZenMode ? 48.0 : 21.0)).clamp(100.0, 5000.0);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gutter (hidden in Zen Mode for clean typewriter look)
                          if (!isZenMode) ...[
                            Container(
                              width: gutterWidth,
                              color: GruvboxColors.bg1,
                              child: AnimatedBuilder(
                                animation: Listenable.merge([_scrollController, _controller]),
                                builder: (context, _) {
                                  return ClipRect(
                                    child: CustomPaint(
                                      size: Size(gutterWidth, constraints.maxHeight),
                                      painter: _LineGutterPainter(
                                        text: _controller.text,
                                        currentLine: _currentLine,
                                        scrollOffset: _scrollController.hasClients ? _scrollController.offset : 0.0,
                                        editorWidth: editorWidth,
                                        editorTextStyle: textStyle,
                                        paddingTop: 8.0,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(width: 1, color: GruvboxColors.bg3),
                          ],

                          // Text field
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: isZenMode ? 24.0 : 10.0),
                              child: TextField(
                                controller: _controller,
                                undoController: _undoController,
                                scrollController: _scrollController,
                                maxLines: null,
                                expands: true,
                                style: textStyle,
                                cursorColor: GruvboxColors.aqua,
                                spellCheckConfiguration: (!kIsWeb &&
                                        !Platform.environment.containsKey('FLUTTER_TEST') &&
                                        (Platform.isAndroid || Platform.isIOS))
                                    ? const SpellCheckConfiguration()
                                    : const SpellCheckConfiguration.disabled(),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(vertical: isZenMode ? 20.0 : 8.0),
                                ),
                                contextMenuBuilder: (context, editableTextState) {
                                  final List<ContextMenuButtonItem> buttonItems =
                                      editableTextState.contextMenuButtonItems;

                                  final selection = _controller.selection;
                                  final hasSelection = selection.isValid && !selection.isCollapsed;

                                  if (hasSelection) {
                                    buttonItems.addAll([
                                      ContextMenuButtonItem(
                                        label: '🪄 Fix Grammar',
                                        onPressed: () {
                                          ContextMenuController.removeAny();
                                          _runAiAction('grammar');
                                        },
                                      ),
                                      ContextMenuButtonItem(
                                        label: '📝 Summarize',
                                        onPressed: () {
                                          ContextMenuController.removeAny();
                                          _runAiAction('summarize');
                                        },
                                      ),
                                      ContextMenuButtonItem(
                                        label: '💡 Expand',
                                        onPressed: () {
                                          ContextMenuController.removeAny();
                                          _runAiAction('expand');
                                        },
                                      ),
                                      ContextMenuButtonItem(
                                        label: '📋 Action Items',
                                        onPressed: () {
                                          ContextMenuController.removeAny();
                                          _runAiAction('action_items');
                                        },
                                      ),
                                    ]);
                                  }

                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors: editableTextState.contextMenuAnchors,
                                    buttonItems: buttonItems,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Docked Mobile Keyboard Accessory Bar on mobile / narrow screens
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobileDevice = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isNarrowScreen = screenWidth < 650;
                    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

                    if (!isZenMode && (isMobileDevice || isNarrowScreen || isKeyboardVisible)) {
                      return MobileKeyboardAccessoryBar(
                        controller: _controller,
                        undoController: _undoController,
                        onDismissKeyboard: isKeyboardVisible
                            ? () => FocusScope.of(context).unfocus()
                            : null,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter that precisely measures line wrap heights and aligns line numbers
/// with the exact vertical baseline of each paragraph and scroll position.
class _LineGutterPainter extends CustomPainter {
  final String text;
  final int currentLine;
  final double scrollOffset;
  final double editorWidth;
  final TextStyle editorTextStyle;
  final double paddingTop;

  _LineGutterPainter({
    required this.text,
    required this.currentLine,
    required this.scrollOffset,
    required this.editorWidth,
    required this.editorTextStyle,
    this.paddingTop = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lines = text.split('\n');
    double currentY = paddingTop - scrollOffset;

    final normalStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: GruvboxColors.gray,
      height: 1.5,
    );

    final activeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: GruvboxColors.yellow,
      fontWeight: FontWeight.bold,
      height: 1.5,
    );

    for (int i = 0; i < lines.length; i++) {
      final lineText = lines[i];
      final lineNum = i + 1;
      final isCurrent = lineNum == currentLine;

      // Measure height of this line taking soft wraps into account
      final measurePainter = TextPainter(
        text: TextSpan(text: lineText.isEmpty ? ' ' : lineText, style: editorTextStyle),
        textDirection: TextDirection.ltr,
      );
      measurePainter.layout(maxWidth: editorWidth > 0 ? editorWidth : 500);
      final lineHeight = measurePainter.height;

      // Only draw if within visible viewport bounds (with small buffer)
      if (currentY + lineHeight >= -20 && currentY <= size.height + 20) {
        final numPainter = TextPainter(
          text: TextSpan(
            text: lineNum.toString(),
            style: isCurrent ? activeStyle : normalStyle,
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
        );
        numPainter.layout(maxWidth: size.width - 6);
        numPainter.paint(
          canvas,
          Offset(size.width - 6 - numPainter.width, currentY),
        );
      }

      currentY += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant _LineGutterPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.currentLine != currentLine ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.editorWidth != editorWidth;
  }
}

class _StyleInterval {
  final int start;
  final int end;
  final TextStyle style;
  _StyleInterval(this.start, this.end, this.style);
}

class _GrammarInterval {
  final int start;
  final int end;
  final GrammarIssue issue;
  _GrammarInterval(this.start, this.end, this.issue);
}

class _HighlightInterval {
  final int start;
  final int end;
  final Color color;
  _HighlightInterval(this.start, this.end, this.color);
}

class _SearchMatchInterval {
  final int start;
  final int end;
  final bool isCurrent;
  _SearchMatchInterval(this.start, this.end, this.isCurrent);
}

class MarkdownTextEditingController extends TextEditingController {
  List<GrammarIssue> grammarIssues = [];
  List<SearchMatch> searchMatches = [];
  int currentSearchMatchIndex = -1;
  TextRange? activeHighlightRange;
  Color? activeHighlightColor;

  static final RegExp _markdownRegex = RegExp(
    r'(^#{1,6}\s+.*$|\*\*.*?\*\*|\*.*?\*|`.*?`|\[\[.*?\]\]|^>.*$|^\s*-\s+.*$|\[.*?\]\(.*?\)|^-{3,}$)',
    multiLine: true,
  );

  TextStyle _getMarkdownStyle(String match, TextStyle? baseStyle) {
    TextStyle style = baseStyle ?? TextStyle(color: GruvboxColors.fg);
    if (match.startsWith('#')) {
      return style.copyWith(
        color: GruvboxColors.green,
        fontWeight: FontWeight.bold,
      );
    } else if (match.startsWith('**') && match.endsWith('**')) {
      return style.copyWith(
        color: GruvboxColors.fg0,
        fontWeight: FontWeight.bold,
      );
    } else if (match.startsWith('*') && match.endsWith('*')) {
      return style.copyWith(
        color: GruvboxColors.fg2,
        fontStyle: FontStyle.italic,
      );
    } else if (match.startsWith('`') && match.endsWith('`')) {
      return style.copyWith(
        color: GruvboxColors.orange,
        backgroundColor: GruvboxColors.bg1,
      );
    } else if (match.startsWith('[[') && match.endsWith(']]')) {
      return style.copyWith(
        color: GruvboxColors.blue,
        decoration: TextDecoration.underline,
      );
    } else if (match.startsWith('>')) {
      return style.copyWith(color: GruvboxColors.aqua);
    } else if (match.trimLeft().startsWith('-') && !match.startsWith('---')) {
      return style.copyWith(color: GruvboxColors.yellow);
    } else if (match.startsWith('[') && match.contains('](')) {
      return style.copyWith(
        color: GruvboxColors.blue,
        decoration: TextDecoration.underline,
      );
    } else if (match.startsWith('---')) {
      return style.copyWith(color: GruvboxColors.gray);
    }
    return style;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String currentText = text;
    if (currentText.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final Set<int> boundaries = {0, currentText.length};

    final List<_StyleInterval> mdIntervals = [];
    for (final match in _markdownRegex.allMatches(currentText)) {
      boundaries.add(match.start);
      boundaries.add(match.end);
      mdIntervals.add(_StyleInterval(match.start, match.end, _getMarkdownStyle(match[0]!, style)));
    }

    final List<_GrammarInterval> issueIntervals = [];
    for (final issue in grammarIssues) {
      final start = issue.offset.clamp(0, currentText.length);
      final end = (issue.offset + issue.length).clamp(0, currentText.length);
      if (start < end) {
        boundaries.add(start);
        boundaries.add(end);
        issueIntervals.add(_GrammarInterval(start, end, issue));
      }
    }

    final List<_SearchMatchInterval> searchIntervals = [];
    for (final sm in searchMatches) {
      final start = sm.startOffset.clamp(0, currentText.length);
      final end = sm.endOffset.clamp(0, currentText.length);
      if (start < end) {
        boundaries.add(start);
        boundaries.add(end);
        final isCurrent = sm.index == currentSearchMatchIndex;
        searchIntervals.add(_SearchMatchInterval(start, end, isCurrent));
      }
    }

    _HighlightInterval? highlightInterval;
    if (activeHighlightRange != null && activeHighlightRange!.isValid) {
      final hStart = activeHighlightRange!.start.clamp(0, currentText.length);
      final hEnd = activeHighlightRange!.end.clamp(0, currentText.length);
      if (hStart < hEnd) {
        boundaries.add(hStart);
        boundaries.add(hEnd);
        highlightInterval = _HighlightInterval(hStart, hEnd, activeHighlightColor ?? GruvboxColors.green);
      }
    }

    final sortedPoints = boundaries.toList()..sort();
    final List<TextSpan> children = [];

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final start = sortedPoints[i];
      final end = sortedPoints[i + 1];
      if (start >= end) continue;

      final chunk = currentText.substring(start, end);

      TextStyle sliceStyle = style ?? TextStyle(color: GruvboxColors.fg);
      for (final md in mdIntervals) {
        if (start >= md.start && end <= md.end) {
          sliceStyle = md.style;
          break;
        }
      }

      // Check if inside a grammar or spelling issue
      GrammarIssue? matchedIssue;
      for (final gi in issueIntervals) {
        if (start >= gi.start && end <= gi.end) {
          matchedIssue = gi.issue;
          break;
        }
      }

      if (matchedIssue != null) {
        Color wavyColor;
        switch (matchedIssue.type) {
          case GrammarIssueType.spelling:
          case GrammarIssueType.repeatedWord:
          case GrammarIssueType.homophone:
            wavyColor = GruvboxColors.red;
            break;
          case GrammarIssueType.capitalization:
          case GrammarIssueType.doublePunctuation:
          case GrammarIssueType.punctuationSpacing:
            wavyColor = GruvboxColors.yellow;
            break;
          case GrammarIssueType.cliche:
          case GrammarIssueType.passiveVoice:
            wavyColor = GruvboxColors.aqua;
            break;
        }
        sliceStyle = sliceStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: wavyColor,
        );
      }

      // Check if inside a search match
      _SearchMatchInterval? matchedSearch;
      for (final smi in searchIntervals) {
        if (start >= smi.start && end <= smi.end) {
          matchedSearch = smi;
          break;
        }
      }

      if (matchedSearch != null) {
        if (matchedSearch.isCurrent) {
          // Vivid, glowing highlight for the currently focused search instance
          sliceStyle = sliceStyle.copyWith(
            backgroundColor: GruvboxColors.yellow.withValues(alpha: 0.75),
            color: GruvboxColors.bgHard,
            fontWeight: FontWeight.bold,
          );
        } else {
          // Secondary subtle highlight for all other matching instances
          sliceStyle = sliceStyle.copyWith(
            backgroundColor: GruvboxColors.yellow.withValues(alpha: 0.28),
          );
        }
      }

      // Check if inside active change highlight
      if (highlightInterval != null && start >= highlightInterval.start && end <= highlightInterval.end) {
        sliceStyle = sliceStyle.copyWith(
          backgroundColor: highlightInterval.color.withValues(alpha: 0.38),
          color: GruvboxColors.fg0,
          fontWeight: FontWeight.bold,
        );
      }

      children.add(TextSpan(text: chunk, style: sliceStyle));
    }

    return TextSpan(style: style, children: children);
  }
}
