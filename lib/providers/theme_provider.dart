import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/app_theme_data.dart';
import 'package:quill_papyrus_ai/services/database_service.dart';
import 'package:quill_papyrus_ai/services/sync_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class ThemeState {
  final AppThemeData activeTheme;
  final List<AppThemeData> presets;
  final List<AppThemeData> customThemes;
  final bool isLoading;
  final DateTime? lastThemeSyncTime;
  final bool isSyncingTheme;

  const ThemeState({
    required this.activeTheme,
    required this.presets,
    required this.customThemes,
    this.isLoading = false,
    this.lastThemeSyncTime,
    this.isSyncingTheme = false,
  });

  List<AppThemeData> get allThemes => [...presets, ...customThemes];

  ThemeState copyWith({
    AppThemeData? activeTheme,
    List<AppThemeData>? presets,
    List<AppThemeData>? customThemes,
    bool? isLoading,
    DateTime? lastThemeSyncTime,
    bool? isSyncingTheme,
  }) {
    return ThemeState(
      activeTheme: activeTheme ?? this.activeTheme,
      presets: presets ?? this.presets,
      customThemes: customThemes ?? this.customThemes,
      isLoading: isLoading ?? this.isLoading,
      lastThemeSyncTime: lastThemeSyncTime ?? this.lastThemeSyncTime,
      isSyncingTheme: isSyncingTheme ?? this.isSyncingTheme,
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

    // Sync with cloud settings if available
    await syncFromCloud();
  }

  Future<void> selectTheme(String themeId) async {
    final all = state.allThemes;
    final match = all.where((t) => t.id == themeId);
    if (match.isNotEmpty) {
      final selected = match.first;
      GruvboxColors.setActiveTheme(selected);
      state = state.copyWith(activeTheme: selected);
      await _db.setSetting('active_theme_id', selected.id);
      await exportThemesToCloud();
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

    await exportThemesToCloud();
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

    await exportThemesToCloud();
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

  /// Exports the active theme and all custom themes to the sync folder (.quill/theme_settings.json)
  Future<void> exportThemesToCloud({String? targetFolderPath}) async {
    try {
      final folder = targetFolderPath ?? SyncService.instance.effectiveSyncPath;
      if (!Directory(folder).existsSync()) return;

      final filePath = p.join(folder, '.quill', 'theme_settings.json');
      final now = DateTime.now().millisecondsSinceEpoch;

      final data = {
        'version': 1,
        'updatedAt': now,
        'platform': Platform.operatingSystem,
        'activeThemeId': state.activeTheme.id,
        'customThemes': state.customThemes.map((t) => t.toMap()).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await SyncService.instance.writeAtomic(filePath, jsonStr);
      await _db.setSetting('themes_synced_at', now.toString());
      state = state.copyWith(lastThemeSyncTime: DateTime.fromMillisecondsSinceEpoch(now));
    } catch (_) {}
  }

  /// Synchronizes themes from the sync folder (.quill/theme_settings.json) into the local database
  Future<bool> syncFromCloud({String? targetFolderPath}) async {
    try {
      final folder = targetFolderPath ?? SyncService.instance.effectiveSyncPath;
      final file = File(p.join(folder, '.quill', 'theme_settings.json'));
      if (!await file.exists()) {
        // If cloud file doesn't exist yet, seed it with current local themes
        if (Directory(folder).existsSync()) {
          await exportThemesToCloud(targetFolderPath: folder);
        }
        return false;
      }

      state = state.copyWith(isSyncingTheme: true);
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>?;
      if (data == null) {
        state = state.copyWith(isSyncingTheme: false);
        return false;
      }

      final cloudTimestamp = (data['updatedAt'] as num?)?.toInt() ?? 0;
      final localTimestampStr = await _db.getSetting('themes_synced_at');
      final localTimestamp = int.tryParse(localTimestampStr ?? '0') ?? 0;

      // If local is strictly newer, export local to cloud instead
      if (localTimestamp > cloudTimestamp) {
        await exportThemesToCloud(targetFolderPath: folder);
        state = state.copyWith(isSyncingTheme: false);
        return true;
      }

      // Otherwise import cloud themes
      final rawCustom = data['customThemes'] as List<dynamic>? ?? [];
      final List<AppThemeData> importedCustom = [];
      for (final item in rawCustom) {
        if (item is Map<String, dynamic>) {
          try {
            final theme = AppThemeData.fromMap(item);
            importedCustom.add(theme);
            await _db.upsertCustomTheme(theme);
          } catch (_) {}
        }
      }

      final activeThemeId = data['activeThemeId'] as String?;
      AppThemeData newActive = state.activeTheme;

      if (activeThemeId != null && activeThemeId.isNotEmpty) {
        final all = [...state.presets, ...importedCustom];
        final match = all.where((t) => t.id == activeThemeId);
        if (match.isNotEmpty) {
          newActive = match.first;
          GruvboxColors.setActiveTheme(newActive);
          await _db.setSetting('active_theme_id', newActive.id);
        }
      }

      await _db.setSetting('themes_synced_at', cloudTimestamp.toString());

      state = state.copyWith(
        activeTheme: newActive,
        customThemes: importedCustom.isNotEmpty ? importedCustom : state.customThemes,
        lastThemeSyncTime: DateTime.fromMillisecondsSinceEpoch(cloudTimestamp),
        isSyncingTheme: false,
      );
      return true;
    } catch (_) {
      state = state.copyWith(isSyncingTheme: false);
      return false;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier(DatabaseService.instance);
});
