import 'package:equatable/equatable.dart';

/// Represents a reusable AI skill loaded either from built-in defaults
/// or from a workspace Markdown file (`.skills/<slug>/SKILL.md`).
class AiSkill with Equatable {
  /// Unique slash identifier (e.g. `meeting-notes`, `action-items`).
  final String id;

  /// Human-readable title displayed in the Skills picker and chips.
  final String name;

  /// Short summary explaining when to use this skill.
  final String description;

  /// Full Markdown instructions injected into the AI system prompt when active.
  final String instructions;

  /// Optional file path if loaded from the user's workspace `.skills/` folder.
  final String? filePath;

  /// Whether this skill ships as a built-in example.
  final bool isBuiltIn;

  const AiSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    this.filePath,
    this.isBuiltIn = false,
  });

  /// Formats this skill as a standard `SKILL.md` document with YAML frontmatter.
  String toSkillMarkdown() {
    final escapedDesc = description.replaceAll('"', '\\"');
    return '''---
name: $id
title: $name
description: "$escapedDesc"
---

${instructions.trim()}
''';
  }

  @override
  List<Object?> get props => [id, name, description, instructions, filePath, isBuiltIn];
}

/// Snapshot of current chat context window consumption.
class ContextUsage with Equatable {
  final int systemAndSkillsTokens;
  final int ragTokens;
  final int historyTokens;
  final int maxTokens;
  final bool isExact;

  const ContextUsage({
    this.systemAndSkillsTokens = 0,
    this.ragTokens = 0,
    this.historyTokens = 0,
    this.maxTokens = 8192,
    this.isExact = false,
  });

  int get usedTokens => systemAndSkillsTokens + ragTokens + historyTokens;

  int get remainingTokens => (maxTokens - usedTokens).clamp(0, maxTokens);

  double get usedFraction {
    if (maxTokens <= 0) return 0.0;
    return (usedTokens / maxTokens).clamp(0.0, 1.0);
  }

  int get remainingPercent => ((1.0 - usedFraction) * 100).round().clamp(0, 100);

  @override
  List<Object?> get props => [
        systemAndSkillsTokens,
        ragTokens,
        historyTokens,
        maxTokens,
        isExact,
      ];
}
