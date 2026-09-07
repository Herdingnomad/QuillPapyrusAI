import 'package:yaml/yaml.dart';

class FrontMatterData {
  final String? title;
  final List<String> tags;
  final List<String> topics;
  final DateTime? date;
  final String? dayOfWeek;
  final String? mood;
  final String? status;
  final Map<String, dynamic> customFields;

  FrontMatterData({
    this.title,
    this.tags = const [],
    this.topics = const [],
    this.date,
    this.dayOfWeek,
    this.mood,
    this.status,
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

      final topicsList = yamlMap['topics'];
      List<String> topics = [];
      if (topicsList is YamlList) {
        topics = topicsList.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      } else if (topicsList is String) {
        topics = topicsList.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
      }

      DateTime? date;
      if (yamlMap['date'] != null) {
        date = DateTime.tryParse(yamlMap['date'].toString());
      }

      final dayOfWeek = (yamlMap['day_of_week'] ?? yamlMap['dayOfWeek'])?.toString();
      final mood = yamlMap['mood']?.toString();
      final status = yamlMap['status']?.toString();

      return FrontMatterData(
        title: title,
        tags: tags,
        topics: topics,
        date: date,
        dayOfWeek: dayOfWeek,
        mood: mood,
        status: status,
        customFields: customFields,
      );
    } catch (e) {
      return null;
    }
  }

  static String stripFrontMatter(String content) {
    return content.replaceFirst(_frontMatterExp, '');
  }

  /// Generates the full structured YAML frontmatter block matching the specified format:
  /// ---
  /// title: Journal Entry - Coffee & App Testing
  /// date: 2025-09-05
  /// day_of_week: Saturday
  /// mood: Reflective / Productive
  /// tags: [journaling, technology, productivity, personal_log]
  /// topics: [writing, journaling, app_testing, hardware]
  /// status: complete # Or 'in_progress' if you plan to edit it heavily later
  /// ---
  static String generateFullFrontMatter({
    String? title,
    DateTime? date,
    String? dayOfWeek,
    String? mood,
    List<String>? tags,
    List<String>? topics,
    String? status,
  }) {
    final now = date ?? DateTime.now();
    final dStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dow = dayOfWeek ?? weekdays[now.weekday - 1];
    final t = title ?? 'Untitled';
    final m = mood ?? '';
    final tagList = tags ?? [];
    final topicList = topics ?? [];
    final st = status ?? '';

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('title: $t');
    buffer.writeln('date: $dStr');
    buffer.writeln('day_of_week: $dow');
    buffer.writeln(m.isNotEmpty ? 'mood: $m' : 'mood: ');
    buffer.writeln('tags: [${tagList.join(', ')}]');
    buffer.writeln('topics: [${topicList.join(', ')}]');
    buffer.writeln(st.isNotEmpty ? 'status: $st' : 'status: ');
    buffer.writeln('---');
    return buffer.toString();
  }

  /// Prepends or replaces full structured frontmatter at the top of content
  static String insertOrUpdateFullFrontMatter(
    String content, {
    String? title,
    DateTime? date,
    String? dayOfWeek,
    String? mood,
    List<String>? tags,
    List<String>? topics,
    String? status,
  }) {
    final frontMatterBlock = generateFullFrontMatter(
      title: title,
      date: date,
      dayOfWeek: dayOfWeek,
      mood: mood,
      tags: tags,
      topics: topics,
      status: status,
    );

    final strippedContent = stripFrontMatter(content);
    final buffer = StringBuffer();
    buffer.write(frontMatterBlock);
    if (!strippedContent.startsWith('\n') && strippedContent.isNotEmpty) {
      buffer.writeln();
    }
    buffer.write(strippedContent);
    return buffer.toString();
  }

  static String addOrUpdateFrontMatter(String content, FrontMatterData data) {
    final strippedContent = stripFrontMatter(content);

    final buffer = StringBuffer();
    buffer.writeln('---');
    if (data.title != null) buffer.writeln('title: "${data.title}"');
    if (data.date != null) {
      final d = data.date!;
      buffer.writeln('date: ${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    if (data.dayOfWeek != null) buffer.writeln('day_of_week: ${data.dayOfWeek}');
    if (data.mood != null) buffer.writeln('mood: ${data.mood}');
    if (data.tags.isNotEmpty) {
      buffer.writeln('tags: [${data.tags.join(', ')}]');
    }
    if (data.topics.isNotEmpty) {
      buffer.writeln('topics: [${data.topics.join(', ')}]');
    }
    if (data.status != null) buffer.writeln('status: ${data.status}');

    data.customFields.forEach((key, value) {
      if (key != 'title' &&
          key != 'date' &&
          key != 'day_of_week' &&
          key != 'dayOfWeek' &&
          key != 'mood' &&
          key != 'tags' &&
          key != 'topics' &&
          key != 'status') {
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
        topics: existingData.topics,
        date: existingData.date,
        dayOfWeek: existingData.dayOfWeek,
        mood: existingData.mood,
        status: existingData.status,
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
      topics: existingData?.topics ?? const [],
      date: existingData?.date,
      dayOfWeek: existingData?.dayOfWeek,
      mood: existingData?.mood,
      status: existingData?.status,
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
      topics: existingData.topics,
      date: existingData.date,
      dayOfWeek: existingData.dayOfWeek,
      mood: existingData.mood,
      status: existingData.status,
      customFields: existingData.customFields,
    );
    return addOrUpdateFrontMatter(content, updatedData);
  }

  /// Toggles a topic in the given markdown content. If topic exists, it is removed; otherwise added.
  static String toggleTopic(String content, String topic) {
    final cleanTopic = topic.trim().replaceAll('@', '');
    if (cleanTopic.isEmpty) return content;

    final existingData = parse(content);
    if (existingData != null) {
      final topics = List<String>.from(existingData.topics);
      if (topics.contains(cleanTopic)) {
        topics.remove(cleanTopic);
      } else {
        topics.add(cleanTopic);
      }
      final updatedData = FrontMatterData(
        title: existingData.title,
        tags: existingData.tags,
        topics: topics,
        date: existingData.date,
        dayOfWeek: existingData.dayOfWeek,
        mood: existingData.mood,
        status: existingData.status,
        customFields: existingData.customFields,
      );
      return addOrUpdateFrontMatter(content, updatedData);
    } else {
      final newData = FrontMatterData(
        topics: [cleanTopic],
      );
      return addOrUpdateFrontMatter(content, newData);
    }
  }

  /// Checks if markdown content contains a specific topic in its frontmatter
  static bool hasTopic(String content, String topic) {
    final cleanTopic = topic.trim().replaceAll('@', '');
    final data = parse(content);
    return data?.topics.contains(cleanTopic) ?? false;
  }
}
