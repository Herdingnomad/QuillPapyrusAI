import 'package:equatable/equatable.dart';

enum SyncStatus {
  synced,
  syncing,
  conflict,
  idle,
  error,
}

class SyncManifestEntry with Equatable {
  final String relativePath;
  final String sha256Hash;
  final int lastModified;
  final int fileSize;
  final int syncTimestamp;

  const SyncManifestEntry({
    required this.relativePath,
    required this.sha256Hash,
    required this.lastModified,
    required this.fileSize,
    required this.syncTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'relative_path': relativePath,
      'sha256_hash': sha256Hash,
      'last_modified': lastModified,
      'file_size': fileSize,
      'sync_timestamp': syncTimestamp,
    };
  }

  factory SyncManifestEntry.fromMap(Map<String, dynamic> map) {
    return SyncManifestEntry(
      relativePath: map['relative_path'] as String,
      sha256Hash: map['sha256_hash'] as String,
      lastModified: map['last_modified'] as int,
      fileSize: map['file_size'] as int,
      syncTimestamp: map['sync_timestamp'] as int,
    );
  }

  @override
  List<Object?> get props => [relativePath, sha256Hash, lastModified, fileSize, syncTimestamp];
}

class SyncConflict with Equatable {
  final String relativePath;
  final String localUri;
  final String conflictUri;
  final DateTime timestamp;

  const SyncConflict({
    required this.relativePath,
    required this.localUri,
    required this.conflictUri,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [relativePath, localUri, conflictUri, timestamp];
}

class SyncResult with Equatable {
  final bool success;
  final int filesChecked;
  final int filesSynced;
  final List<SyncConflict> conflicts;
  final String? errorMessage;
  final DateTime timestamp;

  const SyncResult({
    required this.success,
    this.filesChecked = 0,
    this.filesSynced = 0,
    this.conflicts = const [],
    this.errorMessage,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [success, filesChecked, filesSynced, conflicts, errorMessage, timestamp];
}
