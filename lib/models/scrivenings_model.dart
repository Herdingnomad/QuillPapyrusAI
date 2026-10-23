import 'package:equatable/equatable.dart';
import 'package:quill_papyrus_ai/models/manuscript_metadata.dart';

class ScriveningsSegment with Equatable {
  final String fileUri;
  final String fileName;
  final String title;
  final String content;
  final int startOffset;
  final int endOffset;
  final ManuscriptMetadata metadata;

  const ScriveningsSegment({
    required this.fileUri,
    required this.fileName,
    required this.title,
    required this.content,
    required this.startOffset,
    required this.endOffset,
    required this.metadata,
  });

  int get wordCount => content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;

  ScriveningsSegment copyWith({
    String? fileUri,
    String? fileName,
    String? title,
    String? content,
    int? startOffset,
    int? endOffset,
    ManuscriptMetadata? metadata,
  }) {
    return ScriveningsSegment(
      fileUri: fileUri ?? this.fileUri,
      fileName: fileName ?? this.fileName,
      title: title ?? this.title,
      content: content ?? this.content,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [fileUri, fileName, title, startOffset, endOffset, metadata];
}

class StitchedDocument with Equatable {
  final List<ScriveningsSegment> segments;
  final String stitchedContent;

  const StitchedDocument({
    required this.segments,
    required this.stitchedContent,
  });

  int get totalWords =>
      stitchedContent.trim().isEmpty ? 0 : stitchedContent.trim().split(RegExp(r'\s+')).length;

  ScriveningsSegment? segmentAt(int offset) {
    for (final seg in segments) {
      if (offset >= seg.startOffset && offset <= seg.endOffset) {
        return seg;
      }
    }
    return segments.isNotEmpty ? segments.first : null;
  }

  @override
  List<Object?> get props => [segments, stitchedContent];
}
