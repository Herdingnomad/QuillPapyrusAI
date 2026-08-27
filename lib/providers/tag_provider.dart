import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';

/// Derived provider that builds tag index from workspace
final tagIndexProvider = Provider<Map<String, List<String>>>((ref) {
  // Watch workspace state to re-evaluate when workspace updates
  final workspace = ref.watch(workspaceProvider);
  final map = <String, List<String>>{};
  for (final tag in workspace.tags) {
    map[tag] = [workspace.rootUri ?? ''];
  }
  return map;
});

/// Active tag filter
final activeTagFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered file URIs based on selected tag
final filteredFileUrisProvider = Provider<Set<String>?>((ref) {
  final activeTag = ref.watch(activeTagFilterProvider);
  if (activeTag == null) return null; // null means show all

  final tagIndex = ref.watch(tagIndexProvider);
  return tagIndex[activeTag]?.toSet() ?? {};
});
