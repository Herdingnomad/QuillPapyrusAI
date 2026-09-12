import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/document_template.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:uuid/uuid.dart';

class TemplateState {
  final List<DocumentTemplate> templates;
  final String dateFormat; // 'us' (MM-DD-YYYY), 'iso' (YYYY-MM-DD), 'eu' (DD-MM-YYYY)
  final String searchQuery;
  final String selectedCategory;
  final bool isLoading;

  const TemplateState({
    required this.templates,
    this.dateFormat = 'us',
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.isLoading = false,
  });

  List<DocumentTemplate> get filteredTemplates {
    return templates.where((t) {
      final matchesCat = selectedCategory == 'All' ||
          t.category.toLowerCase() == selectedCategory.toLowerCase();
      if (!matchesCat) return false;

      if (searchQuery.trim().isEmpty) return true;
      final q = searchQuery.toLowerCase().trim();
      return t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          t.content.toLowerCase().contains(q);
    }).toList();
  }

  List<String> get availableCategories {
    final set = <String>{'All'};
    for (final t in templates) {
      if (t.category.trim().isNotEmpty) {
        set.add(t.category.trim());
      }
    }
    return set.toList();
  }

  TemplateState copyWith({
    List<DocumentTemplate>? templates,
    String? dateFormat,
    String? searchQuery,
    String? selectedCategory,
    bool? isLoading,
  }) {
    return TemplateState(
      templates: templates ?? this.templates,
      dateFormat: dateFormat ?? this.dateFormat,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TemplateNotifier extends StateNotifier<TemplateState> {
  final DatabaseService _db;

  TemplateNotifier(this._db)
      : super(const TemplateState(
          templates: [],
          isLoading: true,
        )) {
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    state = state.copyWith(isLoading: true);
    final list = await _db.getTemplates();
    final savedDateFormat = await _db.getSetting('template_date_format') ?? 'us';

    state = state.copyWith(
      templates: list,
      dateFormat: savedDateFormat,
      isLoading: false,
    );
  }

  Future<void> setDateFormat(String format) async {
    final validFormat = (format == 'iso' || format == 'eu') ? format : 'us';
    state = state.copyWith(dateFormat: validFormat);
    await _db.setSetting('template_date_format', validFormat);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<void> createTemplate(DocumentTemplate template) async {
    await _db.upsertTemplate(template);
    final updated = List<DocumentTemplate>.from(state.templates);
    updated.insert(0, template);
    state = state.copyWith(templates: updated);
  }

  Future<void> updateTemplate(DocumentTemplate template) async {
    final updatedTmpl = template.copyWith(updatedAt: DateTime.now());
    await _db.upsertTemplate(updatedTmpl);

    final updated = state.templates.map((t) {
      return t.id == updatedTmpl.id ? updatedTmpl : t;
    }).toList();
    state = state.copyWith(templates: updated);
  }

  Future<void> deleteTemplate(String id) async {
    await _db.deleteTemplate(id);
    final updated = state.templates.where((t) => t.id != id).toList();
    state = state.copyWith(templates: updated);
  }

  Future<DocumentTemplate> duplicateTemplate(String id, {String? newTitle}) async {
    final target = state.templates.firstWhere(
      (t) => t.id == id,
      orElse: () => DocumentTemplate.defaultTemplates.first,
    );
    final now = DateTime.now();
    final duplicated = DocumentTemplate(
      id: const Uuid().v4(),
      title: newTitle ?? '${target.title} (Copy)',
      description: target.description,
      category: target.category,
      icon: target.icon,
      content: target.content,
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
    );
    await createTemplate(duplicated);
    return duplicated;
  }

  Future<DocumentTemplate> saveActiveDocumentAsTemplate({
    required String title,
    required String content,
    String? category,
    String? description,
    String? icon,
  }) async {
    final now = DateTime.now();
    final newTemplate = DocumentTemplate(
      id: const Uuid().v4(),
      title: title.trim().isEmpty ? 'My Custom Template' : title.trim(),
      description: description?.trim().isEmpty == false
          ? description!.trim()
          : 'Template created from active document.',
      category: category?.trim().isEmpty == false ? category!.trim() : 'Custom',
      icon: icon ?? 'description',
      content: content,
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
    );

    await createTemplate(newTemplate);
    return newTemplate;
  }

  Future<bool> importTemplateFromJson(String jsonStr) async {
    try {
      final imported = DocumentTemplate.fromJson(jsonStr);
      final now = DateTime.now();
      final toSave = imported.copyWith(
        id: const Uuid().v4(),
        isBuiltIn: false,
        createdAt: now,
        updatedAt: now,
      );
      await createTemplate(toSave);
      return true;
    } catch (_) {
      return false;
    }
  }

  String exportTemplateToJson(DocumentTemplate template) {
    return template.toJson();
  }
}

final templateProvider = StateNotifierProvider<TemplateNotifier, TemplateState>((ref) {
  return TemplateNotifier(DatabaseService.instance);
});
