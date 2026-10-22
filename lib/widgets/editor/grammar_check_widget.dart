import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/grammar_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class GrammarCheckWidget extends ConsumerStatefulWidget {
  final String content;
  final void Function(int line, int offset)? onNavigateToLine;

  const GrammarCheckWidget({
    super.key,
    required this.content,
    this.onNavigateToLine,
  });

  @override
  ConsumerState<GrammarCheckWidget> createState() => _GrammarCheckWidgetState();
}

class _GrammarCheckWidgetState extends ConsumerState<GrammarCheckWidget> {
  final Set<String> _ignoredIssueIds = {};
  GrammarIssueType? _filterType;

  @override
  Widget build(BuildContext context) {
    final issues = GrammarService.instance
        .analyze(widget.content)
        .where((issue) => !_ignoredIssueIds.contains(issue.id))
        .toList();

    final filteredIssues = _filterType == null
        ? issues
        : issues.where((issue) => issue.type == _filterType).toList();

    final fixableCount = issues.where((i) => i.replacements.isNotEmpty).length;

    return Container(
      color: GruvboxColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: GruvboxColors.bg1,
              border: Border(bottom: BorderSide(color: GruvboxColors.bg3, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      issues.isEmpty ? Icons.check_circle : Icons.spellcheck,
                      color: issues.isEmpty ? GruvboxColors.green : GruvboxColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issues.isEmpty
                            ? 'Prose Clean & Checked'
                            : '${issues.length} Issue${issues.length == 1 ? '' : 's'} Detected',
                        style: TextStyle(
                          color: GruvboxColors.fg,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (fixableCount > 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: GruvboxColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.auto_fix_high, size: 14),
                        label: const Text('Fix All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final updated = GrammarService.instance.applyAllFixes(widget.content, issues);
                          ref.read(editorProvider.notifier).updateContent(updated);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: GruvboxColors.bg1,
                              duration: const Duration(seconds: 1),
                              content: Text(
                                'Applied $fixableCount quick fixes!',
                                style: TextStyle(color: GruvboxColors.green),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                if (issues.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(null, 'All (${issues.length})'),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          GrammarIssueType.repeatedWord,
                          'Duplicates',
                          count: issues.where((i) => i.type == GrammarIssueType.repeatedWord).length,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          GrammarIssueType.homophone,
                          'Words',
                          count: issues.where((i) => i.type == GrammarIssueType.homophone).length,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          GrammarIssueType.punctuationSpacing,
                          'Punctuation',
                          count: issues.where((i) => i.type == GrammarIssueType.punctuationSpacing || i.type == GrammarIssueType.doublePunctuation).length,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          GrammarIssueType.capitalization,
                          'Caps',
                          count: issues.where((i) => i.type == GrammarIssueType.capitalization).length,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          GrammarIssueType.cliche,
                          'Style',
                          count: issues.where((i) => i.type == GrammarIssueType.cliche || i.type == GrammarIssueType.passiveVoice).length,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Issues list or empty state
          Expanded(
            child: filteredIssues.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 48,
                            color: GruvboxColors.green.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            issues.isEmpty
                                ? 'No grammar or spelling issues!'
                                : 'No issues matching current filter.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GruvboxColors.fg,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            issues.isEmpty
                                ? 'Your document has been verified for repeated words, punctuation spacing, capitalization, and homophone clarity.'
                                : 'Select "All" to view other detected issues.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GruvboxColors.gray,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                    itemCount: filteredIssues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final issue = filteredIssues[index];
                      return _buildIssueCard(issue);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(GrammarIssueType? type, String label, {int? count}) {
    if (count != null && count == 0) return const SizedBox.shrink();
    final isSelected = _filterType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _filterType = isSelected && type != null ? null : type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? GruvboxColors.accent.withValues(alpha: 0.2) : GruvboxColors.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? GruvboxColors.accent : GruvboxColors.bg3,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? GruvboxColors.accent : GruvboxColors.fg,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildIssueCard(GrammarIssue issue) {
    Color badgeColor;
    switch (issue.type) {
      case GrammarIssueType.repeatedWord:
        badgeColor = GruvboxColors.red;
        break;
      case GrammarIssueType.homophone:
        badgeColor = GruvboxColors.orange;
        break;
      case GrammarIssueType.capitalization:
      case GrammarIssueType.doublePunctuation:
      case GrammarIssueType.punctuationSpacing:
        badgeColor = GruvboxColors.yellow;
        break;
      case GrammarIssueType.cliche:
      case GrammarIssueType.passiveVoice:
        badgeColor = GruvboxColors.aqua;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: GruvboxColors.bg3, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 0.8),
                ),
                child: Text(
                  issue.typeLabel,
                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  widget.onNavigateToLine?.call(issue.line, issue.offset);
                  ref.read(editorProvider.notifier).updateCursor(issue.line, issue.column);
                },
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: GruvboxColors.gray),
                    const SizedBox(width: 2),
                    Text(
                      'Ln ${issue.line}, Col ${issue.column}',
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() {
                    _ignoredIssueIds.add(issue.id);
                  });
                },
                child: Tooltip(
                  message: 'Ignore this occurrence',
                  child: Icon(Icons.close, size: 13, color: GruvboxColors.gray),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Message
          Text(
            issue.message,
            style: TextStyle(
              color: GruvboxColors.fg,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),

          // Matched text snippet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: GruvboxColors.bgHard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: GruvboxColors.bg3, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    issue.matchedText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Replacement actions
          if (issue.replacements.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: issue.replacements.map((repl) {
                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GruvboxColors.accent,
                    foregroundColor: GruvboxColors.bgHard,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.check, size: 13),
                  label: Text(
                    repl.isEmpty ? 'Remove' : 'Fix with "$repl"',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final updated = GrammarService.instance.applyFix(widget.content, issue, repl);
                    ref.read(editorProvider.notifier).updateContent(updated);
                    widget.onNavigateToLine?.call(issue.line, issue.offset);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
