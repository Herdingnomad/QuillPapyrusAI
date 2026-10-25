import 'dart:convert';

class DetectedArtwork {
  final List<int> box2d; // [ymin, xmin, ymax, xmax] (0-1000 scale)
  final String label;

  DetectedArtwork({
    required this.box2d,
    required this.label,
  });

  factory DetectedArtwork.fromJson(Map<String, dynamic> json) {
    List<int> box = [0, 0, 1000, 1000];
    if (json['box_2d'] is List) {
      box = (json['box_2d'] as List).map((e) => (e as num).toInt()).toList();
    }
    return DetectedArtwork(
      box2d: box,
      label: json['label'] as String? ?? 'Sketch',
    );
  }

  Map<String, dynamic> toJson() => {
        'box_2d': box2d,
        'label': label,
      };
}

class JournalPageAnalysisResult {
  final List<DetectedArtwork> artworks;
  final String transcribedText;
  final String? detectedDate;
  final List<String> tags;

  JournalPageAnalysisResult({
    required this.artworks,
    required this.transcribedText,
    this.detectedDate,
    this.tags = const [],
  });

  factory JournalPageAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawArtworks = json['artworks'] as List? ?? [];
    final artworks = rawArtworks
        .whereType<Map<String, dynamic>>()
        .map((m) => DetectedArtwork.fromJson(m))
        .toList();

    final tagsList = (json['tags'] as List? ?? []).map((e) => e.toString()).toList();

    return JournalPageAnalysisResult(
      artworks: artworks,
      transcribedText: json['transcribed_text'] as String? ?? '',
      detectedDate: json['detected_date'] as String?,
      tags: tagsList,
    );
  }

  static JournalPageAnalysisResult? tryParseJson(String rawOutput) {
    try {
      // Find JSON block if enclosed in markdown code fences
      var cleaned = rawOutput.trim();
      final codeFenceRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
      final match = codeFenceRegex.firstMatch(cleaned);
      if (match != null) {
        cleaned = match.group(1)!.trim();
      }

      final decoded = json.decode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return JournalPageAnalysisResult.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
