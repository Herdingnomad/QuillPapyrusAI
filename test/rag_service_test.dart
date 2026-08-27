import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/services/rag_service.dart';

void main() {
  group('RagService', () {
    test('builds prompt context with active document and headings', () async {
      final rag = RagService();

      const docContent = '''---
title: Getting Started
tags: [tutorial]
---

# Introduction
This is the active document content.

## Section 1
Detailed instructions go here.
''';

      final context = await rag.buildPromptContext(
        query: 'instructions',
        currentDocUri: '/storage/emulated/0/Documents/GettingStarted.md',
        currentDocContent: docContent,
        parentFolder: 'Documents',
      );

      expect(context.contains('Active Document Context (GettingStarted.md)'), isTrue);
      expect(context.contains('This is the active document content'), isTrue);
    });
  });
}
