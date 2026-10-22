import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/pacing_quota.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';

class PacingState with Equatable {
  final ManuscriptTarget target;
  final WritingSession? todaySession;
  final List<WritingSession> recentHistory;
  final int totalManuscriptWords;

  const PacingState({
    required this.target,
    this.todaySession,
    this.recentHistory = const [],
    this.totalManuscriptWords = 0,
  });

  int get todayNetWords => todaySession?.netWords ?? 0;
  double get dailyProgress => target.dailyProgressFraction(todayNetWords);
  double get manuscriptProgress => target.progressFraction(totalManuscriptWords);

  PacingState copyWith({
    ManuscriptTarget? target,
    WritingSession? todaySession,
    List<WritingSession>? recentHistory,
    int? totalManuscriptWords,
  }) {
    return PacingState(
      target: target ?? this.target,
      todaySession: todaySession ?? this.todaySession,
      recentHistory: recentHistory ?? this.recentHistory,
      totalManuscriptWords: totalManuscriptWords ?? this.totalManuscriptWords,
    );
  }

  @override
  List<Object?> get props => [target, todaySession, recentHistory, totalManuscriptWords];
}

final pacingProvider = StateNotifierProvider<PacingNotifier, PacingState>((ref) {
  final notifier = PacingNotifier(ref);
  notifier.loadPacingData();
  return notifier;
});

class PacingNotifier extends StateNotifier<PacingState> {
  final Ref _ref;
  final DatabaseService _db = DatabaseService.instance;

  PacingNotifier(this._ref)
      : super(PacingState(
          target: ManuscriptTarget(updatedAt: DateTime.now()),
        ));

  Future<void> loadPacingData() async {
    final target = await _db.getManuscriptTarget();
    final today = await _db.getTodaySession();
    final history = await _db.getRecentSessions(days: 14);

    state = state.copyWith(
      target: target,
      todaySession: today,
      recentHistory: history,
    );

    await calculateManuscriptWords();
  }

  Future<void> calculateManuscriptWords() async {
    final workspace = _ref.read(workspaceProvider);
    final tree = workspace.fileTree;
    if (tree == null) return;

    final storage = _ref.read(safStorageServiceProvider);
    int count = 0;

    Future<void> countNode(dynamic node) async {
      if (!node.isDirectory && (node.name.endsWith('.md') || node.name.endsWith('.markdown'))) {
        try {
          final content = await storage.readFile(node.uri);
          final words = content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;
          count += words;
        } catch (_) {}
      }
      for (final child in node.children) {
        await countNode(child);
      }
    }

    await countNode(tree);
    state = state.copyWith(totalManuscriptWords: count);
  }

  Future<void> logEditDelta(int oldWords, int newWords) async {
    if (newWords > oldWords) {
      await _db.recordWritingActivity(
        wordsAdded: newWords - oldWords,
        wordsDeleted: 0,
        durationSeconds: 10,
      );
    } else if (oldWords > newWords) {
      await _db.recordWritingActivity(
        wordsAdded: 0,
        wordsDeleted: oldWords - newWords,
        durationSeconds: 10,
      );
    }

    final today = await _db.getTodaySession();
    final history = await _db.getRecentSessions(days: 14);
    state = state.copyWith(
      todaySession: today,
      recentHistory: history,
    );
  }

  Future<void> updateTarget({
    int? manuscriptWords,
    int? dailyWords,
    String? deadline,
  }) async {
    final newTarget = state.target.copyWith(
      targetManuscriptWords: manuscriptWords,
      targetDailyWords: dailyWords,
      deadline: deadline,
      updatedAt: DateTime.now(),
    );
    await _db.saveManuscriptTarget(newTarget);
    state = state.copyWith(target: newTarget);
  }
}
