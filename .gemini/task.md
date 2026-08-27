# Quill & Papyrus AI — Build Tasks

## Project Initialization
- [x] Run `flutter create` to scaffold project
- [x] Configure `pubspec.yaml` with all dependencies
- [x] Configure Android build settings (minSdk, applicationId)
- [x] Configure AndroidManifest.xml for SAF and foldable support

## Theme & Design System
- [x] Create `gruvbox_theme.dart` with full color system and ThemeData

## App Shell & Layout
- [x] Create `main.dart` entry point
- [x] Create `app.dart` root MaterialApp
- [x] Create `adaptive_shell.dart` responsive layout controller
- [x] Create `three_pane_layout.dart` with draggable dividers
- [x] Create `single_pane_nav.dart` bottom navigation

## Models
- [x] Create `file_node.dart` tree data model
- [x] Create `chat.dart` data classes
- [x] Create `editor_tab.dart` tab model
- [x] Create `workspace_state.dart` state container

## Services
- [x] Create `saf_storage_service.dart` SAF file operations
- [x] Create `database_service.dart` SQLite schema & CRUD
- [x] Create `frontmatter_service.dart` YAML parser
- [x] Create `wikilink_service.dart` link resolver
- [x] Create `indexer_service.dart` FTS5 workspace indexer

## Providers (Riverpod)
- [x] Create `workspace_provider.dart`
- [x] Create `editor_provider.dart`
- [x] Create `tag_provider.dart`

## Widgets — File Tree
- [x] Create `file_tree_panel.dart`
- [x] Create `file_tree_item.dart`

## Widgets — Editor
- [x] Create `editor_pane.dart` with tabs
- [x] Create `code_editor_widget.dart` with syntax highlighting
- [x] Create `markdown_toolbar.dart`

## Widgets — Preview
- [x] Create `markdown_preview.dart`
- [x] Create `wikilink_builder.dart`

## Widgets — AI (Placeholder)
- [x] Create `ai_panel.dart` stub

## Verification
- [x] `flutter analyze` passes (0 issues)
- [x] `flutter test` passes (15/15 tests passing)
- [x] `flutter build apk --debug` succeeds (`build\app\outputs\flutter-apk\app-debug.apk`)
