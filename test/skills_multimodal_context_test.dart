import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/ai_skill.dart';
import 'package:quill_papyrus_ai/services/ai_service.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/services/skill_service.dart';
import 'package:quill_papyrus_ai/widgets/ai/ai_panel.dart';

void main() {
  group('SkillService & Markdown Skills', () {
    test('loads built-in example skills by default', () async {
      final service = SkillService();
      final skills = await service.loadSkills();

      expect(skills.length, greaterThanOrEqualTo(4));
      final ids = skills.map((s) => s.id).toSet();
      expect(ids, containsAll(['meeting-notes', 'action-items', 'daily-review', 'research-brief']));
    });

    test('installs example SKILL.md files to workspace .skills/ and parses overrides', () async {
      final tempDir = await Directory.systemTemp.createTemp('quill_skills_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = SkillService();
      final created = await service.installExampleSkillsToWorkspace(tempDir.path);
      expect(created, equals(SkillService.builtInSkills.length));

      // Second install should not overwrite existing files
      final secondRun = await service.installExampleSkillsToWorkspace(tempDir.path);
      expect(secondRun, equals(0));

      // Add a custom workspace skill
      final customDir = Directory(p.join(tempDir.path, '.skills', 'farm-brief'));
      await customDir.create(recursive: true);
      await File(p.join(customDir.path, 'SKILL.md')).writeAsString('''---
name: farm-brief
title: Farm Brief
description: "Summarizes pasture and herd notes."
---

# Farm Brief
Summarize paddock moves and livestock checks.
''');

      final loaded = await service.loadSkills(workspaceRoot: tempDir.path);
      final custom = loaded.firstWhere((s) => s.id == 'farm-brief');
      expect(custom.name, equals('Farm Brief'));
      expect(custom.description, equals('Summarizes pasture and herd notes.'));
      expect(custom.isBuiltIn, isFalse);
      expect(custom.instructions, contains('Summarize paddock moves'));
    });

    test('extractSlashSkill parses explicit /skill commands', () {
      final res = SkillService.extractSlashSkill(
        '/meeting-notes Discussed Q4 launch and budget.',
        SkillService.builtInSkills,
      );
      expect(res.skill?.id, equals('meeting-notes'));
      expect(res.cleanedPrompt, equals('Discussed Q4 launch and budget.'));

      final unmatched = SkillService.extractSlashSkill(
        '/unknown-cmd Hello',
        SkillService.builtInSkills,
      );
      expect(unmatched.skill, isNull);
      expect(unmatched.cleanedPrompt, equals('/unknown-cmd Hello'));
    });

    test('buildSkillsSystemBlock formats active skill instructions', () {
      final block = SkillService.buildSkillsSystemBlock([SkillService.builtInSkills.first]);
      expect(block, contains('Active Skills'));
      expect(block, contains('/meeting-notes'));
    });
  });

  group('ContextUsage & Token Counting', () {
    test('computes used, remaining, and percentage correctly', () {
      const usage = ContextUsage(
        systemAndSkillsTokens: 200,
        ragTokens: 824,
        historyTokens: 1024,
        maxTokens: 4096,
        isExact: true,
      );
      expect(usage.usedTokens, equals(2048));
      expect(usage.remainingTokens, equals(2048));
      expect(usage.usedFraction, closeTo(0.5, 0.001));
      expect(usage.remainingPercent, equals(50));
    });

    test('clamps when over context limit', () {
      const over = ContextUsage(
        systemAndSkillsTokens: 500,
        ragTokens: 2000,
        historyTokens: 3000,
        maxTokens: 4096,
      );
      expect(over.remainingTokens, equals(0));
      expect(over.usedFraction, equals(1.0));
      expect(over.remainingPercent, equals(0));
    });

    test('AiService.countTokens estimates tokens offline', () async {
      final ai = AiService();
      final empty = await ai.countTokens('');
      expect(empty.tokens, equals(0));

      final sample = await ai.countTokens('Hello world, this is a test sentence for token counting.');
      expect(sample.tokens, greaterThan(5));
    });

    test('DiffService detects and trims runaway repetition loops', () {
      const normal = 'Chapters 1, 2, and 3 introduce the setting and characters cleanly.';
      expect(DiffService.hasRepetitionLoop(normal), isFalse);

      const looping = 'Conflict events (Chapter 14, 18, 1, 1, 1, 1, 1, 1, 1, 1, 1)';
      const rawLoop = 'Conflict events (Chapter 14, 18, 1, 1, 1, 1, 1, 1, 1, 1';
      expect(DiffService.hasRepetitionLoop(rawLoop), isTrue);
      final trimmed = DiffService.trimRepetitionLoop(rawLoop);
      expect(trimmed, isNot(contains('1, 1, 1, 1')));
      expect(looping.length, greaterThan(trimmed.length));
    });
  });

  group('AiPanel Context Bar, Skills, and Multimodal Controls', () {
    testWidgets('renders context bar, skills picker button, image and mic buttons', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                height: 700,
                child: AiPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('% left'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_mosaic_outlined), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      // Typing '/' should show the Antigravity-style slash-command skills popup
      await tester.enterText(find.byType(TextField), '/');
      await tester.pumpAndSettle();
      expect(find.text('SKILLS — Tap to insert'), findsOneWidget);
      expect(find.text('/meeting-notes'), findsOneWidget);

      // Tapping a skill inserts '/meeting-notes ' and closes the popup
      await tester.tap(find.text('/meeting-notes'));
      await tester.pumpAndSettle();
      expect(find.text('SKILLS — Tap to insert'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
