import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/app_theme_data.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class ThemeState {
  final AppThemeData activeTheme;
  final List<AppThemeData> presets;
  final List<AppThemeData> customThemes;
  final bool isLoading;

  const ThemeState({
    required this.activeTheme,
    required this.presets,
    required this.customThemes,
    this.isLoading = false,
  });

  List<AppThemeData> get allThemes => [...presets, ...customThemes];

  ThemeState copyWith({
    AppThemeData? activeTheme,
    List<AppThemeData>? presets,
    List<AppThemeData>? customThemes,
    bool? isLoading,
  }) {
    return ThemeState(
      activeTheme: activeTheme ?? this.activeTheme,
      presets: presets ?? this.presets,
      customThemes: customThemes ?? this.customThemes,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  final DatabaseService _db;

  ThemeNotifier(this._db)
      : super(const ThemeState(
          activeTheme: AppThemeData.gruvboxDark,
          presets: AppThemeData.defaultPresets,
          customThemes: [],
          isLoading: true,
        )) {
    loadThemes();
  }

  Future<void> loadThemes() async {
    state = state.copyWith(isLoading: true);
    final customList = await _db.getCustomThemes();
    final savedThemeId = await _db.getSetting('active_theme_id');

    final allThemes = [...state.presets, ...customList];
    AppThemeData active = AppThemeData.gruvboxDark;

    if (savedThemeId != null) {
      final found = allThemes.where((t) => t.id == savedThemeId);
      if (found.isNotEmpty) {
        active = found.first;
      }
    }

    GruvboxColors.setActiveTheme(active);

    state = state.copyWith(
      activeTheme: active,
      customThemes: customList,
      isLoading: false,
    );
  }

  Future<void> selectTheme(String themeId) async {
    final all = state.allThemes;
    final match = all.where((t) => t.id == themeId);
    if (match.isNotEmpty) {
      final selected = match.first;
      GruvboxColors.setActiveTheme(selected);
      state = state.copyWith(activeTheme: selected);
      await _db.setSetting('active_theme_id', selected.id);
    }
  }

  Future<void> saveCustomTheme(AppThemeData theme) async {
    final customTheme = theme.copyWith(isCustom: true);
    await _db.upsertCustomTheme(customTheme);

    final updatedCustom = List<AppThemeData>.from(state.customThemes);
    final existingIndex = updatedCustom.indexWhere((t) => t.id == customTheme.id);
    if (existingIndex >= 0) {
      updatedCustom[existingIndex] = customTheme;
    } else {
      updatedCustom.insert(0, customTheme);
    }

    // If active theme was modified, update activeTheme and GruvboxColors
    var newActive = state.activeTheme;
    if (state.activeTheme.id == customTheme.id) {
      newActive = customTheme;
      GruvboxColors.setActiveTheme(newActive);
    }

    state = state.copyWith(
      customThemes: updatedCustom,
      activeTheme: newActive,
    );
  }

  Future<void> deleteCustomTheme(String themeId) async {
    await _db.deleteCustomTheme(themeId);
    final updatedCustom = state.customThemes.where((t) => t.id != themeId).toList();

    var newActive = state.activeTheme;
    if (state.activeTheme.id == themeId) {
      newActive = AppThemeData.gruvboxDark;
      GruvboxColors.setActiveTheme(newActive);
      await _db.setSetting('active_theme_id', newActive.id);
    }

    state = state.copyWith(
      customThemes: updatedCustom,
      activeTheme: newActive,
    );
  }

  Future<AppThemeData> duplicateTheme(String themeId, {String? newName}) async {
    final all = state.allThemes;
    final target = all.firstWhere((t) => t.id == themeId, orElse: () => state.activeTheme);

    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final name = newName ?? '${target.name} (Copy)';
    final cloned = target.copyWith(
      id: newId,
      name: name,
      isCustom: true,
    );

    await saveCustomTheme(cloned);
    await selectTheme(cloned.id);
    return cloned;
  }

  Future<bool> importThemeFromJson(String jsonStr) async {
    try {
      final imported = AppThemeData.fromJson(jsonStr);
      final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      final toSave = imported.copyWith(
        id: newId,
        isCustom: true,
      );
      await saveCustomTheme(toSave);
      await selectTheme(toSave.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  String exportThemeToJson(AppThemeData theme) {
    return theme.toJson();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier(DatabaseService.instance);
});
