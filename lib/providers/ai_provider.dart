import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/ai_model_config.dart';
import 'package:quill_papyrus_ai/models/ai_skill.dart';
import 'package:quill_papyrus_ai/models/chat.dart';
import 'package:quill_papyrus_ai/services/ai_service.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:uuid/uuid.dart';

class AiState {
  final List<ChatMessage> messages;
  final List<Chat> conversations;
  final String? activeChatId;
  final bool isStreaming;
  final String streamingBuffer;
  final AiModelConfig config;
  final bool ragEnabled;
  final bool isModelLoaded;
  final GemmaModelType defaultModelType;
  final String? defaultModelPath;
  final ContextUsage contextUsage;

  const AiState({
    this.messages = const [],
    this.conversations = const [],
    this.activeChatId,
    this.isStreaming = false,
    this.streamingBuffer = '',
    this.config = const AiModelConfig(),
    this.ragEnabled = true,
    this.isModelLoaded = false,
    this.defaultModelType = GemmaModelType.gemma4E4B,
    this.defaultModelPath,
    this.contextUsage = const ContextUsage(),
  });

  AiState copyWith({
    List<ChatMessage>? messages,
    List<Chat>? conversations,
    String? Function()? activeChatId,
    bool? isStreaming,
    String? streamingBuffer,
    AiModelConfig? config,
    bool? ragEnabled,
    bool? isModelLoaded,
    GemmaModelType? defaultModelType,
    String? defaultModelPath,
    bool clearDefaultModelPath = false,
    ContextUsage? contextUsage,
  }) {
    return AiState(
      messages: messages ?? this.messages,
      conversations: conversations ?? this.conversations,
      activeChatId: activeChatId != null ? activeChatId() : this.activeChatId,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingBuffer: streamingBuffer ?? this.streamingBuffer,
      config: config ?? this.config,
      ragEnabled: ragEnabled ?? this.ragEnabled,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      defaultModelType: defaultModelType ?? this.defaultModelType,
      defaultModelPath: clearDefaultModelPath ? null : (defaultModelPath ?? this.defaultModelPath),
      contextUsage: contextUsage ?? this.contextUsage,
    );
  }
}

final aiServiceProvider = Provider<AiService>((ref) => AiService());

final aiProvider = StateNotifierProvider<AiNotifier, AiState>((ref) {
  return AiNotifier(ref.read(aiServiceProvider));
});

class AiNotifier extends StateNotifier<AiState> {
  final AiService _aiService;
  final DatabaseService _dbService = DatabaseService.instance;
  final Uuid _uuid = const Uuid();

  AiNotifier(this._aiService) : super(const AiState()) {
    initChats();
  }

  Future<void> initChats() async {
    try {
      final chats = await _dbService.getChats();
      if (!mounted) return;
      if (chats.isNotEmpty) {
        final latest = chats.first;
        final messages = await _dbService.getMessages(latest.id);
        if (!mounted) return;
        state = state.copyWith(
          conversations: chats,
          activeChatId: () => latest.id,
          messages: messages,
          isModelLoaded: _aiService.isModelLoaded,
        );
      } else {
        await startNewChat(title: 'New Conversation');
        if (!mounted) return;
      }

      // Restore persisted default model preference from database
      final defaultTypeStr = await _dbService.getSetting('default_model_type');
      if (!mounted) return;
      final savedDefaultPath = await _dbService.getSetting('default_model_path');
      if (!mounted) return;

      GemmaModelType defType = GemmaModelType.gemma4E4B;
      if (defaultTypeStr != null) {
        for (final t in GemmaModelType.values) {
          if (t.name == defaultTypeStr) {
            defType = t;
            break;
          }
        }
      }

      String? customPath = AiService.isValidModelPathForPlatform(savedDefaultPath)
          ? savedDefaultPath
          : null;
      customPath ??= await _aiService.resolveModelPath(AiModelConfig(modelType: defType));
      if (!mounted) return;

      final savedContextSizeStr = await _dbService.getSetting('ai_context_size');
      if (!mounted) return;
      int contextSize = 8192;
      if (savedContextSizeStr != null) {
        contextSize = int.tryParse(savedContextSizeStr) ?? 8192;
      }

      state = state.copyWith(
        defaultModelType: defType,
        defaultModelPath: (savedDefaultPath != null && savedDefaultPath.isNotEmpty) ? savedDefaultPath : null,
        config: state.config.copyWith(
          modelType: defType,
          customModelPath: customPath,
          contextSize: contextSize,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      if (state.activeChatId == null) {
        final defaultId = _uuid.v4();
        state = state.copyWith(
          activeChatId: () => defaultId,
          conversations: [
            Chat(id: defaultId, title: 'New Conversation', createdAt: DateTime.now(), updatedAt: DateTime.now())
          ],
        );
      }
    }
  }

  Future<void> startNewChat({String title = 'New Conversation', String? linkedDocUri}) async {
    final newChatId = _uuid.v4();
    final newChat = Chat(
      id: newChatId,
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      linkedDocUri: linkedDocUri,
    );

    try {
      await _dbService.insertChat(newChat);
      final chats = await _dbService.getChats();
      state = state.copyWith(
        conversations: chats.isNotEmpty ? chats : [newChat, ...state.conversations],
        activeChatId: () => newChatId,
        messages: [],
        streamingBuffer: '',
        isStreaming: false,
      );
    } catch (_) {
      state = state.copyWith(
        conversations: [newChat, ...state.conversations],
        activeChatId: () => newChatId,
        messages: [],
        streamingBuffer: '',
        isStreaming: false,
      );
    }
    refreshContextUsage();
  }

  Future<void> switchChat(String chatId) async {
    try {
      final messages = await _dbService.getMessages(chatId);
      state = state.copyWith(
        activeChatId: () => chatId,
        messages: messages,
        streamingBuffer: '',
        isStreaming: false,
      );
    } catch (_) {
      state = state.copyWith(
        activeChatId: () => chatId,
        streamingBuffer: '',
        isStreaming: false,
      );
    }
    refreshContextUsage();
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _dbService.deleteChat(chatId);
      final chats = await _dbService.getChats();
      if (chats.isNotEmpty) {
        await switchChat(chats.first.id);
        state = state.copyWith(conversations: chats);
      } else {
        await startNewChat();
      }
    } catch (_) {
      await startNewChat();
    }
  }

  void setModelConfig(AiModelConfig config) {
    state = state.copyWith(config: config);
    if (config.customModelPath != null && config.customModelPath!.isNotEmpty) {
      // Automatically persist selected model path so it survives app restarts
      _dbService.setSetting('default_model_type', config.modelType.name);
      _dbService.setSetting('default_model_path', config.customModelPath!);
      state = state.copyWith(
        defaultModelType: config.modelType,
        defaultModelPath: config.customModelPath,
      );
    } else {
      _aiService.resolveModelPath(config).then((path) {
        if (path != null && mounted) {
          state = state.copyWith(config: state.config.copyWith(customModelPath: path));
        }
      });
    }
  }

  Future<void> setDefaultModel({
    required GemmaModelType modelType,
    String? customModelPath,
  }) async {
    await _dbService.setSetting('default_model_type', modelType.name);
    await _dbService.setSetting('default_model_path', customModelPath ?? '');

    String? resolvedPath = customModelPath;
    if (resolvedPath == null || resolvedPath.isEmpty) {
      resolvedPath = await _aiService.resolveModelPath(AiModelConfig(modelType: modelType));
    }

    if (!mounted) return;

    state = state.copyWith(
      defaultModelType: modelType,
      defaultModelPath: (customModelPath != null && customModelPath.isNotEmpty) ? customModelPath : null,
      clearDefaultModelPath: customModelPath == null || customModelPath.isEmpty,
      config: state.config.copyWith(
        modelType: modelType,
        customModelPath: resolvedPath,
      ),
    );
  }

  bool isDefaultModel(GemmaModelType type, {String? customPath}) {
    if (customPath != null && state.defaultModelPath != null && state.defaultModelPath!.isNotEmpty) {
      if (AiService.canonicalizePath(state.defaultModelPath!) ==
          AiService.canonicalizePath(customPath)) {
        return true;
      }
    }
    if (state.defaultModelType == type) {
      if (type == GemmaModelType.customGGUF) {
        if (state.defaultModelPath == null || customPath == null) return false;
        return AiService.canonicalizePath(state.defaultModelPath!) ==
            AiService.canonicalizePath(customPath);
      }
      return true;
    }
    return false;
  }

  Future<bool> loadModel() async {
    try {
      String? path = AiService.isValidModelPathForPlatform(state.config.customModelPath)
          ? state.config.customModelPath
          : null;
      path ??= await _aiService.resolveModelPath(state.config);
      if (path != null && path.isNotEmpty) {
        final success = await _aiService.loadNativeModel(path, contextSize: state.config.contextSize);
        state = state.copyWith(
          isModelLoaded: success,
          config: state.config.copyWith(customModelPath: path),
        );
        refreshContextUsage();
        return success;
      }
      return false;
    } catch (_) {
      state = state.copyWith(isModelLoaded: false);
      return false;
    }
  }

  Future<void> setContextSize(int newSize) async {
    state = state.copyWith(config: state.config.copyWith(contextSize: newSize));
    await _dbService.setSetting('ai_context_size', newSize.toString());
    if (state.isModelLoaded) {
      await loadModel();
    }
    refreshContextUsage();
  }

  Future<void> unloadModel() async {
    await _aiService.unloadModel();
    state = state.copyWith(isModelLoaded: false);
  }

  void syncModelStatus() {
    state = state.copyWith(isModelLoaded: _aiService.isModelLoaded);
  }

  void toggleRag() {
    state = state.copyWith(ragEnabled: !state.ragEnabled);
    refreshContextUsage();
  }

  void stopGeneration() {
    _aiService.requestCancelGeneration();
  }

  /// Recomputes token usage across system/skills, RAG, and recent chat history.
  Future<void> refreshContextUsage({
    String? skillsSystemPrompt,
    String? activeDocContent,
    String? ragContextOverride,
    List<String>? directoryFiles,
  }) async {
    const baseSystem =
        'You are Quill & Papyrus AI, a private on-device markdown assistant. Always output natural, grammatically correct English with proper spacing between words.';
    final systemText = (skillsSystemPrompt != null && skillsSystemPrompt.isNotEmpty)
        ? '$baseSystem\n\n$skillsSystemPrompt'
        : baseSystem;

    String ragText = '';
    if (state.ragEnabled) {
      if (ragContextOverride != null && ragContextOverride.isNotEmpty) {
        ragText = ragContextOverride;
      } else if (_aiService.lastRagContext.isNotEmpty) {
        ragText = _aiService.lastRagContext;
      } else {
        final buf = StringBuffer();
        if (activeDocContent != null && activeDocContent.isNotEmpty) {
          final docBudget = state.config.contextSize >= 8192
              ? 14000
              : (state.config.contextSize >= 4096 ? 6500 : 3000);
          buf.writeln(activeDocContent.length > docBudget
              ? activeDocContent.substring(0, docBudget)
              : activeDocContent);
        }
        if (directoryFiles != null && directoryFiles.isNotEmpty) {
          for (final f in directoryFiles.take(150)) {
            buf.writeln('- $f');
          }
        }
        ragText = buf.toString();
      }
    }

    final recentHistory = state.messages.length > 8
        ? state.messages.sublist(state.messages.length - 8)
        : state.messages;
    final historyText = recentHistory.map((m) => m.content).join('\n');

    final sysRes = await _aiService.countTokens(systemText);
    final ragRes = await _aiService.countTokens(ragText);
    final histRes = await _aiService.countTokens(historyText);

    if (!mounted) return;
    state = state.copyWith(
      contextUsage: ContextUsage(
        systemAndSkillsTokens: sysRes.tokens,
        ragTokens: ragRes.tokens,
        historyTokens: histRes.tokens,
        maxTokens: state.config.contextSize,
        isExact: sysRes.isExact,
      ),
    );
  }

  Future<void> sendMessage({
    required String text,
    String? displayMessage,
    String? systemPrompt,
    String? currentDocUri,
    String? currentDocContent,
    String? parentFolder,
    List<String>? directoryFiles,
    List<String>? imagePaths,
    String? audioPath,
    String? workspaceRoot,
    String? scopedFolderPath,
    void Function()? onWorkspaceModified,
  }) async {
    final cleanText = text.trim();
    final hasAttachments =
        (imagePaths != null && imagePaths.isNotEmpty) ||
        (audioPath != null && audioPath.isNotEmpty);
    if ((cleanText.isEmpty && !hasAttachments) || state.isStreaming) return;

    final effectivePrompt = cleanText.isNotEmpty
        ? cleanText
        : (audioPath != null && audioPath.isNotEmpty
            ? 'Transcribe this audio recording into clean Markdown.'
            : 'Analyze this image and extract any text or key details into clean Markdown.');
    final shownUserText = (displayMessage != null && displayMessage.trim().isNotEmpty)
        ? displayMessage.trim()
        : effectivePrompt;

    var chatId = state.activeChatId;
    if (chatId == null) {
      chatId = _uuid.v4();
      final title = shownUserText.length > 30 ? '${shownUserText.substring(0, 30)}...' : shownUserText;
      final newChat = Chat(
        id: chatId,
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        linkedDocUri: currentDocUri,
      );
      state = state.copyWith(
        activeChatId: () => chatId,
        conversations: [newChat, ...state.conversations],
      );
      _dbService.insertChat(newChat);
    } else {
      final currentChat = state.conversations.firstWhere(
        (c) => c.id == chatId,
        orElse: () => Chat(id: chatId!, title: 'New Conversation', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );

      if (currentChat.title == 'New Conversation' || state.messages.isEmpty) {
        final title = shownUserText.length > 30 ? '${shownUserText.substring(0, 30)}...' : shownUserText;
        final updatedChat = currentChat.copyWith(
          title: title,
          updatedAt: DateTime.now(),
          linkedDocUri: currentDocUri ?? currentChat.linkedDocUri,
        );
        _dbService.updateChat(updatedChat);
      }
    }

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      sender: MessageSender.user,
      content: shownUserText,
      timestamp: DateTime.now(),
    );

    final previousMessages = List<ChatMessage>.from(state.messages);

    // Update state immediately
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isStreaming: true,
      streamingBuffer: '',
      isModelLoaded: _aiService.isModelLoaded,
    );

    _dbService.insertMessage(userMsg);

    final stream = _aiService.generateStream(
      prompt: effectivePrompt,
      systemPrompt: systemPrompt,
      config: state.config,
      ragEnabled: state.ragEnabled,
      currentDocUri: state.ragEnabled ? currentDocUri : null,
      currentDocContent: state.ragEnabled ? currentDocContent : null,
      parentFolder: state.ragEnabled ? parentFolder : null,
      directoryFiles: state.ragEnabled ? directoryFiles : null,
      conversationHistory: previousMessages,
      imagePaths: imagePaths,
      audioPath: audioPath,
      workspaceRoot: state.ragEnabled ? workspaceRoot : null,
      scopedFolderPath: state.ragEnabled ? scopedFolderPath : null,
      onWorkspaceModified: onWorkspaceModified,
    );

    final buffer = StringBuffer();
    try {
      await for (final token in stream) {
        buffer.write(token);
        state = state.copyWith(
          streamingBuffer: DiffService.repairMissingSpaces(DiffService.cleanSpecialTokens(buffer.toString())),
          isModelLoaded: _aiService.isModelLoaded,
        );
      }
    } catch (e) {
      if (buffer.isEmpty) {
        buffer.write(
          'Unable to generate a response right now. Check that your local model file is selected and loaded in AI settings.',
        );
      }
    }

    final cleanedBuffer = DiffService.trimRepetitionLoop(
      DiffService.cleanSpecialTokens(buffer.toString()).trim(),
    );
    final repairedContent = DiffService.repairMissingSpaces(cleanedBuffer);
    final finalContent = repairedContent.isNotEmpty
        ? repairedContent
        : 'The model returned an empty response. Try rephrasing your prompt or reloading the local model in AI settings.';

    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      sender: MessageSender.assistant,
      content: finalContent,
      timestamp: DateTime.now(),
    );

    _dbService.insertMessage(assistantMsg);

    state = state.copyWith(
      messages: [...state.messages, assistantMsg],
      isStreaming: false,
      streamingBuffer: '',
      isModelLoaded: _aiService.isModelLoaded,
    );

    refreshContextUsage(
      skillsSystemPrompt: systemPrompt,
      activeDocContent: currentDocContent,
      ragContextOverride: _aiService.lastRagContext,
      directoryFiles: directoryFiles,
    );
  }

  /// Transcribes speech from an audio file into markdown notes
  Future<String> transcribeAudioFile(File audioFile) async {
    return await _aiService.transcribeAudio(audioFile);
  }
}
