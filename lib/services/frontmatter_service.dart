import 'package:yaml/yaml.dart';

class FrontMatterData {
  final String? title;
  final List<String> tags;
  final DateTime? date;
  final Map<String, dynamic> customFields;

  FrontMatterData({
    this.title,
    this.tags = const [],
    this.date,
    this.customFields = const {},
  });
}

class FrontMatterService {
  static final RegExp _frontMatterExp = RegExp(r'^---\r?\n(.*?)\r?\n---\r?\n?', dotAll: true);

  static FrontMatterData? parse(String content) {
    final match = _frontMatterExp.firstMatch(content);
    if (match == null) return null;

    try {
      final yamlContent = match.group(1)!;
      final dynamic parsed = loadYaml(yamlContent);
      if (parsed is! YamlMap) return null;

      final yamlMap = parsed;
      final customFields = <String, dynamic>{};
      for (final key in yamlMap.keys) {
        customFields[key.toString()] = yamlMap[key];
      }

      final title = yamlMap['title']?.toString();
      final tagsList = yamlMap['tags'];
      List<String> tags = [];
      if (tagsList is YamlList) {
        tags = tagsList.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      } else if (tagsList is String) {
        tags = tagsList.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
      }

      DateTime? date;
      if (yamlMap['date'] != null) {
        date = DateTime.tryParse(yamlMap['date'].toString());
      }

      return FrontMatterData(
        title: title,
        tags: tags,
        date: date,
        customFields: customFields,
      );
    } catch (e) {
      return null;
    }
  }

  static String stripFrontMatter(String content) {
    return content.replaceFirst(_frontMatterExp, '');
  }

  static String addOrUpdateFrontMatter(String content, FrontMatterData data) {
    final strippedContent = stripFrontMatter(content);

    final buffer = StringBuffer();
    buffer.writeln('---');
    if (data.title != null) buffer.writeln('title: "${data.title}"');
    if (data.date != null) buffer.writeln('date: ${data.date!.toIso8601String()}');
    if (data.tags.isNotEmpty) {
      buffer.writeln('tags: [${data.tags.join(', ')}]');
    }

    data.customFields.forEach((key, value) {
      if (key != 'title' && key != 'date' && key != 'tags') {
        buffer.writeln('$key: $value');
      }
    });

    buffer.writeln('---');
    if (!strippedContent.startsWith('\n') && strippedContent.isNotEmpty) {
      buffer.writeln();
    }
    buffer.write(strippedContent);
    return buffer.toString();
  }

  /// Toggles a tag in the given markdown content. If tag exists, it is removed; otherwise added.
  static String toggleTag(String content, String tag) {
    final cleanTag = tag.trim().replaceAll('#', '');
    if (cleanTag.isEmpty) return content;

    final existingData = parse(content);
    if (existingData != null) {
      final tags = List<String>.from(existingData.tags);
      if (tags.contains(cleanTag)) {
        tags.remove(cleanTag);
      } else {
        tags.add(cleanTag);
      }
      final updatedData = FrontMatterData(
        title: existingData.title,
        tags: tags,
        date: existingData.date,
        customFields: existingData.customFields,
      );
      return addOrUpdateFrontMatter(content, updatedData);
    } else {
      final newData = FrontMatterData(
        tags: [cleanTag],
      );
      return addOrUpdateFrontMatter(content, newData);
    }
  }

  /// Checks if markdown content contains a specific tag in its frontmatter
  static bool hasTag(String content, String tag) {
    final cleanTag = tag.trim().replaceAll('#', '');
    final data = parse(content);
    return data?.tags.contains(cleanTag) ?? false;
  }

  /// Adds a tag to the given markdown content if not already present
  static String addTag(String content, String tag) {
    final cleanTag = tag.trim().replaceAll('#', '');
    if (cleanTag.isEmpty) return content;

    final existingData = parse(content);
    final tags = existingData != null ? List<String>.from(existingData.tags) : <String>[];
    if (!tags.contains(cleanTag)) {
      tags.add(cleanTag);
    }
    final updatedData = FrontMatterData(
      title: existingData?.title,
      tags: tags,
      date: existingData?.date,
      customFields: existingData?.customFields ?? {},
    );
    return addOrUpdateFrontMatter(content, updatedData);
  }

  /// Removes a tag from the given markdown content
  static String removeTag(String content, String tag) {
    final cleanTag = tag.trim().replaceAll('#', '');
    final existingData = parse(content);
    if (existingData == null) return content;

    final tags = List<String>.from(existingData.tags)..remove(cleanTag);
    final updatedData = FrontMatterData(
      title: existingData.title,
      tags: tags,
      date: existingData.date,
      customFields: existingData.customFields,
    );
    return addOrUpdateFrontMatter(content, updatedData);
  }
}
