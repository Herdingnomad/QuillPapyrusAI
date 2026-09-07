import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';

/// Derived provider that provides tag index from workspace
final tagIndexProvider = Provider<Map<String, List<String>>>((ref) {
  final workspace = ref.watch(workspaceProvider);
  return workspace.tagIndex;
});

/// Derived provider that provides topic index from workspace
final topicIndexProvider = Provider<Map<String, List<String>>>((ref) {
  final workspace = ref.watch(workspaceProvider);
  return workspace.topicIndex;
});

/// Active tag filter
final activeTagFilterProvider = StateProvider<String?>((ref) => null);

/// Active topic filter
final activeTopicFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered file URIs based on selected tag and/or topic
final filteredFileUrisProvider = Provider<Set<String>?>((ref) {
  final activeTag = ref.watch(activeTagFilterProvider);
  final activeTopic = ref.watch(activeTopicFilterProvider);

  if (activeTag == null && activeTopic == null) {
    return null; // null means show all
  }

  final tagIndex = ref.watch(tagIndexProvider);
  final topicIndex = ref.watch(topicIndexProvider);

  Set<String>? tagMatches;
  if (activeTag != null) {
    tagMatches = tagIndex[activeTag]?.toSet() ?? <String>{};
  }

  Set<String>? topicMatches;
  if (activeTopic != null) {
    topicMatches = topicIndex[activeTopic]?.toSet() ?? <String>{};
  }

  if (tagMatches != null && topicMatches != null) {
    return tagMatches.intersection(topicMatches);
  }
  return tagMatches ?? topicMatches ?? <String>{};
});
