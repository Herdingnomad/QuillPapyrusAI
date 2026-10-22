import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/sync_models.dart';
import 'package:quill_papyrus_ai/providers/theme_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/services/sync_service.dart';

class SyncState with Equatable {
  final SyncStatus status;
  final String syncFolderPath;
  final List<String> discoveredSyncPaths;
  final DateTime? lastSyncTime;
  final int filesChecked;
  final int filesSynced;
  final List<SyncConflict> conflicts;
  final String? errorMessage;
  final bool isAutoSyncEnabled;

  const SyncState({
    this.status = SyncStatus.idle,
    required this.syncFolderPath,
    this.discoveredSyncPaths = const [],
    this.lastSyncTime,
    this.filesChecked = 0,
    this.filesSynced = 0,
    this.conflicts = const [],
    this.errorMessage,
    this.isAutoSyncEnabled = true,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? syncFolderPath,
    List<String>? discoveredSyncPaths,
    DateTime? lastSyncTime,
    int? filesChecked,
    int? filesSynced,
    List<SyncConflict>? conflicts,
    String? errorMessage,
    bool? isAutoSyncEnabled,
  }) {
    return SyncState(
      status: status ?? this.status,
      syncFolderPath: syncFolderPath ?? this.syncFolderPath,
      discoveredSyncPaths: discoveredSyncPaths ?? this.discoveredSyncPaths,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      filesChecked: filesChecked ?? this.filesChecked,
      filesSynced: filesSynced ?? this.filesSynced,
      conflicts: conflicts ?? this.conflicts,
      errorMessage: errorMessage,
      isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
    );
  }

  @override
  List<Object?> get props => [
        status,
        syncFolderPath,
        discoveredSyncPaths,
        lastSyncTime,
        filesChecked,
        filesSynced,
        conflicts,
        errorMessage,
        isAutoSyncEnabled,
      ];
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final notifier = SyncNotifier(ref);
  notifier.initialize();
  return notifier;
});

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  final SyncService _service = SyncService.instance;

  SyncNotifier(this._ref)
      : super(SyncState(
          syncFolderPath: SyncService.instance.effectiveSyncPath,
          discoveredSyncPaths: SyncService.instance.getDiscoveredSyncPaths(),
        ));

  Future<void> initialize() async {
    try {
      final savedPath = await DatabaseService.instance.getSetting('sync_folder_path');
      if (savedPath != null && savedPath.isNotEmpty) {
        _service.setCustomSyncPath(savedPath);
      }
    } catch (_) {}

    final discovered = _service.getDiscoveredSyncPaths();
    state = state.copyWith(
      syncFolderPath: _service.effectiveSyncPath,
      discoveredSyncPaths: discovered,
    );
    _startWatcher();
  }

  void _startWatcher() {
    if (!state.isAutoSyncEnabled) return;
    _service.startWatcher(onChange: () {
      triggerSync();
    });
  }

  Future<void> triggerSync() async {
    final workspaceState = _ref.read(workspaceProvider);
    final workspaceUri = workspaceState.rootUri;
    if (workspaceUri == null) {
      state = state.copyWith(
        status: SyncStatus.idle,
        errorMessage: 'No workspace open to sync',
      );
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);

    final result = await _service.performSync(localWorkspacePath: workspaceUri);

    if (result.success) {
      state = state.copyWith(
        status: result.conflicts.isNotEmpty ? SyncStatus.conflict : SyncStatus.synced,
        lastSyncTime: result.timestamp,
        filesChecked: result.filesChecked,
        filesSynced: result.filesSynced,
        conflicts: result.conflicts,
      );
      // Refresh workspace to load any pulled or conflict files
      await _ref.read(workspaceProvider.notifier).refreshWorkspace();
      try {
        await _ref.read(themeProvider.notifier).syncFromCloud();
      } catch (_) {}
    } else {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: result.errorMessage,
        lastSyncTime: result.timestamp,
      );
    }
  }

  void toggleAutoSync() {
    final newEnabled = !state.isAutoSyncEnabled;
    state = state.copyWith(isAutoSyncEnabled: newEnabled);
    if (newEnabled) {
      _startWatcher();
    } else {
      _service.stopWatcher();
    }
  }

  Future<void> setCustomSyncFolder(String path) async {
    _service.setCustomSyncPath(path);
    try {
      await DatabaseService.instance.setSetting('sync_folder_path', path);
    } catch (_) {}
    state = state.copyWith(
      syncFolderPath: path,
      discoveredSyncPaths: _service.getDiscoveredSyncPaths(),
    );
    _startWatcher();
    triggerSync();
  }

  Future<int> reconcileDocumentsAndAutosync() async {
    final count = await _service.reconcileFolders(
      sourcePath: SyncService.fallbackAndroidSyncPath,
      targetPath: SyncService.primaryAndroidSyncPath,
    );
    await _ref.read(workspaceProvider.notifier).refreshWorkspace();
    return count;
  }

  void refreshDiscoveredPaths() {
    state = state.copyWith(
      syncFolderPath: _service.effectiveSyncPath,
      discoveredSyncPaths: _service.getDiscoveredSyncPaths(),
    );
  }

  void clearConflicts() {
    state = state.copyWith(
      conflicts: [],
      status: SyncStatus.synced,
    );
  }

  @override
  void dispose() {
    _service.stopWatcher();
    super.dispose();
  }
}
