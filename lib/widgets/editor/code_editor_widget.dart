import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/editor/markdown_toolbar.dart';

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

  void _syncFromProvider() {
    final activeTab = ref.read(editorProvider).activeTab;
    if (activeTab != null && activeTab.uri != _lastLoadedUri) {
      _lastLoadedUri = activeTab.uri;
      if (_controller.text != activeTab.content) {
        _isUpdatingFromProvider = true;
        _controller.text = activeTab.content;
        _isUpdatingFromProvider = false;
      }
    }
  }

  void _onTextChanged() {
    if (_isUpdatingFromProvider) return;

    final text = _controller.text;
    final selection = _controller.selection;

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

    ref.read(editorProvider.notifier).updateContent(text);
    ref.read(editorProvider.notifier).updateCursor(line, column);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _undoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for tab switches or external content modifications (e.g. tag additions/removals)
    ref.listen(editorProvider, (previous, next) {
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
            if (currentSelection.isValid && currentSelection.end <= nextTab.content.length) {
              _controller.selection = currentSelection;
            }
            _isUpdatingFromProvider = false;
          }
        }
      }
    });

    const textStyle = TextStyle(
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
      },
      child: Container(
        color: GruvboxColors.bgHard,
        child: Column(
          children: [
            // Formatting toolbar
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
                        style: const TextStyle(color: GruvboxColors.green),
                      ),
                    ),
                  );
                }
              },
            ),
            const Divider(color: GruvboxColors.bg3, height: 1),

            // Editor & Gutter
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gutterWidth = 44.0;
                  // Calculate available width for text inside the editor padding (horizontal: 10.0 => 20px)
                  final editorWidth = (constraints.maxWidth - gutterWidth - 21.0).clamp(100.0, 5000.0);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gutter (mathematically locked to text lines and scroll offset)
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

                      // Text field
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: TextField(
                            controller: _controller,
                            undoController: _undoController,
                            scrollController: _scrollController,
                            maxLines: null,
                            expands: true,
                            style: textStyle,
                            cursorColor: GruvboxColors.aqua,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            selectionControls: MaterialTextSelectionControls(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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

    const normalStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: GruvboxColors.gray,
      height: 1.5,
    );

    const activeStyle = TextStyle(
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

class MarkdownTextEditingController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    text.splitMapJoin(
      RegExp(
        r'(^#{1,6}\s+.*$|\*\*.*?\*\*|\*.*?\*|`.*?`|\[\[.*?\]\]|^>.*$|^\s*-\s+.*$|\[.*?\]\(.*?\)|^-{3,}$)',
        multiLine: true,
      ),
      onMatch: (Match m) {
        final match = m[0]!;
        TextStyle matchStyle = style ?? const TextStyle(color: GruvboxColors.fg);

        if (match.startsWith('#')) {
          matchStyle = matchStyle.copyWith(
            color: GruvboxColors.green,
            fontWeight: FontWeight.bold,
          );
        } else if (match.startsWith('**') && match.endsWith('**')) {
          matchStyle = matchStyle.copyWith(
            color: GruvboxColors.fg0,
            fontWeight: FontWeight.bold,
          );
        } else if (match.startsWith('*') && match.endsWith('*')) {
          matchStyle = matchStyle.copyWith(
            color: GruvboxColors.fg2,
            fontStyle: FontStyle.italic,
          );
        } else if (match.startsWith('`') && match.endsWith('`')) {
          matchStyle = matchStyle.copyWith(
            color: GruvboxColors.orange,
            backgroundColor: GruvboxColors.bg1,
          );
        } else if (match.startsWith('[[') && match.endsWith(']]')) {
          matchStyle = matchStyle.copyWith(
            color: GruvboxColors.blue,
            decoration: TextDecoration.underline,
          );
        } else if (match.startsWith('>')) {
          matchStyle = matchStyle.copyWith(color: GruvboxColors.aqua);
        } else if (match.trimLeft().startsWith('-') && !match.startsWith('---')) {
          matchStyle = matchStyle.copyWith(color: GruvboxColors.yellow);
        } else if (match.startsWith('[') && match.contains('](')) {
          matchStyle = matchStyle.copyWith(
            color: GruvboxColors.blue,
            decoration: TextDecoration.underline,
          );
        } else if (match.startsWith('---')) {
          matchStyle = matchStyle.copyWith(color: GruvboxColors.gray);
        }

        children.add(TextSpan(text: match, style: matchStyle));
        return '';
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}
