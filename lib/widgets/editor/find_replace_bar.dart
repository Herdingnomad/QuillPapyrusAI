import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/find_replace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class FindReplaceBar extends ConsumerStatefulWidget {
  final TextEditingController editorController;
  final void Function(int start, int end)? onScrollToMatch;

  const FindReplaceBar({
    super.key,
    required this.editorController,
    this.onScrollToMatch,
  });

  @override
  ConsumerState<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends ConsumerState<FindReplaceBar> {
  late TextEditingController _findController;
  late TextEditingController _replaceController;
  final FocusNode _findFocus = FocusNode();
  final FocusNode _replaceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _findController = TextEditingController();
    _replaceController = TextEditingController();

    _findController.addListener(_onFindChanged);
    _replaceController.addListener(_onReplaceChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _findFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant FindReplaceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final findState = ref.read(findReplaceProvider);
    if (_findController.text != findState.options.query) {
      _findController.text = findState.options.query;
    }
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    _findFocus.dispose();
    _replaceFocus.dispose();
    super.dispose();
  }

  void _onFindChanged() {
    ref.read(findReplaceProvider.notifier).updateQuery(
          _findController.text,
          widget.editorController.text,
        );
    _jumpToActiveMatch();
  }

  void _onReplaceChanged() {
    ref.read(findReplaceProvider.notifier).updateReplaceWith(_replaceController.text);
  }

  void _jumpToActiveMatch() {
    final state = ref.read(findReplaceProvider);
    final match = state.currentMatch;
    if (match != null) {
      widget.editorController.selection = TextSelection(
        baseOffset: match.startOffset,
        extentOffset: match.endOffset,
      );
      widget.onScrollToMatch?.call(match.startOffset, match.endOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final findState = ref.watch(findReplaceProvider);
    if (!findState.isVisible) return const SizedBox.shrink();

    final options = findState.options;

    return Material(
      color: GruvboxColors.bg1,
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          color: GruvboxColors.bg1,
          border: Border(
            bottom: BorderSide(color: GruvboxColors.bg3, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Find row
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    findState.isReplaceMode ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: GruvboxColors.aqua,
                  ),
                  tooltip: findState.isReplaceMode ? 'Hide Replace' : 'Show Replace (Ctrl+H)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => ref.read(findReplaceProvider.notifier).toggleReplaceMode(),
                ),
                Expanded(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GruvboxColors.bg3),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _findController,
                      focusNode: _findFocus,
                      style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                      cursorColor: GruvboxColors.yellow,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        hintText: 'Find in document...',
                        hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) {
                        ref.read(findReplaceProvider.notifier).nextMatch();
                        _jumpToActiveMatch();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Match counter badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg2,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    options.query.isEmpty
                        ? '0 matches'
                        : findState.matchCount > 0
                            ? '${findState.currentMatchIndex + 1} of ${findState.matchCount}'
                            : 'No matches',
                    style: TextStyle(
                      color: findState.matchCount > 0 ? GruvboxColors.yellow : GruvboxColors.gray,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Case sensitive toggle
                _buildToggleButton(
                  label: 'Aa',
                  isActive: options.matchCase,
                  tooltip: 'Match Case',
                  onTap: () {
                    ref.read(findReplaceProvider.notifier).toggleMatchCase(widget.editorController.text);
                    _jumpToActiveMatch();
                  },
                ),
                // Whole word toggle
                _buildToggleButton(
                  label: r'\b',
                  isActive: options.wholeWord,
                  tooltip: 'Match Whole Word',
                  onTap: () {
                    ref.read(findReplaceProvider.notifier).toggleWholeWord(widget.editorController.text);
                    _jumpToActiveMatch();
                  },
                ),
                // Regex toggle
                _buildToggleButton(
                  label: '.*',
                  isActive: options.useRegex,
                  tooltip: 'Use Regular Expression',
                  onTap: () {
                    ref.read(findReplaceProvider.notifier).toggleUseRegex(widget.editorController.text);
                    _jumpToActiveMatch();
                  },
                ),
                const SizedBox(width: 4),
                // Previous match
                IconButton(
                  icon: Icon(Icons.arrow_upward, size: 16, color: GruvboxColors.fg),
                  tooltip: 'Previous Match (Shift+Enter)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    ref.read(findReplaceProvider.notifier).previousMatch();
                    _jumpToActiveMatch();
                  },
                ),
                // Next match
                IconButton(
                  icon: Icon(Icons.arrow_downward, size: 16, color: GruvboxColors.fg),
                  tooltip: 'Next Match (Enter)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    ref.read(findReplaceProvider.notifier).nextMatch();
                    _jumpToActiveMatch();
                  },
                ),
                // Close button
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: GruvboxColors.gray),
                  tooltip: 'Close (Esc)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => ref.read(findReplaceProvider.notifier).close(),
                ),
              ],
            ),

            // Row 2: Replace row
            if (findState.isReplaceMode) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 26),
                  Expanded(
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GruvboxColors.bg3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _replaceController,
                        focusNode: _replaceFocus,
                        style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                        cursorColor: GruvboxColors.yellow,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          hintText: 'Replace with...',
                          hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) {
                          ref.read(findReplaceProvider.notifier).replaceCurrent(widget.editorController);
                          _jumpToActiveMatch();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Replace current
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GruvboxColors.bg2,
                      foregroundColor: GruvboxColors.fg,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(60, 26),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      ref.read(findReplaceProvider.notifier).replaceCurrent(widget.editorController);
                      _jumpToActiveMatch();
                    },
                    child: const Text('Replace'),
                  ),
                  const SizedBox(width: 4),
                  // Replace All
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GruvboxColors.bg2,
                      foregroundColor: GruvboxColors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(70, 26),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      ref.read(findReplaceProvider.notifier).replaceAll(widget.editorController);
                    },
                    child: const Text('Replace All'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: isActive ? GruvboxColors.bg3 : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isActive ? GruvboxColors.aqua : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? GruvboxColors.aqua : GruvboxColors.gray,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
