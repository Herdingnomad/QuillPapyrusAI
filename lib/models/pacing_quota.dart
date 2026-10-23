import 'package:equatable/equatable.dart';

class ManuscriptTarget with Equatable {
  final String id;
  final int targetManuscriptWords;
  final int targetDailyWords;
  final String? deadline;
  final DateTime updatedAt;

  const ManuscriptTarget({
    this.id = 'default',
    this.targetManuscriptWords = 80000,
    this.targetDailyWords = 1500,
    this.deadline,
    required this.updatedAt,
  });

  double progressFraction(int currentWords) {
    if (targetManuscriptWords <= 0) return 0.0;
    return (currentWords / targetManuscriptWords).clamp(0.0, 1.0);
  }

  double dailyProgressFraction(int todayNetWords) {
    if (targetDailyWords <= 0) return 0.0;
    return (todayNetWords / targetDailyWords).clamp(0.0, 1.0);
  }

  double estimatedReadingHours(int totalWords, {int wordsPerMinute = 250}) {
    if (wordsPerMinute <= 0) return 0.0;
    return totalWords / (wordsPerMinute * 60);
  }

  ManuscriptTarget copyWith({
    String? id,
    int? targetManuscriptWords,
    int? targetDailyWords,
    String? deadline,
    DateTime? updatedAt,
  }) {
    return ManuscriptTarget(
      id: id ?? this.id,
      targetManuscriptWords: targetManuscriptWords ?? this.targetManuscriptWords,
      targetDailyWords: targetDailyWords ?? this.targetDailyWords,
      deadline: deadline ?? this.deadline,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target_manuscript_words': targetManuscriptWords,
      'target_daily_words': targetDailyWords,
      'deadline': deadline,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ManuscriptTarget.fromMap(Map<String, dynamic> map) {
    return ManuscriptTarget(
      id: map['id'] as String? ?? 'default',
      targetManuscriptWords: map['target_manuscript_words'] as int? ?? 80000,
      targetDailyWords: map['target_daily_words'] as int? ?? 1500,
      deadline: map['deadline'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  List<Object?> get props => [id, targetManuscriptWords, targetDailyWords, deadline, updatedAt];
}

class WritingSession with Equatable {
  final String id;
  final String date; // YYYY-MM-DD
  final int wordsWritten;
  final int wordsDeleted;
  final int netWords;
  final int durationSeconds;
  final DateTime lastActive;

  const WritingSession({
    required this.id,
    required this.date,
    required this.wordsWritten,
    required this.wordsDeleted,
    required this.netWords,
    required this.durationSeconds,
    required this.lastActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'words_written': wordsWritten,
      'words_deleted': wordsDeleted,
      'net_words': netWords,
      'duration_seconds': durationSeconds,
      'last_active': lastActive.millisecondsSinceEpoch,
    };
  }

  factory WritingSession.fromMap(Map<String, dynamic> map) {
    return WritingSession(
      id: map['id'] as String,
      date: map['date'] as String,
      wordsWritten: map['words_written'] as int? ?? 0,
      wordsDeleted: map['words_deleted'] as int? ?? 0,
      netWords: map['net_words'] as int? ?? 0,
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      lastActive: DateTime.fromMillisecondsSinceEpoch(map['last_active'] as int? ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  List<Object?> get props => [id, date, wordsWritten, wordsDeleted, netWords, durationSeconds, lastActive];
}
