import 'package:equatable/equatable.dart';

enum DiffType { equal, addition, deletion }

class DiffChunk with Equatable {
  final DiffType type;
  final String text;

  const DiffChunk({
    required this.type,
    required this.text,
  });

  @override
  List<Object?> get props => [type, text];
}

class InlineDiffProposal with Equatable {
  final String originalText;
  final String proposedText;
  final List<DiffChunk> chunks;
  final int selectionStart;
  final int selectionEnd;
  final String actionTitle;

  const InlineDiffProposal({
    required this.originalText,
    required this.proposedText,
    required this.chunks,
    required this.selectionStart,
    required this.selectionEnd,
    required this.actionTitle,
  });

  @override
  List<Object?> get props => [
        originalText,
        proposedText,
        chunks,
        selectionStart,
        selectionEnd,
        actionTitle,
      ];
}
