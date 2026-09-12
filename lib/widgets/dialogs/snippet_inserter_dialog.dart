import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/theme_provider.dart';

Future<void> showSnippetInserterDialog(BuildContext context, WidgetRef ref) async {
  return showDialog(
    context: context,
    builder: (ctx) => const SnippetInserterDialog(),
  );
}

class MarkdownSnippet {
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final String snippet;

  const MarkdownSnippet({
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.snippet,
  });
}

class SnippetInserterDialog extends ConsumerStatefulWidget {
  const SnippetInserterDialog({super.key});

  @override
  ConsumerState<SnippetInserterDialog> createState() => _SnippetInserterDialogState();
}

class _SnippetInserterDialogState extends ConsumerState<SnippetInserterDialog> {
  String _selectedCategory = 'All';

  static const List<MarkdownSnippet> snippets = [
    // GFM Callouts
    MarkdownSnippet(
      title: 'Note Callout',
      description: 'Standard informational callout box',
      icon: Icons.info_outline,
      category: 'Callouts',
      snippet: '> [!NOTE]\n> Highlights information that users should take note of.',
    ),
    MarkdownSnippet(
      title: 'Tip Callout',
      description: 'Helpful advice or optimization suggestions',
      icon: Icons.lightbulb_outline,
      category: 'Callouts',
      snippet: '> [!TIP]\n> Optional information to help a user be more successful.',
    ),
    MarkdownSnippet(
      title: 'Important Callout',
      description: 'Crucial information required for user success',
      icon: Icons.priority_high,
      category: 'Callouts',
      snippet: '> [!IMPORTANT]\n> Crucial information needed for users to succeed.',
    ),
    MarkdownSnippet(
      title: 'Warning Callout',
      description: 'Negative outcome warnings or potential breaking changes',
      icon: Icons.warning_amber_outlined,
      category: 'Callouts',
      snippet: '> [!WARNING]\n> Critical content demanding immediate user attention due to potential risks.',
    ),
    MarkdownSnippet(
      title: 'Caution Callout',
      description: 'High-risk warnings for data loss or breaking changes',
      icon: Icons.dangerous_outlined,
      category: 'Callouts',
      snippet: '> [!CAUTION]\n> Negative consequences of an action, such as data loss or security risk.',
    ),

    // Tables & Lists
    MarkdownSnippet(
      title: '3-Column Table',
      description: 'Standard Markdown table with header and rows',
      icon: Icons.table_chart_outlined,
      category: 'Tables',
      snippet: '''| Item | Status | Notes |
| :--- | :--- | :--- |
| First Entry | Active | Initial review |
| Second Entry | Pending | Needs follow-up |''',
    ),
    MarkdownSnippet(
      title: 'Feature Matrix Table',
      description: 'Comparison table with checkmarks',
      icon: Icons.compare_arrows,
      category: 'Tables',
      snippet: '''| Feature | Standard | Pro | Enterprise |
| :--- | :---: | :---: | :---: |
| On-Device AI | ✓ | ✓ | ✓ |
| Custom Themes | ✓ | ✓ | ✓ |
| Multi-Pane IDE | ✓ | ✓ | ✓ |''',
    ),
    MarkdownSnippet(
      title: 'Interactive Task List',
      description: 'GFM Checkboxes for to-do tracking',
      icon: Icons.checklist_rtl,
      category: 'Tables',
      snippet: '''- [ ] High priority task
- [ ] In-progress milestone
- [x] Completed item''',
    ),

    // Diagrams & Math
    MarkdownSnippet(
      title: 'Mermaid Flowchart',
      description: 'Architecture flowchart diagram block',
      icon: Icons.schema_outlined,
      category: 'Diagrams',
      snippet: '''```mermaid
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Proceed]
    B -->|No| D[Retry]
```''',
    ),
    MarkdownSnippet(
      title: 'Mermaid Sequence',
      description: 'Service-to-service sequence diagram',
      icon: Icons.sync_alt,
      category: 'Diagrams',
      snippet: '''```mermaid
sequenceDiagram
    participant User
    participant Editor
    participant GemmaAI
    User->>Editor: Type prompt
    Editor->>GemmaAI: Generate stream
    GemmaAI-->>Editor: Tokens
    Editor-->>User: Render diff
```''',
    ),
    MarkdownSnippet(
      title: 'KaTeX Math Equation',
      description: 'LaTeX/KaTeX mathematical block formula',
      icon: Icons.functions,
      category: 'Math',
      snippet: r'$$ e^{i\pi} + 1 = 0 $$',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final theme = themeState.activeTheme;
    final activeTab = ref.watch(editorProvider).activeTab;

    final categories = ['All', 'Callouts', 'Tables', 'Diagrams', 'Math'];
    final filtered = snippets.where((s) {
      if (_selectedCategory == 'All') return true;
      return s.category == _selectedCategory;
    }).toList();

    return Dialog(
      backgroundColor: theme.bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.bg3),
      ),
      child: Container(
        width: 720,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, color: theme.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Markdown Snippets & Callouts',
                        style: TextStyle(color: theme.fg, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Insert GitHub callouts, tables, task lists, and Mermaid charts directly into your active document.',
                        style: TextStyle(color: theme.fgMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.fgMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: theme.accent,
                      backgroundColor: theme.bg,
                      labelStyle: TextStyle(
                        color: isSelected ? theme.bgHard : theme.fg,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(color: isSelected ? theme.accent : theme.bg3),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Snippets Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.3,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, idx) {
                  final item = filtered[idx];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      _insertSnippet(context, ref, item.snippet, activeTab != null);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.bg3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(item.icon, color: theme.accent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(color: theme.fg, fontSize: 13, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.bg1,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(item.category, style: TextStyle(color: theme.fgMuted, fontSize: 10)),
                              ),
                            ],
                          ),
                          Text(
                            item.description,
                            style: TextStyle(color: theme.fgMuted, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              'Tap to Insert ↵',
                              style: TextStyle(color: theme.accent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _insertSnippet(BuildContext context, WidgetRef ref, String snippet, bool hasActiveTab) {
    if (!hasActiveTab) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a document first to insert snippets.')),
      );
      return;
    }

    final activeTab = ref.read(editorProvider).activeTab!;
    final current = activeTab.content;
    final merged = current.isEmpty ? snippet : '$current\n\n$snippet\n';
    ref.read(editorProvider.notifier).updateContent(merged);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Snippet inserted into document!')),
    );
  }
}
