import 'package:equatable/equatable.dart';

enum MessageSender { user, assistant, system }

class Chat with Equatable {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? linkedDocUri;

  const Chat({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.linkedDocUri,
  });

  Chat copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? linkedDocUri,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      linkedDocUri: linkedDocUri ?? this.linkedDocUri,
    );
  }

  @override
  List<Object?> get props => [id, title, createdAt, updatedAt, linkedDocUri];
}

class ChatMessage with Equatable {
  final String id;
  final String chatId;
  final MessageSender sender;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  ChatMessage copyWith({
    String? id,
    String? chatId,
    MessageSender? sender,
    String? content,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [id, chatId, sender, content, timestamp];
}
