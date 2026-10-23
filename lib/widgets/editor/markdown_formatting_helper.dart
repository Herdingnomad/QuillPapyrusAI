import 'package:flutter/widgets.dart';

/// Reusable markdown formatting utilities for editing operations.
class MarkdownFormattingHelper {
  /// Wraps current selection or inserts prefix and suffix at cursor.
  static void wrapSelection(TextEditingController controller, String prefix, String suffix) {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length),
      );
    } else {
      final offset = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(offset, offset, '$prefix$suffix');

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + prefix.length),
      );
    }
  }

  /// Inserts a prefix at the start of the current line (e.g. '> ', '- ', '1. ').
  static void prefixLine(TextEditingController controller, String prefix) {
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    int lineStart = offset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final newText = text.replaceRange(lineStart, lineStart, prefix);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + prefix.length),
    );
  }

  /// Cycles heading level (# -> ## -> ### -> plain text).
  static void cycleHeading(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    int lineStart = offset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final currentLine = text.substring(lineStart);
    if (currentLine.startsWith('### ')) {
      final newText = text.replaceRange(lineStart, lineStart + 4, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (offset - 4).clamp(0, newText.length)),
      );
    } else if (currentLine.startsWith('## ')) {
      final newText = text.replaceRange(lineStart, lineStart + 3, '### ');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 1),
      );
    } else if (currentLine.startsWith('# ')) {
      final newText = text.replaceRange(lineStart, lineStart + 2, '## ');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 1),
      );
    } else {
      final newText = text.replaceRange(lineStart, lineStart, '# ');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 2),
      );
    }
  }

  /// Toggles checklist item state (- [ ] -> - [x] -> none -> - [ ]).
  static void toggleCheckbox(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.baseOffset : text.length;
    final lineStart = offset > 0 ? text.lastIndexOf('\n', offset - 1) + 1 : 0;
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
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + newLine.length),
    );
  }

  /// Inserts a markdown snippet at cursor offset.
  static void insertSnippet(TextEditingController controller, String snippet) {
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    final newText = text.replaceRange(offset, offset, snippet);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + snippet.length),
    );
  }
}
