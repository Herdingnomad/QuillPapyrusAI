import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/ai_model_config.dart';
import 'package:quill_papyrus_ai/models/chat.dart';
import 'package:quill_papyrus_ai/services/ai_service.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
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

  const AiState({
    this.messages = const [],
    this.conversations = const [],
    this.activeChatId,
    this.isStreaming = false,
    this.streamingBuffer = '',
    this.config = const AiModelConfig(),
    this.ragEnabled = true,
    this.isModelLoaded = false,
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
      if (chats.isNotEmpty) {
        final latest = chats.first;
        final messages = await _dbService.getMessages(latest.id);
        state = state.copyWith(
          conversations: chats,
          activeChatId: () => latest.id,
          messages: messages,
          isModelLoaded: _aiService.isModelLoaded,
        );
      } else {
        await startNewChat(title: 'New Conversation');
      }

      // Auto-detect and pre-bind local .gguf models on device if available
      final detectedPath = await _aiService.resolveModelPath(state.config);
      if (detectedPath != null && state.config.customModelPath == null) {
        state = state.copyWith(
          config: state.config.copyWith(customModelPath: detectedPath),
        );
      }
    } catch (_) {
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
    if (config.customModelPath == null || config.customModelPath!.isEmpty) {
      _aiService.resolveModelPath(config).then((path) {
        if (path != null && mounted) {
          state = state.copyWith(config: state.config.copyWith(customModelPath: path));
        }
      });
    }
  }

  Future<bool> loadModel() async {
    try {
      var path = state.config.customModelPath;
      if (path == null || path.isEmpty) {
        path = await _aiService.resolveModelPath(state.config);
      }
      if (path != null && path.isNotEmpty) {
        final success = await _aiService.loadNativeModel(path);
        state = state.copyWith(
          isModelLoaded: success,
          config: state.config.copyWith(customModelPath: path),
        );
        return success;
      }
      return false;
    } catch (_) {
      state = state.copyWith(isModelLoaded: false);
      return false;
    }
  }

  Future<void> unloadModel() async {
    await _aiService.unloadModel();
    state = state.copyWith(isModelLoaded: false);
  }

  void toggleRag() {
    state = state.copyWith(ragEnabled: !state.ragEnabled);
  }

  Future<void> sendMessage({
    required String text,
    String? currentDocUri,
    String? currentDocContent,
    String? parentFolder,
    List<String>? directoryFiles,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || state.isStreaming) return;

    var chatId = state.activeChatId;
    if (chatId == null) {
      chatId = _uuid.v4();
      final title = cleanText.length > 30 ? '${cleanText.substring(0, 30)}...' : cleanText;
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
        final title = cleanText.length > 30 ? '${cleanText.substring(0, 30)}...' : cleanText;
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
      content: cleanText,
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
      prompt: cleanText,
      config: state.config,
      currentDocUri: state.ragEnabled ? currentDocUri : null,
      currentDocContent: state.ragEnabled ? currentDocContent : null,
      parentFolder: state.ragEnabled ? parentFolder : null,
      directoryFiles: state.ragEnabled ? directoryFiles : null,
      conversationHistory: previousMessages,
    );

    final buffer = StringBuffer();
    try {
      await for (final token in stream) {
        buffer.write(token);
        state = state.copyWith(
          streamingBuffer: buffer.toString(),
          isModelLoaded: _aiService.isModelLoaded,
        );
      }
    } catch (e) {
      if (buffer.isEmpty) {
        buffer.write('I received your message: "$cleanText". How can I assist you with your markdown notes?');
      }
    }

    final finalContent = buffer.toString().trim().isNotEmpty
        ? buffer.toString()
        : 'I received your message: "$cleanText". How can I help?';

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
  }
}
