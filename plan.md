# Implementation Plan & Milestone Status: Quill & Papyrus AI

## Project Overview

**Quill & Papyrus AI** is an air-gapped, offline-first Markdown IDE and long-form authoring studio built with Flutter for Android (optimized for Samsung Galaxy Z Fold displays and Samsung DeX) and Windows Desktop. It combines local **Gemma 4** GGUF execution (`Gemma 4 E2B` and `Gemma 4 E4B` via `llama.cpp`), heading-aware SQLite RAG, Scrivenings multi-scene editing, Manuscript PDF compilation, and multimodal journal ingestion.

---

## Phase 1: Core Architecture, Riverpod State & Local Storage (Completed)

- [x] **1.1 Cross-Platform Flutter & Riverpod Foundation**
  - Configured Flutter (`Dart ^3.12.2`) targeting Android API 34+ (air-gapped manifest with `0` internet permissions) and Windows Desktop.
  - Implemented reactive state architecture with `flutter_riverpod` across 12 providers in `lib/providers/`.
- [x] **1.2 SAF & Native Filesystem Storage Driver (`lib/services/saf_storage_service.dart`)**
  - Implemented workspace directory selection, recursive `.md` file tree scanning, file CRUD, batch operations, and quick-open navigation.
- [x] **1.3 Cross-Platform SQLite Database (`lib/services/database_service.dart`)**
  - Integrated `sqflite` (Android) and `sqflite_common_ffi` (Windows & automated test suite) for chats, messages, snapshots, and RAG chunk storage.

---

## Phase 2: Markdown IDE, Atelier Themes & Long-Form Authoring (Completed)

- [x] **2.1 Multi-Mode Markdown Editor (`lib/widgets/editor/`)**
  - Built code editor with line numbers, syntax highlighting, find/replace bar, document map outline, and mobile keyboard accessory bar.
- [x] **2.2 YAML Frontmatter, Tags & Wikilinks (`lib/services/frontmatter_service.dart`, `wikilink_service.dart`)**
  - Built YAML frontmatter parser, tag browser/filter, and `[[wikilink]]` resolver with asset path resolution (`asset_resolver_service.dart`).
- [x] **2.3 Scrivenings, Corkboard, Snapshots & Pacing Quotas**
  - Implemented `scrivenings_service.dart` for multi-file scene stitching, Corkboard card layout (`lib/widgets/corkboard/`), `snapshot_provider.dart` for scene versioning, and `pacing_provider.dart` for daily word-count goals.
- [x] **2.4 Manuscript Compiler & PDF Publishing (`lib/services/compiler_service.dart`, `pdf_service.dart`)**
  - Built manuscript compilation pipeline with frontmatter stripping, scene dividers, themed PDF generation (`pdf`), and native print dialogs (`printing`).
- [x] **2.5 Atelier Themes & Typography (`lib/theme/`, `lib/services/typography_service.dart`)**
  - Bundled 6 variable/serif/monospace font families (`Newsreader`, `PlusJakartaSans`, `JetBrainsMono`, `CourierPrime`, `Arimo`, `Roboto`) and customizable Atelier color themes.

---

## Phase 3: On-Device Gemma 4 GGUF Engine & Visual Diffs (Completed)

- [x] **3.1 Native `llama.cpp` Runtime Binding (`lib/services/ai_service.dart`)**
  - Integrated `llama_flutter_android` for local `.gguf` model loading (`Gemma 4 E2B` & `Gemma 4 E4B`) with Vulkan GPU offloading and deterministic offline fallback when no model is loaded.
- [x] **3.2 Context-Aware Writing Actions & Inline Visual Diffs (`lib/services/diff_service.dart`)**
  - Built selection transformations (*Fix Grammar & Style*, *Expand*, *Summarize*, *Action Items*) and side-by-side / inline color-coded diff review (`inline_diff_widget.dart`) with Accept/Reject controls.

---

## Phase 4: Heading-Aware Local RAG & Multimodal Journal Ingestion (Completed)

- [x] **4.1 Heading-Aware Document Indexer & RAG (`lib/services/indexer_service.dart`, `rag_service.dart`)**
  - Chunks workspace Markdown files by `#`, `##`, `###` headings and YAML tags into SQLite and retrieves relevant context blocks into the Gemma 4 system prompt.
- [x] **4.2 Multimodal Voice, Scanner & Journal Art Ingestion (`lib/services/ingest_service.dart`, `scripts/ingest.py`)**
  - Added voice memo recording/playback (`audio_recording_service.dart`, `audio_playback_service.dart`), document camera scanning (`document_scanner_service.dart`), and the Python Gemma 4 E2B artwork bounding-box cropper + handwriting OCR companion script (`scripts/ingest.py`).

---

## Phase 5: Adaptive Foldable / DeX Shell & Automated Verification (Completed)

- [x] **5.1 Adaptive Tri-Pane & Single-Pane Layouts (`lib/layout/`)**
  - Built `ThreePaneLayout` for unfolded foldables, Samsung DeX, tablets, and Windows desktop, collapsing automatically to `SinglePaneNav` on compact phone screens.
- [x] **5.2 Comprehensive Automated Test Coverage (`test/`)**
  - Verified across 24 unit, widget, and service integration test suites (`flutter analyze` & `flutter test`).
