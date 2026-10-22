import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/manuscript_metadata.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class SceneMetadataInspector extends ConsumerStatefulWidget {
  const SceneMetadataInspector({super.key});

  @override
  ConsumerState<SceneMetadataInspector> createState() => _SceneMetadataInspectorState();
}

class _SceneMetadataInspectorState extends ConsumerState<SceneMetadataInspector> {
  late TextEditingController _titleController;
  late TextEditingController _povController;
  late TextEditingController _timelineController;
  late TextEditingController _targetController;
  late TextEditingController _synopsisController;
  SceneDraftStatus _status = SceneDraftStatus.draft;

  String? _loadedUri;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _povController = TextEditingController();
    _timelineController = TextEditingController();
    _targetController = TextEditingController();
    _synopsisController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _povController.dispose();
    _timelineController.dispose();
    _targetController.dispose();
    _synopsisController.dispose();
    super.dispose();
  }

  void _syncFromActiveDoc() {
    final activeTab = ref.read(editorProvider).activeTab;
    if (activeTab == null) return;

    if (activeTab.uri != _loadedUri) {
      _loadedUri = activeTab.uri;
      final meta = ManuscriptMetadata.extractFromMarkdown(activeTab.content, fallbackTitle: activeTab.fileName);
      _titleController.text = meta.title;
      _povController.text = meta.pov ?? '';
      _timelineController.text = meta.timeline ?? '';
      _targetController.text = meta.targetWords != null ? meta.targetWords.toString() : '';
      _synopsisController.text = meta.synopsis ?? '';
      _status = meta.status;
    }
  }

  void _applyMetadata() {
    final activeTab = ref.read(editorProvider).activeTab;
    if (activeTab == null) return;

    final existing = ManuscriptMetadata.extractFromMarkdown(activeTab.content, fallbackTitle: activeTab.fileName);
    final updated = existing.copyWith(
      title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : activeTab.fileName,
      pov: _povController.text.trim().isNotEmpty ? _povController.text.trim() : null,
      timeline: _timelineController.text.trim().isNotEmpty ? _timelineController.text.trim() : null,
      status: _status,
      targetWords: int.tryParse(_targetController.text.trim()),
      synopsis: _synopsisController.text.trim().isNotEmpty ? _synopsisController.text.trim() : null,
    );

    final newContent = updated.applyToMarkdown(activeTab.content);
    ref.read(editorProvider.notifier).updateContent(newContent);
  }

  @override
  Widget build(BuildContext context) {
    _syncFromActiveDoc();
    final activeTab = ref.watch(editorProvider).activeTab;

    if (activeTab == null) {
      return Center(
        child: Text(
          'Open a file to inspect metadata',
          style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
        ),
      );
    }

    return Container(
      color: GruvboxColors.bg,
      padding: const EdgeInsets.all(12.0),
      child: ListView(
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: GruvboxColors.yellow, size: 18),
              const SizedBox(width: 6),
              Text(
                'Scene Metadata Inspector',
                style: TextStyle(
                  color: GruvboxColors.fg0,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          _buildField(
            label: 'Scene Title',
            controller: _titleController,
            hint: 'e.g. The Library Infiltration',
            onChanged: (_) => _applyMetadata(),
          ),

          // POV Character
          _buildField(
            label: 'POV Character',
            controller: _povController,
            hint: 'e.g. Kaelen',
            onChanged: (_) => _applyMetadata(),
          ),

          // Timeline / Calendar Date
          _buildField(
            label: 'In-Story Timeline / Date',
            controller: _timelineController,
            hint: 'e.g. Autumn 442, Evening',
            onChanged: (_) => _applyMetadata(),
          ),

          // Draft Status
          const SizedBox(height: 8),
          Text(
            'Draft Status',
            style: TextStyle(color: GruvboxColors.gray, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: SceneDraftStatus.values.map((s) {
              final isSelected = s == _status;
              Color color;
              switch (s) {
                case SceneDraftStatus.idea:
                  color = GruvboxColors.blue;
                  break;
                case SceneDraftStatus.draft:
                  color = GruvboxColors.yellow;
                  break;
                case SceneDraftStatus.revised:
                  color = GruvboxColors.orange;
                  break;
                case SceneDraftStatus.polished:
                  color = GruvboxColors.green;
                  break;
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: InkWell(
                    onTap: () {
                      setState(() => _status = s);
                      _applyMetadata();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.25) : GruvboxColors.bg1,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? color : GruvboxColors.bg3,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: isSelected ? color : GruvboxColors.gray,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Target Word Count
          const SizedBox(height: 12),
          _buildField(
            label: 'Target Word Count',
            controller: _targetController,
            hint: 'e.g. 2500',
            keyboardType: TextInputType.number,
            onChanged: (_) => _applyMetadata(),
          ),

          // Synopsis
          const SizedBox(height: 8),
          Text(
            'Scene Synopsis',
            style: TextStyle(color: GruvboxColors.gray, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: GruvboxColors.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: GruvboxColors.bg3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TextField(
              controller: _synopsisController,
              maxLines: null,
              expands: true,
              style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
              cursorColor: GruvboxColors.yellow,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Brief summary of conflict, action, and outcome...',
                hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                border: InputBorder.none,
              ),
              onChanged: (_) => _applyMetadata(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: GruvboxColors.gray, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: GruvboxColors.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: GruvboxColors.bg3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
              cursorColor: GruvboxColors.yellow,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                hintText: hint,
                hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                border: InputBorder.none,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
