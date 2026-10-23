import 'package:equatable/equatable.dart';

class SceneSnapshot with Equatable {
  final String id;
  final String fileUri;
  final String title;
  final String content;
  final int wordCount;
  final DateTime timestamp;
  final String? note;

  const SceneSnapshot({
    required this.id,
    required this.fileUri,
    required this.title,
    required this.content,
    required this.wordCount,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_uri': fileUri,
      'title': title,
      'content': content,
      'word_count': wordCount,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'note': note,
    };
  }

  factory SceneSnapshot.fromMap(Map<String, dynamic> map) {
    return SceneSnapshot(
      id: map['id'] as String,
      fileUri: map['file_uri'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      wordCount: map['word_count'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      note: map['note'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, fileUri, title, wordCount, timestamp, note];
}
