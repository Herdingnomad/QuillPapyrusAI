import 'package:equatable/equatable.dart';
import 'package:yaml/yaml.dart';

enum SceneDraftStatus {
  idea,
  draft,
  revised,
  polished,
}

extension SceneDraftStatusExtension on SceneDraftStatus {
  String get label {
    switch (this) {
      case SceneDraftStatus.idea:
        return 'Idea';
      case SceneDraftStatus.draft:
        return 'Draft';
      case SceneDraftStatus.revised:
        return 'Revised';
      case SceneDraftStatus.polished:
        return 'Polished';
    }
  }

  static SceneDraftStatus fromString(String? val) {
    if (val == null) return SceneDraftStatus.draft;
    final lower = val.trim().toLowerCase();
    switch (lower) {
      case 'idea':
        return SceneDraftStatus.idea;
      case 'revised':
      case 'revision':
        return SceneDraftStatus.revised;
      case 'polished':
      case 'final':
        return SceneDraftStatus.polished;
      case 'draft':
      default:
        return SceneDraftStatus.draft;
    }
  }
}

class ManuscriptMetadata with Equatable {
  final String title;
  final String? pov;
  final String? timeline;
  final SceneDraftStatus status;
  final int? targetWords;
  final String? synopsis;
  final List<String> plotlines;
  final List<String> characters;
  final List<String> settings;
  final List<String> tags;
  final int? order;

  const ManuscriptMetadata({
    required this.title,
    this.pov,
    this.timeline,
    this.status = SceneDraftStatus.draft,
    this.targetWords,
    this.synopsis,
    this.plotlines = const [],
    this.characters = const [],
    this.settings = const [],
    this.tags = const [],
    this.order,
  });

  ManuscriptMetadata copyWith({
    String? title,
    String? pov,
    String? timeline,
    SceneDraftStatus? status,
    int? targetWords,
    String? synopsis,
    List<String>? plotlines,
    List<String>? characters,
    List<String>? settings,
    List<String>? tags,
    int? order,
  }) {
    return ManuscriptMetadata(
      title: title ?? this.title,
      pov: pov ?? this.pov,
      timeline: timeline ?? this.timeline,
      status: status ?? this.status,
      targetWords: targetWords ?? this.targetWords,
      synopsis: synopsis ?? this.synopsis,
      plotlines: plotlines ?? this.plotlines,
      characters: characters ?? this.characters,
      settings: settings ?? this.settings,
      tags: tags ?? this.tags,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      if (pov != null && pov!.isNotEmpty) 'pov': pov,
      if (timeline != null && timeline!.isNotEmpty) 'timeline': timeline,
      'status': status.label,
      if (targetWords != null) 'target_words': targetWords,
      if (synopsis != null && synopsis!.isNotEmpty) 'synopsis': synopsis,
      if (plotlines.isNotEmpty) 'plotlines': plotlines,
      if (characters.isNotEmpty) 'characters': characters,
      if (settings.isNotEmpty) 'settings': settings,
      if (tags.isNotEmpty) 'tags': tags,
      if (order != null) 'order': order,
    };
  }

  factory ManuscriptMetadata.fromFrontmatter(Map<dynamic, dynamic> map, {String fallbackTitle = 'Untitled'}) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      } else if (val is String && val.trim().isNotEmpty) {
        return val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    int? parseInt(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val);
      return null;
    }

    final title = map['title']?.toString() ?? fallbackTitle;
    final pov = map['pov']?.toString() ?? map['point_of_view']?.toString();
    final timeline = map['timeline']?.toString() ?? map['date']?.toString();
    final status = SceneDraftStatusExtension.fromString(map['status']?.toString());
    final targetWords = parseInt(map['target_words'] ?? map['target']);
    final synopsis = map['synopsis']?.toString() ?? map['summary']?.toString() ?? map['description']?.toString();
    final plotlines = parseList(map['plotlines'] ?? map['plots'] ?? map['sub量plot']);
    final characters = parseList(map['characters'] ?? map['cast']);
    final settings = parseList(map['settings'] ?? map['locations']);
    final tags = parseList(map['tags']);
    final order = parseInt(map['order'] ?? map['chapter'] ?? map['scene']);

    return ManuscriptMetadata(
      title: title,
      pov: pov,
      timeline: timeline,
      status: status,
      targetWords: targetWords,
      synopsis: synopsis,
      plotlines: plotlines,
      characters: characters,
      settings: settings,
      tags: tags,
      order: order,
    );
  }

  /// Parses front-matter from a full markdown document string
  static ManuscriptMetadata extractFromMarkdown(String content, {String fallbackTitle = 'Untitled'}) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('---')) {
      // Look for first # Heading for title
      final hMatch = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
      final title = hMatch?.group(1)?.trim() ?? fallbackTitle;
      return ManuscriptMetadata(title: title);
    }

    final closeIdx = trimmed.indexOf('---', 3);
    if (closeIdx == -1) {
      return ManuscriptMetadata(title: fallbackTitle);
    }

    final yamlString = trimmed.substring(3, closeIdx).trim();
    try {
      final doc = loadYaml(yamlString);
      if (doc is Map) {
        return ManuscriptMetadata.fromFrontmatter(doc, fallbackTitle: fallbackTitle);
      }
    } catch (_) {}

    return ManuscriptMetadata(title: fallbackTitle);
  }

  /// Generates the YAML front-matter block
  String toYamlFrontmatter() {
    final sb = StringBuffer();
    sb.writeln('---');
    sb.writeln('title: ${_escapeYaml(title)}');
    if (pov != null && pov!.trim().isNotEmpty) {
      sb.writeln('pov: ${_escapeYaml(pov!)}');
    }
    if (timeline != null && timeline!.trim().isNotEmpty) {
      sb.writeln('timeline: ${_escapeYaml(timeline!)}');
    }
    sb.writeln('status: ${status.label}');
    if (targetWords != null) {
      sb.writeln('target_words: $targetWords');
    }
    if (order != null) {
      sb.writeln('order: $order');
    }
    if (synopsis != null && synopsis!.trim().isNotEmpty) {
      sb.writeln('synopsis: ${_escapeYaml(synopsis!)}');
    }
    if (characters.isNotEmpty) {
      sb.writeln('characters: [${characters.map((c) => _escapeYaml(c)).join(', ')}]');
    }
    if (settings.isNotEmpty) {
      sb.writeln('settings: [${settings.map((s) => _escapeYaml(s)).join(', ')}]');
    }
    if (plotlines.isNotEmpty) {
      sb.writeln('plotlines: [${plotlines.map((p) => _escapeYaml(p)).join(', ')}]');
    }
    if (tags.isNotEmpty) {
      sb.writeln('tags: [${tags.map((t) => _escapeYaml(t)).join(', ')}]');
    }
    sb.writeln('---');
    return sb.toString();
  }

  /// Injects or updates frontmatter in a markdown document without modifying the body
  String applyToMarkdown(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('---')) {
      return '${toYamlFrontmatter()}\n$content';
    }

    final closeIdx = trimmed.indexOf('---', 3);
    if (closeIdx == -1) {
      return '${toYamlFrontmatter()}\n$content';
    }

    final body = trimmed.substring(closeIdx + 3).trimLeft();
    return '${toYamlFrontmatter()}\n$body';
  }

  static String _escapeYaml(String str) {
    if (str.contains(':') || str.contains('#') || str.contains('[') || str.contains(']') || str.contains('"')) {
      return '"${str.replaceAll('"', r'\"')}"';
    }
    return str;
  }

  @override
  List<Object?> get props => [title, pov, timeline, status, targetWords, synopsis, plotlines, characters, settings, tags, order];
}
