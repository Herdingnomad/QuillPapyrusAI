import 'dart:async';
import 'dart:io';
import 'package:llama_flutter_android/llama_flutter_android.dart' hide ChatMessage;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quill_papyrus_ai/models/ai_model_config.dart';
import 'package:quill_papyrus_ai/models/chat.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
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
    if (!Platform.isAndroid) {
      _isModelLoading = false;
      return false;
    }

    if (_loadedModelPath == modelPath && _llamaController != null) {
      try {
        if (await _llamaController!.isModelLoaded()) return true;
      } catch (_) {}
    }
    if (_isModelLoading) return false;

    _isModelLoading = true;
    try {
      final file = File(modelPath);
      if (!await file.exists()) {
        _isModelLoading = false;
        return false;
      }

      // Verify file is readable and begins with GGUF magic bytes: 'G', 'G', 'U', 'F' (0x47, 0x47, 0x55, 0x46)
      try {
        final sampleBytes = await file.openRead(0, 4).first;
        if (sampleBytes.length < 4 ||
            sampleBytes[0] != 0x47 ||
            sampleBytes[1] != 0x47 ||
            sampleBytes[2] != 0x55 ||
            sampleBytes[3] != 0x46) {
          _isModelLoading = false;
          return false;
        }
      } catch (_) {
        _isModelLoading = false;
        return false;
      }

      // Cleanly dispose prior controller if active
      if (_llamaController != null) {
        try {
          await _llamaController!.dispose();
        } catch (_) {}
        _llamaController = null;
        _loadedModelPath = null;
      }

      final freshController = LlamaController();
      
      // If native engine already had a model loaded from another instance, dispose it first
      try {
        if (await freshController.isModelLoaded()) {
          await freshController.dispose();
        }
      } catch (_) {}

      // Safely detect GPU Vulkan acceleration support
      int? recommendedGpuLayers;
      try {
        final gpu = await freshController.detectGpu();
        if (gpu.vulkanSupported && gpu.recommendedGpuLayers > 0) {
          recommendedGpuLayers = gpu.recommendedGpuLayers;
        }
      } catch (_) {}

      await freshController.loadModel(
        modelPath: modelPath,
        threads: 4,
        contextSize: 2048,
        gpuLayers: recommendedGpuLayers,
      );
      _llamaController = freshController;
      _loadedModelPath = modelPath;
      _isModelLoading = false;
      return true;
    } catch (e) {
      _isModelLoading = false;
      if (_llamaController != null) {
        try {
          await _llamaController!.dispose();
        } catch (_) {}
        _llamaController = null;
      }
      _loadedModelPath = null;
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

  /// Canonicalizes an Android storage path to avoid duplicate /sdcard symlink entries
  static String canonicalizePath(String path) {
    var s = path.trim();
    if (s.startsWith('/sdcard/')) {
      s = s.replaceFirst('/sdcard/', '/storage/emulated/0/');
    }
    return s;
  }

  /// Automatically scans common directories on the phone for .gguf model files
  Future<List<File>> findLocalModelFiles() async {
    final List<File> models = [];
    final seenPaths = <String>{};

    final candidateDirs = <String>[
      '/storage/emulated/0/Documents/QuillPapyrus/models',
      '/storage/emulated/0/Documents/QuillPapyrus',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
    ];

    // Fallback to /sdcard alias only if /storage/emulated/0 does not exist
    if (!Directory('/storage/emulated/0').existsSync()) {
      candidateDirs.addAll([
        '/sdcard/Documents/QuillPapyrus/models',
        '/sdcard/Documents/QuillPapyrus',
        '/sdcard/Download',
        '/sdcard/Documents',
      ]);
    }

    try {
      final appDoc = await getApplicationDocumentsDirectory();
      candidateDirs.add(p.join(appDoc.path, 'QuillPapyrus', 'models'));
      candidateDirs.add(p.join(appDoc.path, 'models'));
    } catch (_) {}

    for (final dirPath in candidateDirs) {
      final dir = Directory(dirPath);
      try {
        if (await dir.exists()) {
          final stream = dir.list(followLinks: false);
          await for (final e in stream.handleError((_) {})) {
            if (e is File) {
              final lower = e.path.toLowerCase();
              if (lower.endsWith('.gguf')) {
                final canonical = canonicalizePath(e.path);
                if (seenPaths.add(canonical)) {
                  models.add(File(canonical));
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    return models;
  }

  /// Resolves the optimal local .gguf model file path on device based on config and available files
  Future<String?> resolveModelPath(AiModelConfig config) async {
    if (!Platform.isAndroid) return null;

    // 1. Explicit path if specified and exists
    if (config.customModelPath != null && config.customModelPath!.isNotEmpty) {
      if (await File(config.customModelPath!).exists()) {
        return config.customModelPath;
      }
    }

    // 2. Currently loaded model path if still valid
    if (_loadedModelPath != null && await File(_loadedModelPath!).exists()) {
      return _loadedModelPath;
    }

    // 3. Scan local directories
    final localFiles = await findLocalModelFiles();
    if (localFiles.isEmpty) return null;

    if (config.modelType == GemmaModelType.gemma4E4B) {
      final match = localFiles.firstWhere(
        (f) {
          final lp = f.path.toLowerCase();
          return lp.contains('4b') || lp.contains('4-e4b');
        },
        orElse: () => localFiles.first,
      );
      return match.path;
    } else if (config.modelType == GemmaModelType.gemma4E2B) {
      final match = localFiles.firstWhere(
        (f) {
          final lp = f.path.toLowerCase();
          return lp.contains('2b') || lp.contains('4-e2b');
        },
        orElse: () => localFiles.first,
      );
      return match.path;
    }

    return localFiles.first.path;
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

    // 2. Check if a real local GGUF model file is available on Android
    if (Platform.isAndroid) {
      String? modelPath = config.customModelPath;
      if (modelPath == null || modelPath.isEmpty) {
        modelPath = _loadedModelPath ?? await resolveModelPath(config);
      }
      if (modelPath != null && modelPath.isNotEmpty) {
        final file = File(modelPath);
        if (await file.exists()) {
          bool isLoaded = false;
          try {
            isLoaded = await loadNativeModel(modelPath);
          } catch (_) {}

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

            if (_llamaController!.isGenerating) {
              try {
                await _llamaController!.stop();
              } catch (_) {}
            }

            Stream<String>? stream;
            try {
              stream = _llamaController!.generate(
                prompt: formattedPrompt.toString(),
                maxTokens: config.maxTokens > 0 ? config.maxTokens : 1024,
                temperature: config.temperature,
                topP: config.topP,
              );
            } catch (_) {}

            if (stream != null) {
              bool receivedToken = false;
              await for (final token in stream) {
                receivedToken = true;
                if (token.contains('<end_of_turn>')) {
                  final clean = token.replaceAll('<end_of_turn>', '');
                  if (clean.isNotEmpty) {
                    yield clean;
                  }
                  break;
                }
                if (token.contains('<start_of_turn>')) {
                  final clean = token.replaceAll('<start_of_turn>', '');
                  if (clean.isNotEmpty) {
                    yield clean;
                  }
                  continue;
                }
                yield token;
              }

              if (receivedToken) {
                return;
              }
            }
          }
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
    return DiffService.cleanSpecialTokens(buffer.toString());
  }

  /// Analyzes document content and workspace context to generate intelligent FrontMatterData
  Future<FrontMatterData> generateFrontMatterForDocument({
    required String documentContent,
    String? fallbackTitle,
    List<String> workspaceTags = const [],
    List<String> workspaceTopics = const [],
    AiModelConfig config = const AiModelConfig(),
  }) async {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final defaultDow = weekdays[now.weekday - 1];

    final existing = FrontMatterService.parse(documentContent);
    final cleanBody = FrontMatterService.stripFrontMatter(documentContent).trim();

    // 1. Infer Title
    String inferredTitle = existing?.title ?? '';
    if (inferredTitle.isEmpty) {
      final headingMatch = RegExp(r'^#+\s+(.+)$', multiLine: true).firstMatch(cleanBody);
      if (headingMatch != null) {
        inferredTitle = headingMatch.group(1)!.trim();
        inferredTitle = inferredTitle.replaceAll(RegExp(r'^[^\w\s]+'), '').trim();
      } else if (cleanBody.isNotEmpty) {
        final firstLine = cleanBody.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
        if (firstLine.isNotEmpty) {
          inferredTitle = firstLine.length > 50 ? '${firstLine.substring(0, 47)}...' : firstLine;
        }
      }
      if (inferredTitle.isEmpty && fallbackTitle != null && fallbackTitle.isNotEmpty) {
        inferredTitle = fallbackTitle.endsWith('.md') ? fallbackTitle.substring(0, fallbackTitle.length - 3) : fallbackTitle;
      }
      if (inferredTitle.isEmpty) {
        inferredTitle = 'Journal Entry - ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      }
    }

    // 2. Infer Date & Day of Week
    DateTime inferredDate = existing?.date ?? now;
    String inferredDayOfWeek = existing?.dayOfWeek ?? defaultDow;

    final dateMatch = RegExp(r'\b(20\d{2}-\d{2}-\d{2})\b').firstMatch(cleanBody);
    if (dateMatch != null) {
      final parsed = DateTime.tryParse(dateMatch.group(1)!);
      if (parsed != null) {
        inferredDate = parsed;
        inferredDayOfWeek = weekdays[inferredDate.weekday - 1];
      }
    }

    final lower = cleanBody.toLowerCase();

    // 3. Infer Mood
    String inferredMood = existing?.mood ?? '';
    if (inferredMood.isEmpty) {
      if (lower.contains('coffee') || lower.contains('morning') || lower.contains('reflect') || lower.contains('gratitude') || lower.contains('journal')) {
        inferredMood = 'Reflective / Productive';
      } else if (lower.contains('goat') || lower.contains('pasture') || lower.contains('farm') || lower.contains('livestock') || lower.contains('hay') || lower.contains('soil')) {
        inferredMood = 'Grounded / Attentive';
      } else if (lower.contains('bug') || lower.contains('fix') || lower.contains('error') || lower.contains('test') || lower.contains('debug') || lower.contains('issue')) {
        inferredMood = 'Analytical / Focused';
      } else if (lower.contains('design') || lower.contains('architecture') || lower.contains('feature') || lower.contains('build') || lower.contains('create')) {
        inferredMood = 'Creative / Deliberate';
      } else if (lower.contains('urgent') || lower.contains('incident') || lower.contains('critical') || lower.contains('blocker')) {
        inferredMood = 'Urgent / Focused';
      } else if (lower.contains('meeting') || lower.contains('sync') || lower.contains('discuss') || lower.contains('team') || lower.contains('call')) {
        inferredMood = 'Collaborative / Direct';
      } else {
        inferredMood = 'Reflective / Productive';
      }
    }

    // 4. Infer Tags
    final Set<String> tagSet = Set.from(existing?.tags ?? []);
    for (final wt in workspaceTags) {
      final clean = wt.trim().replaceAll('#', '').toLowerCase();
      if (clean.isNotEmpty && clean.length >= 2) {
        final pattern = RegExp('\\b${RegExp.escape(clean)}\\b', caseSensitive: false);
        if (pattern.hasMatch(cleanBody)) {
          tagSet.add(clean);
        }
      }
    }
    if (lower.contains('journal') || lower.contains('diary') || lower.contains('morning') || lower.contains('coffee')) {
      tagSet.add('journaling');
    }
    if (lower.contains('code') || lower.contains('flutter') || lower.contains('dart') || lower.contains('app') || lower.contains('tech') || lower.contains('software')) {
      tagSet.add('technology');
    }
    if (lower.contains('ai') || lower.contains('llm') || lower.contains('model') || lower.contains('inference')) {
      tagSet.add('ai');
    }
    if (lower.contains('task') || lower.contains('todo') || lower.contains('progress') || lower.contains('goal') || lower.contains('productivity')) {
      tagSet.add('productivity');
    }
    if (lower.contains('personal') || lower.contains('life') || lower.contains('reflection') || lower.contains('daily')) {
      tagSet.add('personal_log');
    }
    if (lower.contains('farm') || lower.contains('goat') || lower.contains('livestock') || lower.contains('pasture')) {
      tagSet.addAll(['homestead', 'livestock']);
    }
    if (lower.contains('meeting') || lower.contains('agenda') || lower.contains('discussion')) {
      tagSet.add('meeting');
    }
    if (lower.contains('project') || lower.contains('architecture') || lower.contains('spec')) {
      tagSet.add('project_notes');
    }
    if (tagSet.isEmpty) {
      tagSet.addAll(['journaling', 'notes']);
    }

    // 5. Infer Topics
    final Set<String> topicSet = Set.from(existing?.topics ?? []);
    for (final wtop in workspaceTopics) {
      final clean = wtop.trim().replaceAll('@', '').toLowerCase();
      if (clean.isNotEmpty && clean.length >= 2) {
        final pattern = RegExp('\\b${RegExp.escape(clean)}\\b', caseSensitive: false);
        if (pattern.hasMatch(cleanBody)) {
          topicSet.add(clean);
        }
      }
    }
    if (lower.contains('write') || lower.contains('writing') || lower.contains('note') || lower.contains('document')) {
      topicSet.add('writing');
    }
    if (lower.contains('journal') || lower.contains('reflection')) {
      topicSet.add('journaling');
    }
    if (lower.contains('test') || lower.contains('app') || lower.contains('software') || lower.contains('feature') || lower.contains('dev')) {
      topicSet.addAll(['app_testing', 'development']);
    }
    if (lower.contains('hardware') || lower.contains('device') || lower.contains('phone') || lower.contains('sensor')) {
      topicSet.add('hardware');
    }
    if (lower.contains('farm') || lower.contains('livestock') || lower.contains('agriculture') || lower.contains('pasture')) {
      topicSet.addAll(['agriculture', 'pasture_management']);
    }
    if (lower.contains('research') || lower.contains('study') || lower.contains('analysis')) {
      topicSet.add('research');
    }
    if (lower.contains('plan') || lower.contains('milestone') || lower.contains('roadmap')) {
      topicSet.add('planning');
    }
    if (topicSet.isEmpty) {
      topicSet.addAll(['writing', 'journaling']);
    }

    // 6. Infer Status
    String inferredStatus = existing?.status ?? '';
    if (inferredStatus.isEmpty) {
      if (cleanBody.contains('- [ ]') || lower.contains('wip') || lower.contains('in progress') || lower.contains('draft') || lower.contains('todo')) {
        inferredStatus = 'in_progress';
      } else if (cleanBody.length > 200 && !cleanBody.contains('- [ ]')) {
        inferredStatus = 'complete';
      } else {
        inferredStatus = "complete # Or 'in_progress' if you plan to edit it heavily later";
      }
    }

    final baseline = FrontMatterData(
      title: inferredTitle,
      date: inferredDate,
      dayOfWeek: inferredDayOfWeek,
      mood: inferredMood,
      tags: tagSet.toList()..sort(),
      topics: topicSet.toList()..sort(),
      status: inferredStatus,
      customFields: existing?.customFields ?? {},
    );

    // If there is document body content, ask the AI model to analyze it and produce tailored metadata
    if (cleanBody.isNotEmpty) {
      try {
        final dStr = "${inferredDate.year}-${inferredDate.month.toString().padLeft(2, '0')}-${inferredDate.day.toString().padLeft(2, '0')}";
        final prompt = StringBuffer();
        prompt.writeln('Analyze the following markdown document content and extract YAML frontmatter metadata:');
        if (workspaceTags.isNotEmpty) {
          prompt.writeln('Available Workspace Tags: ${workspaceTags.map((t) => '#$t').join(', ')}');
        }
        if (workspaceTopics.isNotEmpty) {
          prompt.writeln('Available Workspace Topics: ${workspaceTopics.map((t) => '@$t').join(', ')}');
        }
        prompt.writeln('\nDocument Content:\n"""\n${cleanBody.length > 2000 ? cleanBody.substring(0, 2000) : cleanBody}\n"""\n');
        prompt.writeln('Extract and output the metadata fields in this exact format:');
        prompt.writeln('TITLE: <Descriptive document title>');
        prompt.writeln('DATE: $dStr');
        prompt.writeln('DAY_OF_WEEK: $inferredDayOfWeek');
        prompt.writeln('MOOD: <Descriptive mood or tone>');
        prompt.writeln('TAGS: <comma-separated lowercase tags>');
        prompt.writeln('TOPICS: <comma-separated lowercase topics>');
        prompt.writeln('STATUS: <complete or in_progress>');

        final stream = generateStream(
          prompt: prompt.toString(),
          systemPrompt: 'You are an AI metadata analyzer. Output ONLY the TITLE, DATE, DAY_OF_WEEK, MOOD, TAGS, TOPICS, and STATUS fields. Do not include markdown fences, comments, or conversational text.',
          config: config,
        );

        final buffer = StringBuffer();
        await for (final token in stream) {
          buffer.write(token);
        }

        final aiResponse = buffer.toString().trim();
        if (aiResponse.isNotEmpty) {
          return _parseAiFrontMatterResponse(aiResponse, baseline);
        }
      } catch (_) {}
    }

    return baseline;
  }

  String _cleanFrontMatterValue(String val) {
    var s = DiffService.cleanSpecialTokens(val);
    while (s.startsWith('"') || s.startsWith("'")) {
      s = s.substring(1).trim();
    }
    while (s.endsWith('"') || s.endsWith("'")) {
      s = s.substring(0, s.length - 1).trim();
    }
    return DiffService.cleanSpecialTokens(s);
  }

  FrontMatterData _parseAiFrontMatterResponse(String response, FrontMatterData baseline) {
    String? title;
    DateTime? date;
    String? dayOfWeek;
    String? mood;
    List<String>? tags;
    List<String>? topics;
    String? status;

    final titleMatch = RegExp(r'(?:title|TITLE)\s*:\s*([^\n\r]+)', caseSensitive: false).firstMatch(response);
    if (titleMatch != null) {
      final t = _cleanFrontMatterValue(titleMatch.group(1)!);
      if (t.isNotEmpty && !t.contains('<')) title = t;
    }

    final dateMatch = RegExp(r'(?:date|DATE)\s*:\s*([^\n\r]+)', caseSensitive: false).firstMatch(response);
    if (dateMatch != null) {
      final dStr = _cleanFrontMatterValue(dateMatch.group(1)!);
      final parsed = DateTime.tryParse(dStr);
      if (parsed != null) date = parsed;
    }

    final dowMatch = RegExp(r'(?:day_of_week|DAY_OF_WEEK|day|DAY)\s*:\s*([^\n\r]+)', caseSensitive: false).firstMatch(response);
    if (dowMatch != null) {
      final dow = _cleanFrontMatterValue(dowMatch.group(1)!);
      if (dow.isNotEmpty && !dow.contains('<')) dayOfWeek = dow;
    }

    final moodMatch = RegExp(r'(?:mood|MOOD)\s*:\s*([^\n\r]+)', caseSensitive: false).firstMatch(response);
    if (moodMatch != null) {
      final m = _cleanFrontMatterValue(moodMatch.group(1)!);
      if (m.isNotEmpty && !m.contains('<')) mood = m;
    }

    final tagsMatch = RegExp(r'(?:tags|TAGS)\s*:\s*([^\n\r]+)', caseSensitive: false).firstMatch(response);
    if (tagsMatch != null) {
      final rawTags = tagsMatch.group(1)!
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll('#', '')
          .trim();
      final split = rawTags
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty && !s.contains('<'))
          .toList();
      if (split.isNotEmpty) tags = split;
    }

    final topicsMatch = RegExp(r'(?:topics|TOPICS)\s*:\s*([^\n\r]+)', caseSensitive: false).firstMatch(response);
    if (topicsMatch != null) {
      final rawTopics = topicsMatch.group(1)!
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll('@', '')
          .trim();
      final split = rawTopics
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty && !s.contains('<'))
          .toList();
      if (split.isNotEmpty) topics = split;
    }

    final statusMatch = RegExp(r'(?:status|STATUS)\s*:\s*([^\n\r]+)', caseSensitive: false).firstMatch(response);
    if (statusMatch != null) {
      final s = _cleanFrontMatterValue(statusMatch.group(1)!).toLowerCase();
      if (s.contains('progress') || s.contains('wip') || s.contains('draft')) {
        status = 'in_progress';
      } else if (s.contains('complete') || s.contains('done')) {
        status = 'complete';
      }
    }

    return FrontMatterData(
      title: title ?? baseline.title,
      date: date ?? baseline.date,
      dayOfWeek: dayOfWeek ?? baseline.dayOfWeek,
      mood: mood ?? baseline.mood,
      tags: tags ?? baseline.tags,
      topics: topics ?? baseline.topics,
      status: status ?? baseline.status,
      customFields: baseline.customFields,
    );
  }

  /// Generates a full markdown document containing frontmatter and structured markdown template body using the AI model
  Future<String> generateDocumentTemplateWithAi({
    required String templateTypeOrPrompt,
    List<String> workspaceTags = const [],
    List<String> workspaceTopics = const [],
    AiModelConfig config = const AiModelConfig(),
  }) async {
    final prompt = StringBuffer();
    prompt.writeln('Generate a complete, structured Markdown document template based on this request:');
    prompt.writeln('Request / Topic: "$templateTypeOrPrompt"');
    if (workspaceTags.isNotEmpty) {
      prompt.writeln('Workspace Tags: ${workspaceTags.map((t) => '#$t').join(', ')}');
    }
    if (workspaceTopics.isNotEmpty) {
      prompt.writeln('Workspace Topics: ${workspaceTopics.map((t) => '@$t').join(', ')}');
    }
    prompt.writeln('\nRequirements:');
    prompt.writeln('1. Begin with a valid YAML Frontmatter block (---) containing title, date, day_of_week, mood, tags, topics, status.');
    prompt.writeln('2. Follow with clear, beautifully structured markdown sections, headings (##, ###), an overview, key details, checklists (- [ ]), and notes.');
    prompt.writeln('3. Output ONLY the raw markdown content without explanations or conversational preamble.');

    try {
      final stream = generateStream(
        prompt: prompt.toString(),
        systemPrompt: 'You are an expert Markdown document architect for Quill & Papyrus AI. Output ONLY the full markdown document including YAML frontmatter. Do not include conversational remarks.',
        config: config,
      );

      final buffer = StringBuffer();
      await for (final token in stream) {
        buffer.write(token);
      }
      final result = buffer.toString().trim();
      final clean = DiffService.cleanSpecialTokens(DiffService.extractCleanAiContent(result));
      if (clean.isNotEmpty && clean.contains('---')) {
        return clean;
      }
    } catch (_) {}

    return generateDocumentTemplate(
      templateTypeOrPrompt: templateTypeOrPrompt,
      workspaceTags: workspaceTags,
      workspaceTopics: workspaceTopics,
    );
  }

  /// Generates a full markdown document containing frontmatter and structured markdown template body
  String generateDocumentTemplate({
    required String templateTypeOrPrompt,
    List<String> workspaceTags = const [],
    List<String> workspaceTopics = const [],
  }) {
    final now = DateTime.now();
    final dStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dow = weekdays[now.weekday - 1];

    final key = templateTypeOrPrompt.toLowerCase().trim();

    if (key.contains('journal') || key == 'daily_journal' || key.contains('coffee')) {
      return '''---
title: Journal Entry - Coffee & App Testing
date: $dStr
day_of_week: $dow
mood: Reflective / Productive
tags: [journaling, technology, productivity, personal_log]
topics: [writing, journaling, app_testing, hardware]
status: complete # Or 'in_progress' if you plan to edit it heavily later
---

# ☕ Daily Journal — $dow, $dStr

## 🌅 Morning Focus & Mindset
- **Primary Intention**: 
- **Current Mindset & Mood**: Reflective and ready to build.
- **Gratitude / Observation**: Morning coffee and quiet space to think.

## 📝 Daily Notes & Stream of Thought
*Write thoughts, observations, and discoveries as the day unfolds...*

## 🎯 Key Accomplishments & Progress
- [ ] Test new features in Quill & Papyrus AI
- [ ] Review documentation and logs
- [ ] Wrap up pending tasks

## 🌙 Evening Reflection
- **Wins today**: 
- **Lessons learned**: 
- **Focus for tomorrow**: 
''';
    } else if (key.contains('project') || key.contains('spec') || key.contains('architecture')) {
      return '''---
title: Project Architecture & Spec
date: $dStr
day_of_week: $dow
mood: Analytical / Focused
tags: [architecture, technology, project_notes]
topics: [development, engineering, planning]
status: in_progress
---

# 🚀 Project Architecture & Spec

## 🎯 Executive Summary & Goals
- **Objective**: 
- **Target Audience / Users**: 
- **Key Success Metrics**: 

## 🏗️ Architectural Overview
- **Core Layer**: Data models and repositories.
- **State Management**: Providers & reactive state listeners.
- **Presentation Layer**: Responsive UI panels (Explorer, Editor, Preview, AI).

## 📋 Implementation Roadmap
- [ ] Phase 1: Core service contracts and data layer
- [ ] Phase 2: State notification and persistent caching
- [ ] Phase 3: Interactive UI components and user feedback
- [ ] Phase 4: Automated tests & validation

## 🔍 Technical Considerations & Risks
- **Data Safety**: Offline-first local storage without remote dependencies.
- **Performance**: Zero lag on large markdown documents.
''';
    } else if (key.contains('meeting') || key.contains('sync') || key.contains('minutes')) {
      return '''---
title: Meeting Notes & Action Items
date: $dStr
day_of_week: $dow
mood: Collaborative / Direct
tags: [meeting, collaboration, project_notes]
topics: [coordination, planning, communication]
status: complete
---

# 👥 Meeting Notes — $dStr

- **Meeting Topic**: 
- **Participants**: 
- **Facilitator / Note Taker**: 

## 📌 Agenda
1. Review of previous action items
2. Core discussion topics
3. Blockers and dependencies
4. Next steps

## 💡 Decisions Made
- [x] Decision 1: 
- [x] Decision 2: 

## ⚡ Action Items & Next Steps
- [ ] Task 1 — @Owner (Due: $dStr)
- [ ] Task 2 — @Owner (Due: $dStr)
''';
    } else if (key.contains('weekly') || key.contains('review') || key.contains('retro')) {
      return '''---
title: Weekly Review & Planning
date: $dStr
day_of_week: $dow
mood: Reflective / Productive
tags: [weekly_review, productivity, personal_log]
topics: [planning, retrospective, goal_setting]
status: in_progress
---

# 📊 Weekly Review & Planning — Week of $dStr

## 🏆 Key Wins & Milestones
- Highlight 1: 
- Highlight 2: 
- Highlight 3: 

## 📈 Metric & Habit Check-in
- [x] Consistent daily journaling
- [ ] Weekly deep work hours reached
- [x] Key projects progressed

## 🔄 Retrospective
- **What worked well**: 
- **Friction or bottlenecks**: 
- **What to stop doing**: 

## 🎯 Top 3 Priorities for Next Week
1. 
2. 
3. 
''';
    } else if (key.contains('farm') || key.contains('pasture') || key.contains('livestock') || key.contains('goat')) {
      return '''---
title: Farm & Pasture Management Log
date: $dStr
day_of_week: $dow
mood: Grounded / Attentive
tags: [homestead, livestock, farm_log]
topics: [agriculture, herd_health, pasture_management]
status: in_progress
---

# 🌾 Farm & Pasture Management Log — $dow, $dStr

## 🌦️ Weather & Soil Observations
- **Temperature & Weather**: 
- **Rainfall (24 hr)**: 
- **Pasture Ground Condition**: Dry / Firm / Muddy

## 🐐 Livestock Health & Herd Inspection
- **Current Paddock**: Paddock A
- **Next Rotation**: Paddock B (Rest period target: 21+ days)
- **Feed & Supplements**: Free-choice minerals, fresh hay, water inspected
- **Herd Observations**: Normal activity, rumination good

## 🛠️ Field Chores & Maintenance
- [ ] Check fence lines and gate latches
- [ ] Clean and refill water troughs
- [ ] Monitor forage regrowth

## 📝 Observations & Notes
*Field notes, animal behavior, and seasonal changes...*
''';
    } else {
      final topicTitle = templateTypeOrPrompt.trim().isEmpty ? 'Notes & Outline' : templateTypeOrPrompt.trim();
      final slug = topicTitle.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();

      return '''---
title: $topicTitle
date: $dStr
day_of_week: $dow
mood: Creative / Deliberate
tags: [productivity, notes, $slug]
topics: [writing, research, planning]
status: in_progress
---

# 📌 $topicTitle

## 🎯 Overview & Objectives
- **Core Purpose**: Outline and document concepts related to $topicTitle.
- **Context**: 

## 💡 Key Concepts & Details
### Section 1: Fundamental Concepts
- Point A
- Point B

### Section 2: Implementation & Execution
- Strategy and approach

## 📋 Action Checklist
- [ ] Initial research and setup
- [ ] Execute primary tasks
- [ ] Review and link related notes via [[Wikilinks]]

## 📝 Notes & Observations
*Add additional thoughts and references...*
''';
    }
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

    // Handle Frontmatter Analysis Prompts in fallback mode
    if (prompt.contains('extract YAML frontmatter metadata:')) {
      final now = DateTime.now();
      const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final dow = weekdays[now.weekday - 1];
      final dStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      String docBody = '';
      if (prompt.contains('Document Content:\n"""\n')) {
        docBody = prompt.split('Document Content:\n"""\n').last.split('"""').first.trim();
      }

      final lines = docBody.split('\n').where((l) => l.trim().isNotEmpty).toList();
      String docTitle = 'Journal Entry - $dStr';
      if (lines.isNotEmpty) {
        final first = lines.first.replaceAll(RegExp(r'^[#\-* ]+'), '').trim();
        if (first.isNotEmpty) docTitle = first;
      }

      final docLower = docBody.toLowerCase();
      String docMood = 'Reflective / Productive';
      if (docLower.contains('coffee') || docLower.contains('morning') || docLower.contains('reflect') || docLower.contains('gratitude') || docLower.contains('journal')) {
        docMood = 'Reflective / Productive';
      } else if (docLower.contains('goat') || docLower.contains('farm') || docLower.contains('pasture') || docLower.contains('livestock')) {
        docMood = 'Grounded / Attentive';
      } else if (docLower.contains('bug') || docLower.contains('code') || docLower.contains('test') || docLower.contains('debug')) {
        docMood = 'Analytical / Focused';
      } else if (docLower.contains('design') || docLower.contains('build') || docLower.contains('create')) {
        docMood = 'Creative / Deliberate';
      }

      final List<String> docTags = ['journaling'];
      if (docLower.contains('flutter') || docLower.contains('dart') || docLower.contains('tech') || docLower.contains('app') || docLower.contains('code')) {
        docTags.add('technology');
      }
      if (docLower.contains('ai') || docLower.contains('model')) {
        docTags.add('ai');
      }
      if (docLower.contains('farm') || docLower.contains('livestock')) {
        docTags.addAll(['homestead', 'livestock']);
      }
      if (docLower.contains('task') || docLower.contains('progress')) {
        docTags.add('productivity');
      }

      final List<String> docTopics = ['writing'];
      if (docLower.contains('app') || docLower.contains('test') || docLower.contains('testing')) {
        docTopics.add('app_testing');
      }
      if (docLower.contains('hardware') || docLower.contains('device')) {
        docTopics.add('hardware');
      }
      if (docLower.contains('dev') || docLower.contains('development')) {
        docTopics.add('development');
      }

      final docStatus = (docBody.contains('- [ ]') || docLower.contains('wip') || docLower.contains('in progress'))
          ? 'in_progress'
          : 'complete';

      return '''TITLE: $docTitle
DATE: $dStr
DAY_OF_WEEK: $dow
MOOD: $docMood
TAGS: ${docTags.toSet().join(', ')}
TOPICS: ${docTopics.toSet().join(', ')}
STATUS: $docStatus''';
    }

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
    } else if (lower.contains('frontmatter') || lower.contains('yaml front matter')) {
      final now = DateTime.now();
      final dStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final dow = weekdays[now.weekday - 1];
      return '''### Generated YAML Frontmatter

```yaml
---
title: Journal Entry - Coffee & App Testing
date: $dStr
day_of_week: $dow
mood: Reflective / Productive
tags: [journaling, technology, productivity, personal_log]
topics: [writing, journaling, app_testing, hardware]
status: complete # Or 'in_progress' if you plan to edit it heavily later
---
```

*Tap **Inline Diff** or use the **Insert YAML Frontmatter** button to apply to line 1.*''';
    } else if (lower.contains('template') || lower.contains('daily journal') || lower.contains('meeting note') || lower.contains('project spec')) {
      final template = generateDocumentTemplate(templateTypeOrPrompt: prompt);
      return '''### Generated Document Template

```markdown
$template
```

*Tap **Inline Diff** or **Insert** to load this into your active document.*''';
    } else if (lower.contains('farm') || lower.contains('goat') || lower.contains('livestock') || lower.contains('pasture')) {
      return '### Farm & Livestock Log :goat:\n\nHere is a dedicated structure for your farming notes:\n\n```markdown\n## 🌾 Farm Management & Pasture Log\n- **Date**: 2026-08-27\n- **Pasture Rotation**: Paddock 2 -> Paddock 3 (rest period: 21 days)\n\n### 🐐 Livestock Health & Herd Observations\n- [ ] Morning feeding: Alfa-grass mix & free-choice minerals\n- [ ] Water trough check: Cleaned and refilled\n- [ ] Herd vitals & body condition scores recorded\n\n### 📝 Tasks & Action Items\n- [ ] Repair north fence line along woodlot\n- [ ] Check hay inventory before weekend weather\n```\n\n*Tap **Inline Diff** or **Insert** to add this directly to your active document.*';
    } else if (lower.contains('welcome') || lower.contains('what is quill')) {
      return '### Welcome to Quill & Papyrus AI\n\nQuill & Papyrus AI is your private, on-device Markdown workstation running local AI models.\n\n- **100% Offline & Private**: All file operations, SQLite indexes, and local LLM tokens run on your device without transmitting data.\n- **Workspace RAG**: Your documents in the active directory provide context for answers.\n- **Inline Diffs**: Review and accept AI proposals with one tap.\n\nHow can I help you write or organize your workspace today?';
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

    final replacements = {
      RegExp(r'\bteh\b', caseSensitive: false): 'the',
      RegExp(r'\brecieve\b', caseSensitive: false): 'receive',
      RegExp(r'\bseperate\b', caseSensitive: false): 'separate',
      RegExp(r'\bdefinately\b', caseSensitive: false): 'definitely',
      RegExp(r'\boccured\b', caseSensitive: false): 'occurred',
      RegExp(r'\bdont\b', caseSensitive: false): "don't",
      RegExp(r'\bcant\b', caseSensitive: false): "can't",
      RegExp(r'\bwont\b', caseSensitive: false): "won't",
      RegExp(r'\barent\b', caseSensitive: false): "aren't",
      RegExp(r'\bisnt\b', caseSensitive: false): "isn't",
      RegExp(r'\bwasnt\b', caseSensitive: false): "wasn't",
      RegExp(r'\bwerent\b', caseSensitive: false): "weren't",
      RegExp(r'\bshouldnt\b', caseSensitive: false): "shouldn't",
      RegExp(r'\bcouldnt\b', caseSensitive: false): "couldn't",
      RegExp(r'\bwouldnt\b', caseSensitive: false): "wouldn't",
      RegExp(r'\bthats\b', caseSensitive: false): "that's",
      RegExp(r'\bwhats\b', caseSensitive: false): "what's",
      RegExp(r'\btheres\b', caseSensitive: false): "there's",
      RegExp(r'\bheres\b', caseSensitive: false): "here's",
      RegExp(r'\b([a-zA-Z]+)\s+\1\b', caseSensitive: false): r'$1',
    };

    for (final entry in replacements.entries) {
      fixed = fixed.replaceAll(entry.key, entry.value);
    }

    fixed = fixed.replaceAllMapped(
      RegExp(r'(?:^|[.!?]\s+)([a-z])'),
      (m) => m.group(0)!.toUpperCase(),
    );

    if (!fixed.endsWith('.') && !fixed.endsWith('!') && !fixed.endsWith('?') && !fixed.endsWith('`') && !fixed.endsWith('#')) {
      fixed = '$fixed.';
    }
    return fixed;
  }

  String _generateExpandedText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'No text to expand.';

    final lines = clean.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final subject = lines.first.replaceAll(RegExp(r'^[#\-* ]+'), '').trim();

    return '''$clean

### 🔍 Deep Dive & Conceptual Context
When working with **$subject**, having clear context and systematic execution is essential. Key considerations include:
- **Architectural Clarity**: Ensure core boundaries and data flows are documented to prevent regression.
- **Resilience & Fault Tolerance**: Plan for edge cases, resource limits, and network transitions.
- **Maintainability**: Clear definitions and idiomatic patterns enable friction-free iteration.

### 💡 Practical Application & Next Steps
1. **Validation**: Test edge-case assumptions against active workloads.
2. **Integration**: Link related notes and references using `[[Wikilinks]]`.
3. **Execution**: Track pending sub-tasks with structured checklists.''';
  }

  String _generateSummary(String prompt, String content) {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) return '- No content provided to summarize.';

    final lines = cleanContent
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^[#\-* ]+'), '').trim())
        .where((l) => l.length > 5)
        .toList();

    if (lines.length <= 3) {
      return lines.map((l) => '- $l').join('\n');
    }

    final bullets = <String>[];
    bullets.add('- **Core Focus**: ${lines.first}');
    if (lines.length > 2) {
      bullets.add('- **Key Details**: ${lines[1]}');
    }
    if (lines.length > 3) {
      bullets.add('- **Context**: ${lines[lines.length - 2]}');
    }
    bullets.add('- **Takeaway**: ${lines.last}');
    return bullets.join('\n');
  }

  String _generateActionItems(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return '- [ ] Define task objectives';

    final lines = clean
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^[#\-* ]+'), '').trim())
        .where((l) => l.length > 4)
        .toList();

    final actionVerbs = RegExp(r'\b(verify|test|check|build|implement|create|fix|update|review|run|deploy|configure|clean|add|remove|investigate|ensure|inspect)\b', caseSensitive: false);
    final items = <String>[];

    for (final l in lines) {
      if (actionVerbs.hasMatch(l)) {
        final task = l[0].toUpperCase() + l.substring(1);
        items.add('- [ ] $task');
      }
    }

    if (items.isEmpty) {
      for (final l in lines.take(4)) {
        final task = l[0].toUpperCase() + l.substring(1);
        items.add('- [ ] $task');
      }
    }

    return items.join('\n');
  }

  String _generateExplanation(String text) {
    final clean = text.trim();
    final firstLine = clean.split('\n').first.replaceAll(RegExp(r'^[#\-* ]+'), '').trim();
    return '### Explanation: $firstLine\n\n- **Overview**: This section outlines the primary conceptual foundation of $firstLine.\n- **Core Mechanism**: How it operates within the context of your notes and workspace.\n- **Key Takeaways**: Clear, actionable understanding without unnecessary complexity.';
  }

  String _generateTable(String text) {
    final clean = text.trim();
    final lines = clean
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^[#\-* ]+'), '').trim())
        .where((l) => l.length > 2)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('| Item / Concept | Description & Details | Status / Notes |');
    buffer.writeln('| :--- | :--- | :--- |');

    if (lines.isNotEmpty) {
      for (final l in lines.take(6)) {
        final parts = l.split(RegExp(r'[:–—\-]'));
        if (parts.length >= 2) {
          final col1 = parts[0].trim();
          final col2 = parts.sublist(1).join(' - ').trim();
          buffer.writeln('| $col1 | $col2 | Verified |');
        } else {
          buffer.writeln('| $l | Key section point | Active |');
        }
      }
    } else {
      buffer.writeln('| Item 1 | Core overview | Active |');
      buffer.writeln('| Item 2 | Implementation details | Complete |');
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

