import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/compiler_config.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/compiler_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class CompilerDialog extends ConsumerStatefulWidget {
  const CompilerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const CompilerDialog(),
    );
  }

  @override
  ConsumerState<CompilerDialog> createState() => _CompilerDialogState();
}

class _CompilerDialogState extends ConsumerState<CompilerDialog> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _subtitleController;
  late TextEditingController _dedicationController;

  CompilerOutputFormat _format = CompilerOutputFormat.printPdfHtml;
  ChapterNumberingStyle _numberingStyle = ChapterNumberingStyle.words;
  String _sceneDivider = '* * *';
  bool _stripComments = true;
  bool _stripFrontmatter = true;
  bool _stripTodoMarkers = true;
  bool _includeTitlePage = true;

  bool _isCompiling = false;
  CompiledDocument? _compiledDoc;

  @override
  void initState() {
    super.initState();
    final ws = ref.read(workspaceProvider);
    _titleController = TextEditingController(text: ws.rootName ?? 'My Manuscript');
    _authorController = TextEditingController(text: 'Author Name');
    _subtitleController = TextEditingController();
    _dedicationController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _subtitleController.dispose();
    _dedicationController.dispose();
    super.dispose();
  }

  Future<void> _runCompile() async {
    final ws = ref.read(workspaceProvider);
    final tree = ws.fileTree;
    if (tree == null) return;

    setState(() {
      _isCompiling = true;
      _compiledDoc = null;
    });

    final storage = ref.read(safStorageServiceProvider);
    final markdownFiles = tree.sortedChildren
        .where((c) => !c.isDirectory && (c.name.endsWith('.md') || c.name.endsWith('.markdown')))
        .toList();

    final config = CompilerConfig(
      bookTitle: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Manuscript',
      authorName: _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : 'Author',
      subtitle: _subtitleController.text.trim().isNotEmpty ? _subtitleController.text.trim() : null,
      dedication: _dedicationController.text.trim().isNotEmpty ? _dedicationController.text.trim() : null,
      outputFormat: _format,
      numberingStyle: _numberingStyle,
      sceneDividerGlyph: _sceneDivider,
      stripComments: _stripComments,
      stripFrontmatter: _stripFrontmatter,
      stripTodoMarkers: _stripTodoMarkers,
      includeTitlePage: _includeTitlePage,
    );

    final compiled = await CompilerService.instance.compileManuscript(
      files: markdownFiles,
      storage: storage,
      config: config,
    );

    setState(() {
      _isCompiling = false;
      _compiledDoc = compiled;
    });
  }

  Future<void> _saveToWorkspace() async {
    if (_compiledDoc == null) return;
    final ws = ref.read(workspaceProvider);
    final root = ws.rootUri;
    if (root == null) return;

    final storage = ref.read(safStorageServiceProvider);
    final targetPath = p.join(root, _compiledDoc!.suggestedFileName);
    await storage.writeFile(targetPath, _compiledDoc!.content);
    await ref.read(workspaceProvider.notifier).refreshWorkspace();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${_compiledDoc!.suggestedFileName} to workspace!'),
          backgroundColor: GruvboxColors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GruvboxColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: GruvboxColors.bg3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.print_outlined, color: GruvboxColors.yellow, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'The Manuscript Compiler',
                    style: TextStyle(
                      color: GruvboxColors.fg0,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: _compiledDoc != null ? _buildResultsView() : _buildConfigForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigForm() {
    return ListView(
      children: [
        // Title & Author
        Row(
          children: [
            Expanded(
              child: _buildTextField('Book Title', _titleController, 'e.g. The Glass Archive'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Author Name', _authorController, 'e.g. J. A. Jensen'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Subtitle
        _buildTextField('Subtitle (Optional)', _subtitleController, 'e.g. Chronicles of the High Scriptum'),
        const SizedBox(height: 12),

        // Format selector
        Text(
          'Target Output Format',
          style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GruvboxColors.bg3),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CompilerOutputFormat>(
              value: _format,
              isExpanded: true,
              dropdownColor: GruvboxColors.bg1,
              style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
              items: CompilerOutputFormat.values.map((fmt) {
                return DropdownMenuItem(
                  value: fmt,
                  child: Text(fmt.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _format = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Chapter numbering style
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chapter Numbering',
                    style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg1,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GruvboxColors.bg3),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ChapterNumberingStyle>(
                        value: _numberingStyle,
                        isExpanded: true,
                        dropdownColor: GruvboxColors.bg1,
                        style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: ChapterNumberingStyle.words, child: Text('Words (Chapter One)')),
                          DropdownMenuItem(value: ChapterNumberingStyle.numeric, child: Text('Numeric (Chapter 1)')),
                          DropdownMenuItem(value: ChapterNumberingStyle.roman, child: Text('Roman (CHAPTER I)')),
                          DropdownMenuItem(value: ChapterNumberingStyle.titleOnly, child: Text('Title Only')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _numberingStyle = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scene Divider Glyph',
                    style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg1,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: GruvboxColors.bg3),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sceneDivider,
                        isExpanded: true,
                        dropdownColor: GruvboxColors.bg1,
                        style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: '* * *', child: Text('* * * (Classic)')),
                          DropdownMenuItem(value: '#', child: Text('# (Manuscript standard)')),
                          DropdownMenuItem(value: '— ❖ —', child: Text('— ❖ — (Ornamental)')),
                          DropdownMenuItem(value: '❦', child: Text('❦ (Fleuron)')),
                          DropdownMenuItem(value: '✦ ✦ ✦', child: Text('✦ ✦ ✦ (Stars)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _sceneDivider = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sanitization Checkboxes
        Text(
          'Sanitization & Production Assembly',
          style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: GruvboxColors.yellow,
          title: Text('Strip internal comments & CriticMarkup annotations', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
          value: _stripComments,
          onChanged: (v) => setState(() => _stripComments = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: GruvboxColors.yellow,
          title: Text('Strip YAML front-matter blocks', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
          value: _stripFrontmatter,
          onChanged: (v) => setState(() => _stripFrontmatter = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: GruvboxColors.yellow,
          title: Text('Strip revision flags (TODO, FIXME, ???)', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
          value: _stripTodoMarkers,
          onChanged: (v) => setState(() => _stripTodoMarkers = v ?? true),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: GruvboxColors.yellow,
          title: Text('Generate Title Page & Front-Matter', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
          value: _includeTitlePage,
          onChanged: (v) => setState(() => _includeTitlePage = v ?? true),
        ),

        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: GruvboxColors.yellow,
            foregroundColor: GruvboxColors.bg,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          icon: _isCompiling
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_isCompiling ? 'Compiling Manuscript...' : 'Compile Manuscript'),
          onPressed: _isCompiling ? null : _runCompile,
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    final doc = _compiledDoc!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: GruvboxColors.green),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: GruvboxColors.green, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manuscript Compiled Successfully!',
                      style: TextStyle(
                        color: GruvboxColors.fg0,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.chapterCount} chapters stitched • ${doc.totalWords} words • Output: ${doc.suggestedFileName}',
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action buttons
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GruvboxColors.green,
                foregroundColor: GruvboxColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.save, size: 16),
              label: Text('Save to Workspace (${doc.suggestedFileName})'),
              onPressed: _saveToWorkspace,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: GruvboxColors.aqua,
              ),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy to Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: doc.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Compiled manuscript copied to clipboard')),
                );
              },
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _compiledDoc = null),
              child: Text('Edit Settings', style: TextStyle(color: GruvboxColors.gray)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Preview snippet
        Text(
          'Preview Output:',
          style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GruvboxColors.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: GruvboxColors.bg3),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                doc.content,
                style: TextStyle(
                  color: GruvboxColors.fg,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: GruvboxColors.gray, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GruvboxColors.bg3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
            cursorColor: GruvboxColors.yellow,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
