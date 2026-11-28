import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/ai_skill.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/skill_service.dart';

class SkillState {
  final List<AiSkill> skills;
  final Set<String> activeSkillIds;
  final bool isLoading;

  const SkillState({
    this.skills = SkillService.builtInSkills,
    this.activeSkillIds = const {},
    this.isLoading = false,
  });

  List<AiSkill> get activeSkills =>
      skills.where((s) => activeSkillIds.contains(s.id)).toList();

  SkillState copyWith({
    List<AiSkill>? skills,
    Set<String>? activeSkillIds,
    bool? isLoading,
  }) {
    return SkillState(
      skills: skills ?? this.skills,
      activeSkillIds: activeSkillIds ?? this.activeSkillIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final skillServiceProvider = Provider<SkillService>((ref) => SkillService());

final skillProvider = StateNotifierProvider<SkillNotifier, SkillState>((ref) {
  final rootUri = ref.watch(workspaceProvider.select((w) => w.rootUri));
  return SkillNotifier(ref.read(skillServiceProvider), workspaceRoot: rootUri);
});

class SkillNotifier extends StateNotifier<SkillState> {
  final SkillService _service;
  final String? workspaceRoot;

  SkillNotifier(this._service, {this.workspaceRoot}) : super(const SkillState()) {
    refreshSkills();
  }

  Future<void> refreshSkills() async {
    state = state.copyWith(isLoading: true);
    final loaded = await _service.loadSkills(workspaceRoot: workspaceRoot);
    if (!mounted) return;
    final validIds = loaded.map((s) => s.id).toSet();
    final filteredActive = state.activeSkillIds.where(validIds.contains).toSet();
    state = state.copyWith(
      skills: loaded,
      activeSkillIds: filteredActive,
      isLoading: false,
    );
  }

  void toggleSkill(String skillId) {
    final next = Set<String>.from(state.activeSkillIds);
    if (next.contains(skillId)) {
      next.remove(skillId);
    } else {
      next.add(skillId);
    }
    state = state.copyWith(activeSkillIds: next);
  }

  void setSkillActive(String skillId, bool active) {
    final next = Set<String>.from(state.activeSkillIds);
    if (active) {
      next.add(skillId);
    } else {
      next.remove(skillId);
    }
    state = state.copyWith(activeSkillIds: next);
  }

  void clearActiveSkills() {
    if (state.activeSkillIds.isEmpty) return;
    state = state.copyWith(activeSkillIds: const {});
  }

  /// Writes the built-in example skills to `<workspaceRoot>/.skills/` and refreshes.
  Future<int> installExampleSkills() async {
    if (workspaceRoot == null || workspaceRoot!.isEmpty) return 0;
    final count = await _service.installExampleSkillsToWorkspace(workspaceRoot!);
    await refreshSkills();
    return count;
  }
}
