import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/pacing_quota.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';

class PacingState with Equatable {
  final ManuscriptTarget target;
  final Map<String, ManuscriptTarget> folderTargets;
  final Map<String, int> folderWordCounts;
  final WritingSession? todaySession;
  final List<WritingSession> recentHistory;
  final int totalManuscriptWords;

  const PacingState({
    required this.target,
    this.folderTargets = const {},
    this.folderWordCounts = const {},
    this.todaySession,
    this.recentHistory = const [],
    this.totalManuscriptWords = 0,
  });

  int get todayNetWords => todaySession?.netWords ?? 0;
  double get dailyProgress => target.dailyProgressFraction(todayNetWords);
  double get manuscriptProgress => target.progressFraction(totalManuscriptWords);

  ManuscriptTarget? targetForFolder(String folderUri) => folderTargets[folderUri];
  int wordsForFolder(String folderUri) => folderWordCounts[folderUri] ?? 0;
  double progressForFolder(String folderUri) {
    final t = folderTargets[folderUri];
    if (t == null || t.targetManuscriptWords <= 0) return 0.0;
    return (wordsForFolder(folderUri) / t.targetManuscriptWords).clamp(0.0, 1.0);
  }

  PacingState copyWith({
    ManuscriptTarget? target,
    Map<String, ManuscriptTarget>? folderTargets,
    Map<String, int>? folderWordCounts,
    WritingSession? todaySession,
    List<WritingSession>? recentHistory,
    int? totalManuscriptWords,
  }) {
    return PacingState(
      target: target ?? this.target,
      folderTargets: folderTargets ?? this.folderTargets,
      folderWordCounts: folderWordCounts ?? this.folderWordCounts,
      todaySession: todaySession ?? this.todaySession,
      recentHistory: recentHistory ?? this.recentHistory,
      totalManuscriptWords: totalManuscriptWords ?? this.totalManuscriptWords,
    );
  }

  @override
  List<Object?> get props => [
        target,
        folderTargets,
        folderWordCounts,
        todaySession,
        recentHistory,
        totalManuscriptWords,
      ];
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
    final allTargets = await _db.getAllManuscriptTargets();
    final Map<String, ManuscriptTarget> folderTargets = {};
    for (final t in allTargets) {
      if (t.id != 'default') {
        folderTargets[t.id] = t;
      }
    }

    final today = await _db.getTodaySession();
    final history = await _db.getRecentSessions(days: 14);

    state = state.copyWith(
      target: target,
      folderTargets: folderTargets,
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
    final Map<String, int> folderCounts = {};

    Future<int> countNode(dynamic node) async {
      if (!node.isDirectory) {
        if (node.name.endsWith('.md') || node.name.endsWith('.markdown')) {
          try {
            final content = await storage.readFile(node.uri);
            return content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;
          } catch (_) {
            return 0;
          }
        }
        return 0;
      }

      int folderTotal = 0;
      for (final child in node.children) {
        folderTotal += await countNode(child);
      }
      folderCounts[node.uri] = folderTotal;
      return folderTotal;
    }

    final total = await countNode(tree);
    folderCounts[tree.uri] = total;

    state = state.copyWith(
      totalManuscriptWords: total,
      folderWordCounts: folderCounts,
    );
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
    await calculateManuscriptWords();
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

  Future<void> setFolderTarget({
    required String folderUri,
    required int targetWords,
    int? dailyWords,
    String? deadline,
  }) async {
    final existing = state.folderTargets[folderUri];
    final newTarget = (existing ?? ManuscriptTarget(id: folderUri, updatedAt: DateTime.now())).copyWith(
      id: folderUri,
      targetManuscriptWords: targetWords,
      targetDailyWords: dailyWords,
      deadline: deadline,
      updatedAt: DateTime.now(),
    );
    await _db.saveManuscriptTarget(newTarget);
    final updated = Map<String, ManuscriptTarget>.from(state.folderTargets);
    updated[folderUri] = newTarget;
    state = state.copyWith(folderTargets: updated);
  }

  Future<void> removeFolderTarget(String folderUri) async {
    await _db.deleteManuscriptTarget(folderUri);
    final updated = Map<String, ManuscriptTarget>.from(state.folderTargets);
    updated.remove(folderUri);
    state = state.copyWith(folderTargets: updated);
  }
}
