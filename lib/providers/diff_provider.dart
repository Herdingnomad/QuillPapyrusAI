import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/diff_model.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';

class DiffState {
  final InlineDiffProposal? proposal;
  final bool isApplying;

  const DiffState({
    this.proposal,
    this.isApplying = false,
  });

  bool get hasActiveDiff => proposal != null;

  DiffState copyWith({
    InlineDiffProposal? Function()? proposal,
    bool? isApplying,
  }) {
    return DiffState(
      proposal: proposal != null ? proposal() : this.proposal,
      isApplying: isApplying ?? this.isApplying,
    );
  }
}

final diffProvider = StateNotifierProvider<DiffNotifier, DiffState>((ref) {
  return DiffNotifier(ref);
});

class DiffNotifier extends StateNotifier<DiffState> {
  final Ref _ref;

  DiffNotifier(this._ref) : super(const DiffState());

  void showProposal(InlineDiffProposal proposal) {
    state = state.copyWith(proposal: () => proposal);
  }

  void clearProposal() {
    state = state.copyWith(proposal: () => null);
  }

  void acceptDiff() {
    final proposal = state.proposal;
    if (proposal == null) return;

    final editor = _ref.read(editorProvider);
    final activeTab = editor.activeTab;
    if (activeTab == null) return;

    final content = activeTab.content;
    if (proposal.selectionStart <= content.length && proposal.selectionEnd <= content.length) {
      final updatedContent = content.replaceRange(
        proposal.selectionStart,
        proposal.selectionEnd,
        proposal.proposedText,
      );
      _ref.read(editorProvider.notifier).updateContent(updatedContent);
    } else {
      // Fallback: replace target substring if range shifted
      final updatedContent = content.replaceFirst(proposal.originalText, proposal.proposedText);
      _ref.read(editorProvider.notifier).updateContent(updatedContent);
    }

    clearProposal();
  }

  void rejectDiff() {
    clearProposal();
  }
}
