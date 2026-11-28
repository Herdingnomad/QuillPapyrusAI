import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/ai_skill.dart';
import 'package:yaml/yaml.dart';

/// Parses, discovers, and formats Markdown-based AI skills (`SKILL.md`).
class SkillService {
  static const List<AiSkill> builtInSkills = [
    AiSkill(
      id: 'meeting-notes',
      name: 'Meeting Notes',
      description: 'Turns rough notes or voice transcripts into structured decisions and action items.',
      isBuiltIn: true,
      instructions: '''# Meeting Notes Skill

When the user provides rough notes, bullet points, or a voice transcript:
1. Organize the output into clean Markdown with these sections:
   - `## Summary` (2–3 sentences)
   - `## Key Decisions` (bulleted list)
   - `## Action Items` (Markdown checkboxes `- [ ] Owner — Task (Due if mentioned)`)
   - `## Open Questions` (only if unresolved questions exist)
2. Preserve facts, dates, and names accurately without inventing details.
3. Keep formatting concise and scannable.''',
    ),
    AiSkill(
      id: 'action-items',
      name: 'Action Extractor',
      description: 'Extracts concrete tasks, owners, and deadlines into a prioritized checklist.',
      isBuiltIn: true,
      instructions: '''# Action Extractor Skill

Extract every actionable task from the user's message, active note, or transcript:
1. Output a clean Markdown checklist grouped by priority (`### High Priority`, `### Next Up`, `### Later`) only when multiple priorities exist.
2. Start each task with an action verb using `- [ ] `.
3. Include owners (`@name`) or deadlines if mentioned.
4. Omit fluff or commentary outside the checklist unless clarification is needed.''',
    ),
    AiSkill(
      id: 'daily-review',
      name: 'Daily Log',
      description: 'Organizes thoughts, wins, blockers, and tomorrow\'s priorities into a daily entry.',
      isBuiltIn: true,
      instructions: '''# Daily Log Skill

Turn the user's update or voice memo into a clean daily log entry:
1. Structure with:
   - `## Highlights & Completed`
   - `## Notes & Observations`
   - `## Blockers / Follow-ups`
   - `## Top Priorities Next` (`- [ ]` checkboxes, max 3–5 items)
2. Keep the tone practical, clear, and faithful to the user's own phrasing.''',
    ),
    AiSkill(
      id: 'research-brief',
      name: 'Research Brief',
      description: 'Distills notes, documents, or attached images into key findings and next steps.',
      isBuiltIn: true,
      instructions: '''# Research Brief Skill

Synthesize the provided material (notes, workspace context, or attached image/audio) into a structured brief:
1. Start with a 2-sentence `## TL;DR`.
2. Follow with `## Key Findings` (concise bullets citing specific details).
3. Add `## Trade-offs & Risks` if comparing options.
4. End with `## Recommended Next Steps` as checkboxes (`- [ ]`).''',
    ),
  ];

  /// Loads built-in example skills merged with any custom workspace skills found under
  /// `<workspaceRoot>/.skills/` or `<workspaceRoot>/skills/`.
  /// Workspace skills with the same `id` override built-in skills.
  Future<List<AiSkill>> loadSkills({String? workspaceRoot}) async {
    final Map<String, AiSkill> byId = {
      for (final skill in builtInSkills) skill.id: skill,
    };

    if (workspaceRoot != null && workspaceRoot.isNotEmpty) {
      final candidateDirs = [
        Directory(p.join(workspaceRoot, '.skills')),
        Directory(p.join(workspaceRoot, 'skills')),
      ];

      for (final dir in candidateDirs) {
        try {
          if (!await dir.exists()) continue;
          await for (final entity in dir.list(followLinks: false)) {
            if (entity is Directory) {
              final skillFile = File(p.join(entity.path, 'SKILL.md'));
              if (await skillFile.exists()) {
                final parsed = await _parseSkillFile(skillFile, fallbackSlug: p.basename(entity.path));
                if (parsed != null) {
                  byId[parsed.id] = parsed;
                }
              }
            } else if (entity is File && entity.path.toLowerCase().endsWith('.md')) {
              final base = p.basenameWithoutExtension(entity.path);
              if (base.toLowerCase() == 'readme') continue;
              final parsed = await _parseSkillFile(entity, fallbackSlug: base);
              if (parsed != null) {
                byId[parsed.id] = parsed;
              }
            }
          }
        } catch (_) {}
      }
    }

    final list = byId.values.toList();
    list.sort((a, b) {
      if (a.isBuiltIn != b.isBuiltIn) {
        return a.isBuiltIn ? 1 : -1; // Custom workspace skills first
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Writes the built-in example skills to `<workspaceRoot>/.skills/<id>/SKILL.md`
  /// without overwriting any skill file the user has already customized.
  /// Returns the number of files newly created.
  Future<int> installExampleSkillsToWorkspace(String workspaceRoot) async {
    int created = 0;
    final skillsRoot = Directory(p.join(workspaceRoot, '.skills'));
    if (!await skillsRoot.exists()) {
      await skillsRoot.create(recursive: true);
    }

    for (final skill in builtInSkills) {
      final skillDir = Directory(p.join(skillsRoot.path, skill.id));
      if (!await skillDir.exists()) {
        await skillDir.create(recursive: true);
      }
      final skillFile = File(p.join(skillDir.path, 'SKILL.md'));
      if (!await skillFile.exists()) {
        await skillFile.writeAsString(skill.toSkillMarkdown());
        created++;
      }
    }
    return created;
  }

  /// Parses an optional leading `/skill-id` command from user chat input.
  /// Returns `(matchedSkill, remainingPrompt)`.
  static ({AiSkill? skill, String cleanedPrompt}) extractSlashSkill(
    String rawInput,
    List<AiSkill> availableSkills,
  ) {
    final trimmed = rawInput.trim();
    if (!trimmed.startsWith('/')) {
      return (skill: null, cleanedPrompt: trimmed);
    }

    final match = RegExp(r'^/([a-zA-Z0-9_-]+)(?:\s+(.*))?$', dotAll: true).firstMatch(trimmed);
    if (match == null) {
      return (skill: null, cleanedPrompt: trimmed);
    }

    final slug = match.group(1)!.toLowerCase();
    final rest = (match.group(2) ?? '').trim();

    for (final s in availableSkills) {
      if (s.id.toLowerCase() == slug) {
        return (skill: s, cleanedPrompt: rest);
      }
    }
    return (skill: null, cleanedPrompt: trimmed);
  }

  /// Combines one or more active skills into a single system prompt block.
  static String buildSkillsSystemBlock(List<AiSkill> activeSkills) {
    if (activeSkills.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('Active Skills (follow these instructions carefully):');
    for (final skill in activeSkills) {
      buf.writeln('\n--- Skill: ${skill.name} (/${skill.id}) ---');
      buf.writeln(skill.instructions.trim());
    }
    return buf.toString().trim();
  }

  /// Parses a Markdown `SKILL.md` file with optional YAML frontmatter.
  static AiSkill? parseSkillMarkdown(
    String rawContent, {
    required String fallbackSlug,
    String? filePath,
  }) {
    String id = _normalizeSlug(fallbackSlug);
    String name = _titleCaseFromSlug(id);
    String description = 'Custom workspace skill';
    String body = rawContent.trim();

    final fmMatch = RegExp(r'^---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n?([\s\S]*)$').firstMatch(rawContent.trimLeft());
    if (fmMatch != null) {
      final yamlText = fmMatch.group(1) ?? '';
      body = (fmMatch.group(2) ?? '').trim();
      try {
        final doc = loadYaml(yamlText);
        if (doc is YamlMap) {
          final yamlName = doc['name']?.toString().trim();
          final yamlTitle = doc['title']?.toString().trim();
          final yamlDesc = doc['description']?.toString().trim();

          if (yamlName != null && yamlName.isNotEmpty) {
            id = _normalizeSlug(yamlName);
            name = yamlTitle != null && yamlTitle.isNotEmpty
                ? yamlTitle
                : _titleCaseFromSlug(id);
          } else if (yamlTitle != null && yamlTitle.isNotEmpty) {
            name = yamlTitle;
          }
          if (yamlDesc != null && yamlDesc.isNotEmpty) {
            description = yamlDesc;
          }
        }
      } catch (_) {}
    }

    if (body.isEmpty) return null;

    return AiSkill(
      id: id,
      name: name,
      description: description,
      instructions: body,
      filePath: filePath,
      isBuiltIn: false,
    );
  }

  Future<AiSkill?> _parseSkillFile(File file, {required String fallbackSlug}) async {
    try {
      final raw = await file.readAsString();
      return parseSkillMarkdown(raw, fallbackSlug: fallbackSlug, filePath: file.path);
    } catch (_) {
      return null;
    }
  }

  static String _normalizeSlug(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return cleaned.isEmpty ? 'custom-skill' : cleaned;
  }

  static String _titleCaseFromSlug(String slug) {
    return slug
        .split(RegExp(r'[-_]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
