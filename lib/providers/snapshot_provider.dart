import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/scene_snapshot.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';

class SnapshotState with Equatable {
  final List<SceneSnapshot> snapshots;
  final bool isLoading;
  final String? activeFileUri;

  const SnapshotState({
    this.snapshots = const [],
    this.isLoading = false,
    this.activeFileUri,
  });

  SnapshotState copyWith({
    List<SceneSnapshot>? snapshots,
    bool? isLoading,
    String? activeFileUri,
  }) {
    return SnapshotState(
      snapshots: snapshots ?? this.snapshots,
      isLoading: isLoading ?? this.isLoading,
      activeFileUri: activeFileUri ?? this.activeFileUri,
    );
  }

  @override
  List<Object?> get props => [snapshots, isLoading, activeFileUri];
}

final snapshotProvider = StateNotifierProvider<SnapshotNotifier, SnapshotState>((ref) {
  return SnapshotNotifier(ref);
});

class SnapshotNotifier extends StateNotifier<SnapshotState> {
  final Ref _ref;
  final DatabaseService _db = DatabaseService.instance;

  SnapshotNotifier(this._ref) : super(const SnapshotState());

  Future<void> loadSnapshots(String fileUri) async {
    state = state.copyWith(isLoading: true, activeFileUri: fileUri);
    final list = await _db.getSnapshotsForFile(fileUri);
    state = state.copyWith(snapshots: list, isLoading: false);
  }

  Future<SceneSnapshot> takeSnapshot({
    required String fileUri,
    required String title,
    required String content,
    String? note,
  }) async {
    final words = content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;
    final snapshot = SceneSnapshot(
      id: 'snap_${DateTime.now().millisecondsSinceEpoch}',
      fileUri: fileUri,
      title: title,
      content: content,
      wordCount: words,
      timestamp: DateTime.now(),
      note: note,
    );

    await _db.saveSnapshot(snapshot);
    await loadSnapshots(fileUri);
    return snapshot;
  }

  Future<void> deleteSnapshot(String id, String fileUri) async {
    await _db.deleteSnapshot(id);
    await loadSnapshots(fileUri);
  }

  Future<void> restoreSnapshot(SceneSnapshot snapshot) async {
    _ref.read(editorProvider.notifier).updateContent(snapshot.content);
    await _ref.read(editorProvider.notifier).saveActiveFile();
  }
}
