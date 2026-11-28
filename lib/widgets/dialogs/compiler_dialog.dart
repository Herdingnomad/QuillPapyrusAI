import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/compiler_config.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/compiler_service.dart';
import 'package:quill_papyrus_ai/services/pdf_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/pdf/pdf_viewer_widget.dart';

enum CompilerMode {
  compileFolder,
  singleFile,
}

class CompilerDialog extends ConsumerStatefulWidget {
  final String? initialFolderUri;
  final String? initialFileUri;
  final bool singleFileMode;

  const CompilerDialog({
    super.key,
    this.initialFolderUri,
    this.initialFileUri,
    this.singleFileMode = false,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialFolderUri,
    String? initialFileUri,
    bool singleFileMode = false,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => CompilerDialog(
        initialFolderUri: initialFolderUri,
        initialFileUri: initialFileUri,
        singleFileMode: singleFileMode,
      ),
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

  late CompilerMode _mode;
  String? _selectedFolderUri;
  String? _selectedFileUri;

  CompilerOutputFormat _format = CompilerOutputFormat.printPdfHtml;
  ChapterNumberingStyle _numberingStyle = ChapterNumberingStyle.words;
  String _sceneDivider = '* * *';
  bool _stripComments = true;
  bool _stripFrontmatter = true;
  bool _stripTodoMarkers = true;
  bool _includeTitlePage = true;

  bool _isCompiling = false;
  bool _isPrinting = false;
  CompiledDocument? _compiledDoc;

  @override
  void initState() {
    super.initState();
    final ws = ref.read(workspaceProvider);
    _titleController = TextEditingController(text: ws.rootName ?? 'My Document');
    _authorController = TextEditingController(text: '');
    _subtitleController = TextEditingController();
    _dedicationController = TextEditingController();

    _mode = widget.singleFileMode || widget.initialFileUri != null
        ? CompilerMode.singleFile
        : CompilerMode.compileFolder;

    _selectedFolderUri = widget.initialFolderUri;
    _selectedFileUri = widget.initialFileUri;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _subtitleController.dispose();
    _dedicationController.dispose();
    super.dispose();
  }

  /// Recursively collects all directories in the file tree
  List<FileNode> _getAllDirectories(FileNode? root) {
    final dirs = <FileNode>[];
    if (root == null) return dirs;

    void traverse(FileNode node) {
      if (node.isDirectory) {
        dirs.add(node);
        for (final child in node.children) {
          traverse(child);
        }
      }
    }

    traverse(root);
    return dirs;
  }

  /// Collects all markdown files matching the current scope
  List<FileNode> _getFilesInScope(FileNode? root) {
    if (root == null) return [];
    final files = <FileNode>[];

    if (_mode == CompilerMode.singleFile) {
      if (_selectedFileUri != null) {
        final found = _findNodeByUri(root, _selectedFileUri!);
        if (found != null) return [found];
      }
      // If no file selected yet, fallback to all markdown files
      _collectMarkdownFiles(root, files, recursive: true);
      return files.isNotEmpty ? [files.first] : [];
    }

    // Folder mode
    if (_selectedFolderUri == null || _selectedFolderUri == '__all__') {
      // Entire workspace recursive
      _collectMarkdownFiles(root, files, recursive: true);
    } else if (_selectedFolderUri == '__root__') {
      // Root level only
      for (final child in root.sortedChildren) {
        if (!child.isDirectory && _isMarkdown(child.name)) {
          files.add(child);
        }
      }
    } else {
      // Specific folder
      final folderNode = _findNodeByUri(root, _selectedFolderUri!);
      if (folderNode != null) {
        _collectMarkdownFiles(folderNode, files, recursive: true);
      }
    }

    return files;
  }

  /// Helper to collect all markdown files in the workspace for the single file dropdown
  List<FileNode> _getAllMarkdownFiles(FileNode? root) {
    final files = <FileNode>[];
    if (root == null) return files;
    _collectMarkdownFiles(root, files, recursive: true);
    return files;
  }

  void _collectMarkdownFiles(FileNode node, List<FileNode> acc, {bool recursive = true}) {
    for (final child in node.sortedChildren) {
      if (!child.isDirectory && _isMarkdown(child.name)) {
        acc.add(child);
      } else if (child.isDirectory && recursive) {
        _collectMarkdownFiles(child, acc, recursive: recursive);
      }
    }
  }

  FileNode? _findNodeByUri(FileNode root, String uri) {
    if (root.uri == uri) return root;
    for (final child in root.children) {
      final found = _findNodeByUri(child, uri);
      if (found != null) return found;
    }
    return null;
  }

  bool _isMarkdown(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.markdown');
  }

  CompilerConfig _buildConfig() {
    return CompilerConfig(
      bookTitle: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Document',
      authorName: _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : '',
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
  }

  Future<void> _runCompile() async {
    final ws = ref.read(workspaceProvider);
    final tree = ws.fileTree;
    if (tree == null) return;

    final targetFiles = _getFilesInScope(tree);
    if (targetFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No Markdown files found in selected scope.'),
          backgroundColor: GruvboxColors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCompiling = true;
      _compiledDoc = null;
    });

    try {
      final storage = ref.read(safStorageServiceProvider);
      final config = _buildConfig();

      final compiled = await CompilerService.instance.compileManuscript(
        files: targetFiles,
        storage: storage,
        config: config,
      );

      if (mounted) {
        setState(() {
          _isCompiling = false;
          _compiledDoc = compiled;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompiling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compilation failed: $e'),
            backgroundColor: GruvboxColors.red,
          ),
        );
      }
    }
  }

  /// Prints the selected single file directly
  Future<void> _printSelectedSingleFile() async {
    final ws = ref.read(workspaceProvider);
    final tree = ws.fileTree;
    if (tree == null) return;

    final allMd = _getAllMarkdownFiles(tree);
    if (allMd.isEmpty) return;

    final targetFile = _selectedFileUri != null
        ? (_findNodeByUri(tree, _selectedFileUri!) ?? allMd.first)
        : allMd.first;

    setState(() => _isPrinting = true);
    try {
      final storage = ref.read(safStorageServiceProvider);
      final config = _buildConfig();

      final success = await CompilerService.instance.printSingleFile(
        file: targetFile,
        storage: storage,
        config: config,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Spooling "${targetFile.name}" to printer...'),
            backgroundColor: GruvboxColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printing failed: $e'),
            backgroundColor: GruvboxColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  /// Prints the compiled manuscript
  Future<void> _printCompiledDocument() async {
    if (_compiledDoc == null) return;

    setState(() => _isPrinting = true);
    try {
      final config = _buildConfig();
      final success = await CompilerService.instance.printCompiledDocument(
        _compiledDoc!,
        config: config,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sent exported document to printer!'),
            backgroundColor: GruvboxColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: GruvboxColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  /// Previews the compiled manuscript layout in the in-app PDF viewer
  Future<void> _previewCompiledPdf() async {
    if (_compiledDoc == null) return;

    try {
      final config = _buildConfig();
      final pdfBytes = await PdfService.instance.generatePrintableDocument(
        title: config.bookTitle,
        subtitle: config.subtitle,
        author: config.authorName,
        content: _compiledDoc!.content,
      );

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 900,
                height: MediaQuery.of(context).size.height * 0.9,
                color: GruvboxColors.bgHard,
                child: Column(
                  children: [
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: GruvboxColors.bg,
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: GruvboxColors.red, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Print Preview — ${config.bookTitle}',
                            style: TextStyle(color: GruvboxColors.fg0, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PdfViewerWidget(
                        pdfBytes: pdfBytes,
                        fileName: '${config.bookTitle}.pdf',
                        showAppBar: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview error: $e'), backgroundColor: GruvboxColors.red),
        );
      }
    }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenWidth < 650;

    return Dialog(
      backgroundColor: GruvboxColors.bg,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12.0 : 24.0,
        vertical: isCompact ? 16.0 : 24.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: GruvboxColors.bg3),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: screenHeight * 0.92,
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 14.0 : 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.print_outlined, color: GruvboxColors.yellow, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Document Exporter',
                      style: TextStyle(
                        color: GruvboxColors.fg0,
                        fontSize: isCompact ? 15 : 17,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Mode Switcher (Compile Folder vs Single File)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: GruvboxColors.bg1,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GruvboxColors.bg3),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _mode = CompilerMode.compileFolder),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _mode == CompilerMode.compileFolder ? GruvboxColors.bg3 : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 15,
                                color: _mode == CompilerMode.compileFolder ? GruvboxColors.yellow : GruvboxColors.gray,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCompact ? 'Folder' : 'Export Folder',
                                style: TextStyle(
                                  color: _mode == CompilerMode.compileFolder ? GruvboxColors.fg0 : GruvboxColors.gray,
                                  fontSize: 12,
                                  fontWeight: _mode == CompilerMode.compileFolder ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _mode = CompilerMode.singleFile),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _mode == CompilerMode.singleFile ? GruvboxColors.bg3 : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description,
                                size: 15,
                                color: _mode == CompilerMode.singleFile ? GruvboxColors.aqua : GruvboxColors.gray,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCompact ? 'Single File' : 'Single File (Print / Compile)',
                                style: TextStyle(
                                  color: _mode == CompilerMode.singleFile ? GruvboxColors.fg0 : GruvboxColors.gray,
                                  fontSize: 12,
                                  fontWeight: _mode == CompilerMode.singleFile ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: _compiledDoc != null ? _buildResultsView(isCompact) : _buildConfigForm(isCompact),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigForm(bool isCompact) {
    final ws = ref.watch(workspaceProvider);
    final tree = ws.fileTree;
    final allDirs = _getAllDirectories(tree);
    final allMd = _getAllMarkdownFiles(tree);
    final scopedFiles = _getFilesInScope(tree);

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Scope Selection Section
        if (_mode == CompilerMode.compileFolder) ...[
          Text(
            'Source Folder to Compile',
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
              child: DropdownButton<String>(
                value: _selectedFolderUri ?? '__all__',
                isExpanded: true,
                dropdownColor: GruvboxColors.bg1,
                style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                items: [
                  const DropdownMenuItem(
                    value: '__all__',
                    child: Text('Entire Workspace (Root & All Subfolders)'),
                  ),
                  const DropdownMenuItem(
                    value: '__root__',
                    child: Text('Workspace Root Only'),
                  ),
                  ...allDirs.map((dir) {
                    final relPath = ws.rootUri != null
                        ? p.relative(dir.uri, from: ws.rootUri)
                        : dir.name;
                    return DropdownMenuItem(
                      value: dir.uri,
                      child: Row(
                        children: [
                          Icon(Icons.folder, size: 15, color: GruvboxColors.yellow),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              relPath,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFolderUri = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Badge showing files count
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 13, color: GruvboxColors.aqua),
              const SizedBox(width: 5),
              Text(
                'Found ${scopedFiles.length} Markdown file(s) ready to export',
                style: TextStyle(color: GruvboxColors.aqua, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else ...[
          // Single File Picker Section
          Text(
            'Select Markdown File to Print or Compile',
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
              child: DropdownButton<String>(
                value: _selectedFileUri ?? (allMd.isNotEmpty ? allMd.first.uri : null),
                isExpanded: true,
                dropdownColor: GruvboxColors.bg1,
                style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                hint: Text('Select file...', style: TextStyle(color: GruvboxColors.gray, fontSize: 12)),
                items: allMd.map((file) {
                  final rel = ws.rootUri != null ? p.relative(file.uri, from: ws.rootUri) : file.name;
                  return DropdownMenuItem(
                    value: file.uri,
                    child: Row(
                      children: [
                        Icon(Icons.description, size: 15, color: GruvboxColors.aqua),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rel,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedFileUri = val;
                      final node = _findNodeByUri(tree!, val);
                      if (node != null && _titleController.text == (ws.rootName ?? 'My Document')) {
                        _titleController.text = p.basenameWithoutExtension(node.name);
                      }
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Direct Single File Print Button
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GruvboxColors.aqua,
                foregroundColor: GruvboxColors.bgHard,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              icon: _isPrinting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print, size: 16),
              label: Text(_isPrinting ? 'Spooling...' : 'Print This File Directly'),
              onPressed: _isPrinting || allMd.isEmpty ? null : _printSelectedSingleFile,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Title & Byline
        if (isCompact) ...[
          _buildTextField('Document Title', _titleController, 'e.g. Project Notes'),
          const SizedBox(height: 10),
          _buildTextField('Byline / Name (Optional)', _authorController, 'e.g. Your Name'),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildTextField('Document Title', _titleController, 'e.g. Project Notes'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('Byline / Name (Optional)', _authorController, 'e.g. Your Name'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),

        // Subtitle
        _buildTextField('Subtitle (Optional)', _subtitleController, 'e.g. Summary or version'),
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

        // Chapter numbering & Scene divider
        if (isCompact) ...[
          _buildNumberingDropdown(),
          const SizedBox(height: 10),
          _buildSceneDividerDropdown(),
        ] else ...[
          Row(
            children: [
              Expanded(child: _buildNumberingDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildSceneDividerDropdown()),
            ],
          ),
        ],
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GruvboxColors.yellow,
                foregroundColor: GruvboxColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              icon: _isCompiling
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_isCompiling
                  ? 'Exporting...'
                  : (_mode == CompilerMode.singleFile ? 'Export Single File' : 'Export Document')),
              onPressed: _isCompiling ? null : _runCompile,
            ),
            if (_mode == CompilerMode.compileFolder)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GruvboxColors.aqua,
                  side: BorderSide(color: GruvboxColors.aqua.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                icon: _isPrinting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print, size: 16),
                label: Text(_isPrinting ? 'Printing...' : 'Compile & Print Immediately'),
                onPressed: _isPrinting
                    ? null
                    : () async {
                        await _runCompile();
                        if (_compiledDoc != null) {
                          await _printCompiledDocument();
                        }
                      },
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildNumberingDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Section Numbering',
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
    );
  }

  Widget _buildSceneDividerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Section Divider',
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
    );
  }

  Widget _buildResultsView(bool isCompact) {
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
                      'Document Exported Successfully!',
                      style: TextStyle(
                        color: GruvboxColors.fg0,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.chapterCount} sections combined • ${doc.totalWords} words • Output: ${doc.suggestedFileName}',
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action buttons with Print option prominently available
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GruvboxColors.aqua,
                foregroundColor: GruvboxColors.bgHard,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              icon: _isPrinting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print, size: 16),
              label: Text(_isPrinting ? 'Printing...' : 'Print Document'),
              onPressed: _isPrinting ? null : _printCompiledDocument,
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GruvboxColors.green,
                foregroundColor: GruvboxColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              icon: const Icon(Icons.save, size: 16),
              label: Text('Save (${doc.suggestedFileName})'),
              onPressed: _saveToWorkspace,
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: GruvboxColors.yellow,
              ),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('Preview PDF'),
              onPressed: _previewCompiledPdf,
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: GruvboxColors.aqua,
              ),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Text'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: doc.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exported document copied to clipboard')),
                );
              },
            ),
            TextButton(
              onPressed: () => setState(() => _compiledDoc = null),
              child: Text('Edit Settings', style: TextStyle(color: GruvboxColors.gray)),
            ),
          ],
        ),
        const SizedBox(height: 10),

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
