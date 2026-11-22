# Agent Operational Guidelines & Skill Router

As an AI software engineering agent working in this repository, produce robust, idiomatic, and maintainable Flutter/Dart software with high velocity and minimal context overhead.

---

## 1. Core Operating Philosophy

1. **High-Velocity Fast Path (Default):** Treat everyday development (bug fixes, widget/unit tests, localized UI/provider tweaks, standard features following established patterns) as zero-overhead tasks. Implement directly and verify with `flutter analyze` and `flutter test` without loading full skill manuals or modifying ADRs/READMEs.
2. **Pragmatic SOLID Baseline:** Favor cohesive modules, focused services (`lib/services/`), reactive Riverpod state providers (`lib/providers/`), and immutable domain models (`lib/models/`)—while respecting YAGNI (avoid premature abstractions or single-implementation "interface soup").
3. **Respect Established Boundaries:** Honor existing specifications (`design.md`, `plan.md`, `docs_local/unified_journal_art_ingestion_plan.md`) and active Architecture Decision Records before altering stack choices, air-gapped network policies, or database schemas.

---

## 2. Dynamic Skill Router (Progressive Disclosure)

Specialized operational skills live under `.agents/skills/<skill-name>/SKILL.md`. To preserve context window and minimize latency, **do not read full `SKILL.md` files unless their trigger conditions apply**.

```text
                                  [ Incoming User Task ]
                                             │
        ┌───────────────────┬───────────────┼───────────────┬───────────────────┐
        ▼                   ▼               ▼               ▼                   ▼
[ Routine Coding ]  [ Feature / Bug ] [ Specs / Design ] [ Design Audit ] [ Fork / Docs ]
  • Trivial edits     • New domain      • Project specs    • God classes    • New core libs,
  • Styling / copy      logic / RAG     • design.md /      • Tight coupling   DB, AI runtime
  • Config tweaks     • Reproducible      plan.md / docs   • SOLID review   • "Update README"
                        bugs                                                    │
        │                   │               │               │                   ▼
        ▼                   ▼               ▼               ▼            `adr-manager` OR
  Fast Path Mode     Load Skill:       Load Skill:     Load Skill:       `comprehensive-readme`
(No skills loaded)  `contract-first-  `ste-spec-      `solid-
                     tdd`              architect`      principles`
```

### Skill Index & Routing Rules

| Route / Skill | Path | Trigger Condition | Prohibited Action |
| :--- | :--- | :--- | :--- |
| **Routine Fast Path** *(Default)* | *(No file loaded)* | Trivial bug fixes, styling/copy tweaks, config updates, or minor extensions following existing patterns. | Do **not** read `.agents/skills/` files; do **not** draft ADRs or edit `README.md`. |
| **Contract-First TDD** | `.agents/skills/contract-first-tdd/SKILL.md` | Implementing non-trivial domain logic, Riverpod providers, RAG/SQLite indexing, manuscript compiler services, or fixing reproducible bugs. | Do **not** declare completion without running `flutter test`; do **not** force heavy test ceremony onto pure styling edits. |
| **STE Spec Architect** | `.agents/skills/ste-spec-architect/SKILL.md` | Authoring or updating `design.md`, `plan.md`, `docs_local/*.md`, or conducting structured project specification intake. | Do **not** skip the phased confirmation interview or generate specs without STE compliance verification. |
| **SOLID Principles** | `.agents/skills/solid-principles/SKILL.md` | Designing new core modules/boundaries, auditing code maintainability, or refactoring coupled/branching/God-Class code. | Do **not** force extra interfaces/factories onto trivial utilities or single-implementation helpers. |
| **ADR Manager** | `.agents/skills/adr-manager/SKILL.md` | Introducing core dependencies/frameworks, changing SQLite/SAF storage, altering `llama.cpp` inference bindings, or explicit ADR tasks. | Do **not** contradict an `Accepted` ADR or write breaking architectural code before presenting a `Proposed` ADR draft. |
| **Comprehensive README** | `.agents/skills/comprehensive-readme/SKILL.md` | Explicit user request to create, regenerate, or overhaul `README.md` or repository onboarding documentation. | Do **not** modify `README.md` during routine coding tasks, invent commands, or emit fake placeholder badges. |

---

## 3. Workflow Routing Details

### A. Routine Coding (Fast Path)
For most day-to-day requests:
1. Locate the relevant source files (`lib/`) and tests (`test/`).
2. Implement the minimal, idiomatic change matching existing codebase conventions.
3. Run relevant tests (`flutter test <test_file>`) and static analysis (`flutter analyze`) to verify behavior.
4. Keep diffs focused; avoid reformatting unrelated files.

### B. Architectural Fork Detection (ADR Guard)
Before adding core packages, swapping databases, changing native GGUF inference bindings (`llama_flutter_android`), or altering the air-gapped manifest policy:
1. Scan `design.md` and `plan.md`.
2. Load `.agents/skills/adr-manager/SKILL.md` and follow its compliance check, bootstrap, or proposal workflow.
3. If the task conflicts with an established guarantee (such as the zero-network-permission air-gap policy), surface the conflict and ask the user before writing implementation code.

### C. Implementation, Specifications, Design Audits, and Documentation
* **New domain logic, services, or reproducible bug fixes:** Load `.agents/skills/contract-first-tdd/SKILL.md`.
* **New or evolving product/system specs:** Load `.agents/skills/ste-spec-architect/SKILL.md`.
* **Structural refactoring or architecture review:** Load `.agents/skills/solid-principles/SKILL.md`.
* **Explicit README / onboarding doc request:** Load `.agents/skills/comprehensive-readme/SKILL.md`.

---

## 4. Universal & Domain Engineering Guardrails

* **Strict Air-Gap Guarantee:** Release `android/app/src/main/AndroidManifest.xml` intentionally omits `android.permission.INTERNET`. Never add internet permissions, telemetry, or cloud API dependencies to the Flutter mobile/desktop application.
* **State Management Determinism:** This project uses **Riverpod** (`flutter_riverpod: ^2.6.1`) with providers in `lib/providers/` and services in `lib/services/`. Never introduce `flutter_bloc` or competing state frameworks.
* **Cross-Platform SQLite Compatibility:** Database operations in `lib/services/database_service.dart` must remain compatible with both `sqflite` (Android) and `sqflite_common_ffi` (Windows Desktop & `flutter test`).
* **On-Device AI Graceful Fallback:** `lib/services/ai_service.dart` executes local `.gguf` models (Gemma 4 E2B / E4B) via `llama_flutter_android` on Android and provides deterministic offline rule-based fallback when no `.gguf` file is loaded or when running in test environments.
* **Adaptive Form Factors:** Preserve responsive support across the 3-Pane Tri-View layout (`lib/layout/three_pane_layout.dart` for Foldables, Samsung DeX, Tablets, and Windows Desktop) and Single-Pane Navigation (`lib/layout/single_pane_nav.dart` for folded phone screens).

---

## 5. Project Commands & Map

* **Install:** `flutter pub get`
* **Dev / Run:** `flutter run` (`flutter run -d windows` or `flutter run -d android`)
* **Test (All Suites):** `flutter test --no-pub`
* **Test (Single Suite):** `flutter test test/compiler_and_pdf_test.dart`
* **Analyze / Lint / Typecheck:** `flutter analyze`
* **Build Android Release APK:** `flutter build apk --release`
* **Build Windows Desktop:** `flutter build windows --release`
* **Journal & Sketch Ingestion CLI (Desktop Companion):** `python scripts/ingest.py --vault "<vault_path>"`
* **Key Entrypoints / Modules:**
  * `lib/main.dart` & `lib/app.dart` — App bootstrap, desktop FFI SQLite initialization, Riverpod `ProviderScope`, and Atelier theme binding
  * `lib/layout/` — `adaptive_shell.dart`, `three_pane_layout.dart` (File Tree/Corkboard | Editor/Preview/Map | AI Co-Pilot/Sidecar), `single_pane_nav.dart`
  * `lib/models/` — 17 immutable domain models (`ai_model_config.dart`, `app_theme_data.dart`, `chat.dart`, `compiler_config.dart`, `diff_model.dart`, `document_template.dart`, `editor_tab.dart`, `file_node.dart`, `journal_ingest_models.dart`, `manuscript_metadata.dart`, `pacing_quota.dart`, `scene_snapshot.dart`, `scrivenings_model.dart`, `search_models.dart`, `sync_models.dart`, `workspace_state.dart`)
  * `lib/providers/` — 12 Riverpod providers (`ai_provider.dart`, `diff_provider.dart`, `editor_provider.dart`, `find_replace_provider.dart`, `layout_provider.dart`, `pacing_provider.dart`, `snapshot_provider.dart`, `sync_provider.dart`, `tag_provider.dart`, `template_provider.dart`, `theme_provider.dart`, `workspace_provider.dart`)
  * `lib/services/` — 25 core services including `ai_service.dart`, `rag_service.dart`, `indexer_service.dart`, `database_service.dart`, `saf_storage_service.dart`, `scrivenings_service.dart`, `compiler_service.dart`, `pdf_service.dart`, `diff_service.dart`, `frontmatter_service.dart`, `wikilink_service.dart`, `ingest_service.dart`, `document_scanner_service.dart`, `audio_recording_service.dart`
  * `lib/widgets/` — Modular UI components across `ai_panel/`, `corkboard/`, `dialogs/`, `editor/`, `file_tree/`, `pdf/`, `preview/`, and `sidecar/`
  * `scripts/ingest.py` — Local Gemma 4 E2B multimodal journal/artwork bounding-box cropper and OCR bridge
  * `test/` — 24 automated unit, widget, and service integration test suites
