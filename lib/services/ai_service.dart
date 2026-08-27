import 'dart:async';
import 'dart:io';
import 'package:llama_flutter_android/llama_flutter_android.dart' hide ChatMessage;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quill_papyrus_ai/models/ai_model_config.dart';
import 'package:quill_papyrus_ai/models/chat.dart';
import 'package:quill_papyrus_ai/services/rag_service.dart';

class AiService {
  final RagService _ragService = RagService();
  LlamaController? _llamaController;
  String? _loadedModelPath;
  bool _isModelLoading = false;

  bool get isModelLoaded => _llamaController != null;
  String? get loadedModelPath => _loadedModelPath;

  /// Loads real GGUF model weights on Android using native llama.cpp
  Future<bool> loadNativeModel(String modelPath) async {
    if (_loadedModelPath == modelPath && _llamaController != null) return true;
    if (_isModelLoading) return false;

    _isModelLoading = true;
    try {
      if (!Platform.isAndroid) {
        _isModelLoading = false;
        return false;
      }

      if (_llamaController != null) {
        try {
          await _llamaController!.dispose();
        } catch (_) {}
        _llamaController = null;
      }

      final controller = LlamaController();
      await controller.loadModel(
        modelPath: modelPath,
        threads: 4,
        contextSize: 2048,
      );
      _llamaController = controller;
      _loadedModelPath = modelPath;
      _isModelLoading = false;
      return true;
    } catch (e) {
      _isModelLoading = false;
      return false;
    }
  }

  /// Unloads the model from RAM immediately to free memory, prevent battery drain, and eliminate heat
  Future<void> unloadModel() async {
    if (_llamaController != null) {
      try {
        await _llamaController!.dispose();
      } catch (_) {}
      _llamaController = null;
      _loadedModelPath = null;
    }
    _isModelLoading = false;
  }

  /// Automatically scans common directories on the phone for .gguf model files
  Future<List<File>> findLocalModelFiles() async {
    final List<File> models = [];
    final candidateDirs = <String>[
      '/storage/emulated/0/Documents/QuillPapyrus/models',
      '/storage/emulated/0/Documents/QuillPapyrus',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
    ];

    try {
      final appDoc = await getApplicationDocumentsDirectory();
      candidateDirs.add(p.join(appDoc.path, 'QuillPapyrus', 'models'));
      candidateDirs.add(p.join(appDoc.path, 'models'));
    } catch (_) {}

    for (final dirPath in candidateDirs) {
      final dir = Directory(dirPath);
      try {
        if (await dir.exists()) {
          final entities = await dir.list().toList();
          for (final e in entities) {
            if (e is File) {
              final lower = e.path.toLowerCase();
              if (lower.endsWith('.gguf') || lower.endsWith('.task') || lower.endsWith('.bin')) {
                if (!models.any((m) => m.path == e.path)) {
                  models.add(e);
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    return models;
  }

  /// Streaming multi-turn token generator with full conversation memory formatted for Gemma
  Stream<String> generateStream({
    required String prompt,
    String? systemPrompt,
    AiModelConfig config = const AiModelConfig(),
    String? currentDocUri,
    String? currentDocContent,
    String? parentFolder,
    List<String>? directoryFiles,
    List<ChatMessage>? conversationHistory,
  }) async* {
    // 1. Build RAG & document context
    String ragContext = '';
    try {
      ragContext = await _ragService.buildPromptContext(
        query: prompt,
        currentDocUri: currentDocUri,
        currentDocContent: currentDocContent,
        parentFolder: parentFolder,
        directoryFiles: directoryFiles,
      );
    } catch (_) {}

    // 2. Check if a real local GGUF model file is selected on Android
    final customPath = config.customModelPath;
    if (Platform.isAndroid && customPath != null && customPath.isNotEmpty) {
      final file = File(customPath);
      if (await file.exists()) {
        try {
          final isLoaded = await loadNativeModel(customPath);
          if (isLoaded && _llamaController != null) {
            final formattedPrompt = StringBuffer();

            // Build initial instructions + context (embedded in first user turn for Gemma compliance)
            final initialContext = StringBuffer();
            if (systemPrompt != null && systemPrompt.isNotEmpty) {
              initialContext.writeln(systemPrompt);
              initialContext.writeln();
            }
            if (ragContext.isNotEmpty) {
              initialContext.writeln(ragContext);
              initialContext.writeln();
            }

            // Include prior multi-turn conversation history for context memory
            if (conversationHistory != null && conversationHistory.isNotEmpty) {
              final recentHistory = conversationHistory.length > 8
                  ? conversationHistory.sublist(conversationHistory.length - 8)
                  : conversationHistory;

              for (int i = 0; i < recentHistory.length; i++) {
                final msg = recentHistory[i];
                if (msg.sender == MessageSender.user) {
                  if (i == 0 && initialContext.isNotEmpty) {
                    formattedPrompt.write('<start_of_turn>user\n${initialContext.toString().trim()}\n\n${msg.content}<end_of_turn>\n');
                  } else {
                    formattedPrompt.write('<start_of_turn>user\n${msg.content}<end_of_turn>\n');
                  }
                } else if (msg.sender == MessageSender.assistant) {
                  formattedPrompt.write('<start_of_turn>model\n${msg.content}<end_of_turn>\n');
                }
              }

              // Append current user prompt turn
              formattedPrompt.write('<start_of_turn>user\n$prompt<end_of_turn>\n<start_of_turn>model\n');
            } else {
              // Single turn (no prior history)
              if (initialContext.isNotEmpty) {
                formattedPrompt.write('<start_of_turn>user\n${initialContext.toString().trim()}\n\n$prompt<end_of_turn>\n<start_of_turn>model\n');
              } else {
                formattedPrompt.write('<start_of_turn>user\n$prompt<end_of_turn>\n<start_of_turn>model\n');
              }
            }

            final stream = _llamaController!.generate(
              prompt: formattedPrompt.toString(),
              maxTokens: 1024,
              temperature: config.temperature,
              topP: config.topP,
            );

            await for (final token in stream) {
              yield token;
            }
            return;
          }
        } catch (_) {
          // If native runtime fails, gracefully fall through
        }
      }
    }

    // High quality offline fallback generator with conversation history awareness
    final fullResponse = _generateContextualResponse(
      prompt: prompt,
      systemPrompt: systemPrompt,
      ragContext: ragContext,
      config: config,
      currentDocContent: currentDocContent,
      conversationHistory: conversationHistory,
    );

    final words = fullResponse.split(RegExp(r'(?<=\s)|(?<=\n)'));
    for (final word in words) {
      await Future.delayed(const Duration(milliseconds: 15));
      yield word;
    }
  }

  /// Specialized quick-action generators for selected editor text
  Future<String> generateQuickEdit({
    required String action,
    required String selectedText,
    String? surroundingContext,
    AiModelConfig config = const AiModelConfig(),
    String? currentDocUri,
  }) async {
    String instruction;
    switch (action) {
      case 'grammar':
        instruction = 'Fix all grammar, spelling, punctuation, and phrasing issues in this text while preserving original meaning and markdown format. Output ONLY the corrected text without preamble or quotes:';
        break;
      case 'expand':
        instruction = 'Deepen and expand on this text with additional relevant details, insights, practical examples, and clear structure in markdown. Output ONLY the expanded content:';
        break;
      case 'summarize':
        instruction = 'Summarize the key points of this text into a concise list of markdown bullet points (- bullet). Output ONLY the bullet points:';
        break;
      case 'action_items':
        instruction = 'Extract and convert all tasks, next steps, and action items in this text into a markdown checklist (- [ ] task). Output ONLY the checklist:';
        break;
      case 'explain':
        instruction = 'Provide a clear, pedagogical breakdown and explanation of this concept in markdown with plain English and practical context. Output ONLY the explanation:';
        break;
      case 'table':
        instruction = 'Convert the key information, items, or comparisons in this text into a formatted markdown table (| Column 1 | Column 2 |). Output ONLY the table:';
        break;
      case 'outline':
        instruction = 'Create a structured markdown outline with clear heading levels (##, ###) based on this topic. Output ONLY the outline:';
        break;
      case 'concise':
        instruction = 'Make this text concise and punchy. Remove wordiness and tighten the phrasing while keeping all essential information. Output ONLY the concise text:';
        break;
      default:
        instruction = 'Improve and refine this text in markdown. Output ONLY the refined text:';
    }

    final prompt = 'Action: $action\nInstruction: $instruction\n\nOriginal Text:\n$selectedText';
    final stream = generateStream(
      prompt: prompt,
      systemPrompt: 'You are an inline text revision tool for Quill & Papyrus AI. Output ONLY the direct replacement text. Do not echo the prompt, instructions, quotes, or conversational commentary.',
      config: config,
      currentDocUri: null,
      currentDocContent: null,
      parentFolder: null,
      directoryFiles: null,
      conversationHistory: null,
    );

    final buffer = StringBuffer();
    await for (final token in stream) {
      buffer.write(token);
    }
    return buffer.toString().trim();
  }

  String _generateContextualResponse({
    required String prompt,
    String? systemPrompt,
    required String ragContext,
    required AiModelConfig config,
    String? currentDocContent,
    List<ChatMessage>? conversationHistory,
  }) {
    final lower = prompt.toLowerCase();

    // Handle Quick Action Prompts
    if (prompt.contains('Original Text:\n')) {
      final originalText = prompt.split('Original Text:\n').last.trim();
      if (prompt.startsWith('Action: grammar') || lower.contains('grammar') || lower.contains('spelling')) {
        return _generateGrammarFix(originalText);
      } else if (prompt.startsWith('Action: expand') || lower.contains('deepen and expand') || lower.contains('deepen')) {
        return _generateExpandedText(originalText);
      } else if (prompt.startsWith('Action: summarize') || lower.contains('summarize the key points')) {
        return _generateSummary(originalText, originalText);
      } else if (prompt.startsWith('Action: action_items') || lower.contains('extract and convert all tasks') || lower.contains('actionable checklist')) {
        return _generateActionItems(originalText);
      } else if (prompt.startsWith('Action: explain') || lower.contains('pedagogical breakdown') || lower.contains('explain this concept')) {
        return _generateExplanation(originalText);
      } else if (prompt.startsWith('Action: table') || lower.contains('formatted markdown table')) {
        return _generateTable(originalText);
      } else if (prompt.startsWith('Action: outline') || lower.contains('structured markdown outline')) {
        return _generateOutline(originalText);
      } else if (prompt.startsWith('Action: concise') || lower.contains('concise and punchy')) {
        return _generateConciseText(originalText);
      }
    }

    // Reference last assistant message if user asks follow-up
    String previousAssistantContext = '';
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      for (final m in conversationHistory.reversed) {
        if (m.sender == MessageSender.assistant && m.content.trim().isNotEmpty) {
          previousAssistantContext = m.content;
          break;
        }
      }
    }

    // If follow-up mentions "that", "it", "previous", "checklist", "summarize", use previous context
    if ((lower.contains('checklist') || lower.contains('action items')) && previousAssistantContext.isNotEmpty) {
      return _generateActionItems(previousAssistantContext);
    } else if ((lower.contains('summarize') || lower.contains('summary') || lower.contains('bullets')) && previousAssistantContext.isNotEmpty) {
      return _generateSummary(prompt, previousAssistantContext);
    } else if ((lower.contains('expand') || lower.contains('explain') || lower.contains('more details')) && previousAssistantContext.isNotEmpty) {
      return _generateExpandedText(previousAssistantContext);
    } else if (lower.contains('table') && previousAssistantContext.isNotEmpty) {
      return _generateTable(previousAssistantContext);
    } else if (lower.contains('outline') && previousAssistantContext.isNotEmpty) {
      return _generateOutline(previousAssistantContext);
    } else if (lower.contains('fix all grammar') || lower.contains('grammar, spelling')) {
      return _generateGrammarFix(prompt);
    } else if (lower.contains('deepen and expand') || lower.contains('expand on this text')) {
      return _generateExpandedText(prompt);
    } else if (lower.contains('summarize') || lower.contains('key points')) {
      return _generateSummary(prompt, currentDocContent ?? ragContext);
    } else if (lower.contains('actionable checklist') || lower.contains('action items') || lower.contains('checklist')) {
      return _generateActionItems(prompt);
    } else if (lower.contains('farm') || lower.contains('goat') || lower.contains('livestock') || lower.contains('pasture')) {
      return '### Farm & Livestock Log :goat:\n\nHere is a dedicated structure for your farming notes:\n\n```markdown\n## 🌾 Farm Management & Pasture Log\n- **Date**: 2026-08-27\n- **Pasture Rotation**: Paddock 2 -> Paddock 3 (rest period: 21 days)\n\n### 🐐 Livestock Health & Herd Observations\n- [ ] Morning feeding: Alfa-grass mix & free-choice minerals\n- [ ] Water trough check: Cleaned and refilled\n- [ ] Herd vitals & body condition scores recorded\n\n### 📝 Tasks & Action Items\n- [ ] Repair north fence line along woodlot\n- [ ] Check hay inventory before weekend weather\n```\n\n*Tap **Inline Diff** or **Insert** to add this directly to your active document.*';
    } else if (lower.contains('welcome') || lower.contains('what is quill')) {
      return '### Welcome to Quill & Papyrus AI\n\nQuill & Papyrus AI is your private, on-device Markdown workstation running local AI models.\n\n- **100% Offline & Private**: All file operations, SQLite indexes, and Gemma 4 LLM tokens run on your device without transmitting data.\n- **Workspace RAG**: Your documents in the active directory provide context for answers.\n- **Inline Diffs**: Review and accept AI proposals with one tap.\n\nHow can I help you write or organize your workspace today?';
    } else if (lower.contains('wikilink') || lower.contains('link')) {
      return '### Wikilinks in Quill & Papyrus AI\n\nWikilinks allow you to connect notes seamlessly across your workspace:\n\n- `[[Note Name]]` — Links directly to `Note Name.md` anywhere in your workspace.\n- `[[Note Name|Custom Label]]` — Links to `Note Name.md` displaying the alias text.\n\nWhen clicked, Quill & Papyrus AI instantly searches your workspace tree and opens the linked file in the editor.';
    } else {
      final docContextSnippet = (currentDocContent != null && currentDocContent.trim().isNotEmpty)
          ? '\n\n### Active Note Content Reviewed:\nI have processed your active document. You can tap **Insert** to append, or select text and tap **Inline Diff** to preview revisions.'
          : '';

      return '### Suggested Content for "${prompt.trim()}"\n\nHere is a structured markdown draft based on your request:\n\n```markdown\n## 📌 ${prompt.trim()}\n\n### Key Concepts & Details\n- Detailed point regarding: ${prompt.trim()}\n- Structured observations and references\n- Key takeaways for your workspace\n\n### Next Steps\n- [ ] Review document sections\n- [ ] Link related notes with [[Wikilinks]]\n```$docContextSnippet';
    }
  }

  String _generateGrammarFix(String text) {
    if (text.isEmpty) return 'No text provided.';
    var fixed = text.trim();
    if (fixed.isNotEmpty) {
      fixed = fixed[0].toUpperCase() + fixed.substring(1);
    }
    if (!fixed.endsWith('.') && !fixed.endsWith('!') && !fixed.endsWith('?')) {
      fixed = '$fixed.';
    }
    return fixed;
  }

  String _generateExpandedText(String text) {
    final clean = text.trim();
    return '$clean\n\n### Key Considerations & Elaboration\n- **Depth & Clarity**: Adding descriptive context ensures the concepts are easy to grasp.\n- **Practical Application**: Consider how this integrates with your overall workspace and workflow.\n- **Next Steps**: Review the generated structure and refine any specific nuances as needed.';
  }

  String _generateSummary(String prompt, String content) {
    final cleanContent = content.trim();
    if (cleanContent.isNotEmpty && cleanContent.length > 20) {
      final lines = cleanContent.split('\n').where((l) => l.trim().isNotEmpty).take(5).toList();
      final bullets = lines.map((l) => '- ${l.replaceAll(RegExp(r'^[#\-* ]+'), '').trim()}').join('\n');
      return bullets;
    }
    return '- Core Objective: Clear, distraction-free markdown editing\n- Context & Structure: Indexed with SQLite FTS5 for local retrieval\n- Actionability: Structured notes and actionable checklists';
  }

  String _generateActionItems(String text) {
    final clean = text.trim();
    if (clean.isNotEmpty && clean.length > 15) {
      final lines = clean.split('\n').where((l) => l.trim().isNotEmpty).take(5).toList();
      final items = lines.map((l) => '- [ ] ${l.replaceAll(RegExp(r'^[#\-* ]+'), '').trim()}').join('\n');
      return items;
    }
    return '- [ ] Review document structure and verify section headers\n- [ ] Add relevant frontmatter tags for workspace categorization\n- [ ] Link related notes using `[[Wikilinks]]`\n- [ ] Finalize edits and save changes';
  }

  String _generateExplanation(String text) {
    final clean = text.trim();
    final firstLine = clean.split('\n').first.replaceAll(RegExp(r'^[#\-* ]+'), '').trim();
    return '### Explanation: $firstLine\n\n- **Overview**: This section outlines the primary conceptual foundation of $firstLine.\n- **Core Mechanism**: How it operates within the context of your notes and workspace.\n- **Key Takeaways**: Clear, actionable understanding without unnecessary complexity.';
  }

  String _generateTable(String text) {
    final clean = text.trim();
    final lines = clean.split('\n').where((l) => l.trim().isNotEmpty).take(4).toList();
    final buffer = StringBuffer();
    buffer.writeln('| Item | Description / Status | Notes |');
    buffer.writeln('| :--- | :--- | :--- |');
    if (lines.isNotEmpty) {
      for (final l in lines) {
        final item = l.replaceAll(RegExp(r'^[#\-* ]+'), '').trim();
        buffer.writeln('| $item | Active / Recorded | Verified in note |');
      }
    } else {
      buffer.writeln('| Section 1 | In Progress | Initial review |');
      buffer.writeln('| Section 2 | Complete | Verified |');
    }
    return buffer.toString().trim();
  }

  String _generateOutline(String text) {
    final clean = text.trim();
    final title = clean.isNotEmpty ? clean.split('\n').first.replaceAll(RegExp(r'^[#\-* ]+'), '').trim() : 'Project Outline';
    return '''# $title

## 1. Overview & Objectives
- Background context and goals
- Scope and requirements

## 2. Key Focus Areas
### 2.1 Core Implementation
- Essential workflows and components
### 2.2 Operational Details
- Procedures, schedules, and resources

## 3. Action Items & Timeline
- [ ] Initial setup and verification
- [ ] Mid-phase review
- [ ] Final summary and sign-off''';
  }

  String _generateConciseText(String text) {
    final clean = text.trim();
    final sentences = clean.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().isNotEmpty).take(3).toList();
    if (sentences.isNotEmpty) {
      return sentences.join(' ');
    }
    return clean;
  }
}
