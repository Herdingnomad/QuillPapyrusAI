import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/workspace_state.dart';
import 'package:quill_papyrus_ai/providers/tag_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/ai_service.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/services/saf_storage_service.dart';

void main() {
  group('Tags and Topics Indexing and Filtering Tests', () {
    test('WorkspaceState maintains tag and topic indices', () {
      final state = WorkspaceState(
        tags: ['flutter', 'ai'],
        tagIndex: {
          'flutter': ['/doc1.md', '/doc2.md'],
          'ai': ['/doc2.md'],
        },
        topics: ['mobile', 'research'],
        topicIndex: {
          'mobile': ['/doc1.md'],
          'research': ['/doc2.md'],
        },
      );

      expect(state.tags, containsAll(['flutter', 'ai']));
      expect(state.tagIndex['flutter'], hasLength(2));
      expect(state.topics, containsAll(['mobile', 'research']));
      expect(state.topicIndex['research'], contains('/doc2.md'));
    });

    test('Topic toggle in document content', () {
      const doc = '''---
title: "Project Notes"
topics: [planning, architecture]
---
# Body
''';

      // Toggle existing topic -> removes it
      final withoutPlanning = FrontMatterService.toggleTopic(doc, 'planning');
      expect(FrontMatterService.hasTopic(withoutPlanning, 'planning'), isFalse);
      expect(FrontMatterService.hasTopic(withoutPlanning, 'architecture'), isTrue);

      // Toggle new topic -> adds it
      final withHardware = FrontMatterService.toggleTopic(withoutPlanning, 'hardware');
      expect(FrontMatterService.hasTopic(withHardware, 'hardware'), isTrue);
      expect(FrontMatterService.hasTopic(withHardware, 'architecture'), isTrue);
    });

    test('Tag and Topic intersection filtering in ProviderContainer', () {
      final container = ProviderContainer(
        overrides: [
          workspaceProvider.overrideWith((ref) {
            final notifier = WorkspaceNotifier(SafStorageService());
            notifier.state = notifier.state.copyWith(
              tags: ['journaling', 'tech'],
              tagIndex: {
                'journaling': ['/journals/today.md', '/journals/yesterday.md'],
                'tech': ['/journals/today.md', '/docs/readme.md'],
              },
              topics: ['writing', 'hardware'],
              topicIndex: {
                'writing': ['/journals/today.md', '/journals/yesterday.md'],
                'hardware': ['/docs/readme.md'],
              },
            );
            return notifier;
          }),
        ],
      );

      // Initially no filter is active
      expect(container.read(activeTagFilterProvider), isNull);
      expect(container.read(activeTopicFilterProvider), isNull);
      expect(container.read(filteredFileUrisProvider), isNull);

      // Filter by tag 'journaling'
      container.read(activeTagFilterProvider.notifier).state = 'journaling';
      expect(container.read(filteredFileUrisProvider), containsAll(['/journals/today.md', '/journals/yesterday.md']));
      expect(container.read(filteredFileUrisProvider), isNot(contains('/docs/readme.md')));

      // Filter by both tag 'tech' and topic 'writing' -> intersection is only /journals/today.md
      container.read(activeTagFilterProvider.notifier).state = 'tech';
      container.read(activeTopicFilterProvider.notifier).state = 'writing';
      final filtered = container.read(filteredFileUrisProvider);
      expect(filtered, equals(['/journals/today.md']));

      // Filter by topic 'hardware' only
      container.read(activeTagFilterProvider.notifier).state = null;
      container.read(activeTopicFilterProvider.notifier).state = 'hardware';
      expect(container.read(filteredFileUrisProvider), equals(['/docs/readme.md']));
    });

    test('FrontMatterService generates full journal entry structure', () {
      final now = DateTime(2025, 9, 5);
      final fm = FrontMatterService.generateFullFrontMatter(
        title: 'Journal Entry - Coffee & App Testing',
        date: now,
        dayOfWeek: 'Saturday',
        mood: 'Reflective / Productive',
        tags: ['journaling', 'technology', 'productivity', 'personal_log'],
        topics: ['writing', 'journaling', 'app_testing', 'hardware'],
        status: 'complete',
      );

      expect(fm.contains('title: Journal Entry - Coffee & App Testing'), isTrue);
      expect(fm.contains('date: 2025-09-05'), isTrue);
      expect(fm.contains('day_of_week: Saturday'), isTrue);
      expect(fm.contains('mood: Reflective / Productive'), isTrue);
      expect(fm.contains('tags: [journaling, technology, productivity, personal_log]'), isTrue);
      expect(fm.contains('topics: [writing, journaling, app_testing, hardware]'), isTrue);
      expect(fm.contains('status: complete'), isTrue);
    });

    test('AiService generates intelligent frontmatter from document content', () async {
      final aiService = AiService();
      const content = '''# Morning Coffee & App Testing
Enjoying a quiet morning coffee while running automated tests on the mobile app.
We need to verify hardware compatibility and complete the remaining tasks.

- [ ] Check Bluetooth connectivity
''';

      final inferred = await aiService.generateFrontMatterForDocument(
        documentContent: content,
        workspaceTags: ['journaling', 'technology'],
        workspaceTopics: ['app_testing', 'hardware'],
      );

      expect(inferred.title, 'Morning Coffee & App Testing');
      expect(inferred.mood, 'Reflective / Productive');
      expect(inferred.tags, containsAll(['journaling', 'technology']));
      expect(inferred.topics, containsAll(['app_testing', 'hardware']));
      expect(inferred.status, 'in_progress'); // because of uncompleted checklist '- [ ]'
    });

    test('AiService generates document templates with frontmatter and markdown body', () {
      final aiService = AiService();

      // Journal template
      final journalTemplate = aiService.generateDocumentTemplate(templateTypeOrPrompt: 'daily_journal');
      expect(journalTemplate.startsWith('---'), isTrue);
      expect(journalTemplate.contains('title: Journal Entry - Coffee & App Testing'), isTrue);
      expect(journalTemplate.contains('mood: Reflective / Productive'), isTrue);
      expect(journalTemplate.contains('tags: [journaling, technology, productivity, personal_log]'), isTrue);
      expect(journalTemplate.contains('topics: [writing, journaling, app_testing, hardware]'), isTrue);
      expect(journalTemplate.contains('# ☕ Daily Journal'), isTrue);

      // Custom topic template
      final customTemplate = aiService.generateDocumentTemplate(templateTypeOrPrompt: 'Colorado Mountain Hike');
      expect(customTemplate.startsWith('---'), isTrue);
      expect(customTemplate.contains('title: Colorado Mountain Hike'), isTrue);
      expect(customTemplate.contains('topics: [writing, research, planning]'), isTrue);
      expect(customTemplate.contains('# 📌 Colorado Mountain Hike'), isTrue);
    });
  });
}
