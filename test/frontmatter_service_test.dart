import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';

void main() {
  group('FrontMatterService', () {
    test('parses front-matter with title, tags, and date', () {
      const content = '''---
title: "My Document"
tags:
  - flutter
  - markdown
date: 2026-08-26T12:00:00.000Z
custom_author: "Antigravity"
---

# Main Content
This is the document body.
''';

      final data = FrontMatterService.parse(content);
      expect(data, isNotNull);
      expect(data!.title, 'My Document');
      expect(data.tags, ['flutter', 'markdown']);
      expect(data.date, DateTime.parse('2026-08-26T12:00:00.000Z'));
      expect(data.customFields['custom_author'], 'Antigravity');
    });

    test('parses comma-separated tags string', () {
      const content = '''---
title: Quick Note
tags: ideas, rust, mobile
---
Note body
''';

      final data = FrontMatterService.parse(content);
      expect(data, isNotNull);
      expect(data!.tags, ['ideas', 'rust', 'mobile']);
    });

    test('returns null when no front-matter is present', () {
      const content = '# Title\nJust body text';
      final data = FrontMatterService.parse(content);
      expect(data, isNull);
    });

    test('strips front-matter cleanly', () {
      const content = '''---
title: Test
---
# Actual Heading
Body paragraph.
''';

      final stripped = FrontMatterService.stripFrontMatter(content);
      expect(stripped.trim(), '# Actual Heading\nBody paragraph.');
    });

    test('adds or updates front-matter', () {
      const original = '# Hello World';
      final data = FrontMatterData(
        title: 'New Title',
        tags: ['alpha', 'beta'],
      );

      final updated = FrontMatterService.addOrUpdateFrontMatter(original, data);
      expect(updated.contains('title: "New Title"'), isTrue);
      expect(updated.contains('tags: [alpha, beta]'), isTrue);
      expect(updated.contains('# Hello World'), isTrue);
    });

    test('toggles tags in frontmatter automatically', () {
      const doc = '''---
title: "My Note"
tags: [sample, ideas]
---

# Note Content
''';

      // Toggle existing tag 'sample' -> removes it
      final withoutSample = FrontMatterService.toggleTag(doc, 'sample');
      expect(FrontMatterService.hasTag(withoutSample, 'sample'), isFalse);
      expect(FrontMatterService.hasTag(withoutSample, 'ideas'), isTrue);

      // Toggle new tag 'project' -> adds it
      final withProject = FrontMatterService.toggleTag(withoutSample, 'project');
      expect(FrontMatterService.hasTag(withProject, 'project'), isTrue);
      expect(FrontMatterService.hasTag(withProject, 'ideas'), isTrue);

      // Toggle tag on document without frontmatter -> creates frontmatter
      const plainDoc = '# Plain Document\nSome content';
      final withCreatedTag = FrontMatterService.toggleTag(plainDoc, 'newtag');
      expect(FrontMatterService.hasTag(withCreatedTag, 'newtag'), isTrue);
      expect(withCreatedTag.contains('# Plain Document'), isTrue);
    });
  });
}
