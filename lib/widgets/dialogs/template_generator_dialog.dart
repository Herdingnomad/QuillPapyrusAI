import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

/// Shows the AI Document Template Generator Dialog
Future<void> showTemplateGeneratorDialog(BuildContext context, WidgetRef ref) async {
  return showDialog(
    context: context,
    builder: (ctx) => const TemplateGeneratorDialog(),
  );
}

class TemplateGeneratorDialog extends ConsumerStatefulWidget {
  const TemplateGeneratorDialog({super.key});

  @override
  ConsumerState<TemplateGeneratorDialog> createState() => _TemplateGeneratorDialogState();
}

class _TemplateGeneratorDialogState extends ConsumerState<TemplateGeneratorDialog> {
  String _selectedPreset = 'journal';
  final TextEditingController _promptController = TextEditingController(text: 'Coffee & Morning Reflections');
  final TextEditingController _fileNameController = TextEditingController();
  bool _createNewFile = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _updateFileName();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  void _updateFileName() {
    final now = DateTime.now();
    final dStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    switch (_selectedPreset) {
      case 'journal':
        _fileNameController.text = '$dStr-journal.md';
        break;
      case 'project':
        _fileNameController.text = 'project-spec.md';
        break;
      case 'meeting':
        _fileNameController.text = '$dStr-meeting-notes.md';
        break;
      case 'weekly':
        _fileNameController.text = '$dStr-weekly-review.md';
        break;
      case 'farm':
        _fileNameController.text = '$dStr-farm-log.md';
        break;
      default:
        final clean = _promptController.text.trim().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), '-').toLowerCase();
        _fileNameController.text = '${clean.isEmpty ? "note" : clean}.md';
    }
  }

  void _onSelectPreset(String preset, String defaultPrompt) {
    setState(() {
      _selectedPreset = preset;
      _promptController.text = defaultPrompt;
      _updateFileName();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(editorProvider).activeTab;
    final workspaceState = ref.watch(workspaceProvider);

    return AlertDialog(
      backgroundColor: GruvboxColors.bg1,
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: GruvboxColors.yellow, size: 20),
          SizedBox(width: 8),
          Text(
            'AI Document Template Generator',
            style: TextStyle(color: GruvboxColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a template type or enter a custom topic. The AI will generate a complete document with valid YAML frontmatter and structured Markdown sections.',
                style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Presets Selection Wrap
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _presetChip('journal', '☕ Daily Journal', 'Coffee & Morning Reflections'),
                  _presetChip('project', '🚀 Project Spec', 'Architecture & System Design'),
                  _presetChip('meeting', '👥 Meeting Notes', 'Team Sync & Action Items'),
                  _presetChip('weekly', '📊 Weekly Review', 'Weekly Retrospective & Roadmap'),
                  _presetChip('farm', '🌾 Farm & Field Log', 'Pasture Rotation & Herd Health'),
                  _presetChip('custom', '✨ Custom Topic', 'My Custom Topic'),
                ],
              ),
              const SizedBox(height: 14),

              // Topic / Title Prompt
              Text(
                _selectedPreset == 'custom' ? 'Custom Topic / Description' : 'Template Title / Focus',
                style: TextStyle(color: GruvboxColors.fg, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _promptController,
                style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: GruvboxColors.bg2,
                  hintText: 'e.g. Flutter Architecture Plan, Hiking Trip...',
                  hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: GruvboxColors.bg3)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: GruvboxColors.aqua)),
                ),
                onChanged: (_) {
                  if (_selectedPreset == 'custom') {
                    _updateFileName();
                  }
                },
              ),
              const SizedBox(height: 14),

              // Destination Mode
              Text(
                'Destination',
                style: TextStyle(color: GruvboxColors.fg, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              RadioGroup<bool>(
                groupValue: _createNewFile,
                onChanged: (val) {
                  if (val != null) {
                    if (!val && activeTab == null) return;
                    setState(() => _createNewFile = val);
                  }
                },
                child: Row(
                  children: [
                    Radio<bool>(
                      value: true,
                      activeColor: GruvboxColors.aqua,
                    ),
                    Text('Create New File', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
                    const SizedBox(width: 16),
                    Radio<bool>(
                      value: false,
                      activeColor: GruvboxColors.aqua,
                    ),
                    Text(
                      'Insert into Current File',
                      style: TextStyle(
                        color: activeTab != null ? GruvboxColors.fg : GruvboxColors.gray,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              if (_createNewFile) ...[
                const SizedBox(height: 8),
                Text(
                  'File Name',
                  style: TextStyle(color: GruvboxColors.fg, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _fileNameController,
                  style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: GruvboxColors.bg2,
                    hintText: 'note-name.md',
                    hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: GruvboxColors.bg3)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: GruvboxColors.aqua)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: GruvboxColors.aqua,
            foregroundColor: GruvboxColors.bgHard,
          ),
          icon: _isGenerating
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: GruvboxColors.bgHard),
                )
              : const Icon(Icons.auto_awesome, size: 16),
          label: Text(_isGenerating ? 'Generating with AI...' : 'Generate Template'),
          onPressed: _isGenerating
              ? null
              : () async {
                  setState(() => _isGenerating = true);
                  final aiService = ref.read(aiServiceProvider);
                  final aiConfig = ref.read(aiProvider).config;
                  final generatedDoc = await aiService.generateDocumentTemplateWithAi(
                    templateTypeOrPrompt: _selectedPreset == 'custom'
                        ? _promptController.text.trim()
                        : '$_selectedPreset: ${_promptController.text.trim()}',
                    workspaceTags: workspaceState.tags,
                    workspaceTopics: workspaceState.topics,
                    config: aiConfig,
                  );

                  if (_createNewFile) {
                    var name = _fileNameController.text.trim();
                    if (!name.endsWith('.md')) name = '$name.md';
                    final parentUri = workspaceState.fileTree?.uri ?? workspaceState.rootUri;
                    if (parentUri != null) {
                      final newUri = await ref.read(workspaceProvider.notifier).createFile(parentUri, name);
                      if (newUri != null) {
                        await ref.read(editorProvider.notifier).openFile(newUri, name);
                        ref.read(editorProvider.notifier).updateContent(generatedDoc);
                        await ref.read(editorProvider.notifier).saveActiveFile();
                      }
                    }
                  } else {
                    ref.read(editorProvider.notifier).updateContent(generatedDoc);
                  }

                  if (mounted) {
                    setState(() => _isGenerating = false);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GruvboxColors.bg1,
                        duration: const Duration(seconds: 2),
                        content: Text(
                          'Generated template for "${_promptController.text.trim()}"',
                          style: TextStyle(color: GruvboxColors.green),
                        ),
                      ),
                    );
                  }
                },
        ),
      ],
    );
  }

  Widget _presetChip(String id, String label, String defaultPrompt) {
    final isSelected = _selectedPreset == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: GruvboxColors.aqua,
      backgroundColor: GruvboxColors.bg2,
      labelStyle: TextStyle(
        color: isSelected ? GruvboxColors.bgHard : GruvboxColors.fg,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? GruvboxColors.aqua : GruvboxColors.bg3),
      onSelected: (_) => _onSelectPreset(id, defaultPrompt),
    );
  }
}
