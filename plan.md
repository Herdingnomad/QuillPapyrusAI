Implementation Plan: Quill & Papyrus AI

Project Overview

Quill & Papyrus AI is an on-device, offline-first Markdown IDE designed for Android (optimized for foldable screens like the Samsung Galaxy Fold 8). Built with Flutter, it integrates local Gemma 4 LLM execution (Gemma 4 E4B / E2B), directory-level RAG context retrieval, Android Storage Access Framework (SAF) file management, and SQLite-backed standalone chat.

Phase 1: Core Architecture & SAF File Management

[ ] 1.1 Flutter Environment & Dependency Setup

Initialize Flutter project targeting Android SDK 34+.

Integrate core packages: flutter_bloc / riverpod, saf_stream / shared_storage, sqflite, path_provider, flutter_code_editor.

[ ] 1.2 Android SAF Storage Driver

Implement directory picking with persistent permission tokens (takePersistableUriPermission).

Create recursive workspace directory reader and file system observer.

Implement file operation primitives: create, read, save, rename, batch move, delete, and directory zip export.

[ ] 1.3 Storage & Metadata Database

Initialize local SQLite database (quill_papyrus.db).

Execute schema setup for chats, messages, document links, and FTS5 search tables.

Phase 2: Markdown IDE & Editing Engine

[ ] 2.1 IDE Code Editor Widget

Build custom editor with gutter line numbers, cursor position indicators, line highlighting, and text fold points.

Configure real-time syntax highlighting for Markdown constructs (headings, blockquotes, code blocks, lists).

[ ] 2.2 Front-Matter & Tag Parser

Build YAML front-matter extractor to parse tags, titles, and metadata from target files.

Expose tag navigation and filtering across the active workspace tree.

[ ] 2.3 Markdown Preview & Wikilink Engine

Construct live/split preview using standard GFM parser.

Add Unicode emoji shortcode mapping (:smile:, :rocket:, etc.).

Implement [[wikilink]] parser to resolve double-bracket internal links and handle navigation tap events.

Phase 3: On-Device Gemma 4 AI Engine & Inline Diffs

[ ] 3.1 Gemma 4 Model Runtime Binding

Integrate native C bindings (llama.cpp FFI or LiteRT Task runner) for Flutter.

Package model loader for Gemma 4 E4B (Primary) and Gemma 4 E2B (Low-Power).

Implement asynchronous token streaming pipeline with NPU/GPU hardware acceleration.

[ ] 3.2 Context-Aware Editor Prompting

Build selection context provider utilizing Gemma 4 native system prompts for action triggers: Fix Grammar & Style, Expand / Deepen, Summarize, Convert to Action Items.

[ ] 3.3 Inline Diff Rendering System

Implement line-by-line / word-by-word diff calculation comparing current editor text with Gemma 4 proposals.

Build inline gutter markers (green additions, red deletions) and interactive "Accept [✓]" / "Reject [✗]" chip controls.

Phase 4: Local Workspace RAG & Chat System

[ ] 4.1 Workspace Document Indexer

Build document chunker that splits Markdown files by section headers (#, ##, ###).

Automatically update SQLite FTS5 index on file creation, modification, or workspace switch.

[ ] 4.2 Directory-Scoped RAG Pipeline

Limit RAG retrieval scope to files sharing the directory of the currently open document.

Perform hybrid FTS5 lexical matching to select relevant context blocks into Gemma 4’s system prompt window.

[ ] 4.3 Standalone AI Chat UI

Implement persistent conversational interface detached from active documents.

Persist conversation histories, system parameters, and message logs in SQLite.

Phase 5: Foldable UI Optimization & Final QA

[ ] 5.1 Samsung Fold 8 Responsive Layouts

Configure 3-pane adaptive layout for unfolded state (File Tree | Editor | AI Assistant).

Configure collapsible single-pane navigation for cover display state.

Test seamless layout reconfiguration on device unfold/fold transitions.

[ ] 5.2 Performance & Memory Optimization

Benchmark on-device Gemma 4 E4B RAM footprint (~3.5 GB) to ensure smooth multitasking on Galaxy Fold 8.

Optimize FTS5 indexing performance on directories with 500+ Markdown files.

[ ] 5.3 End-to-End Testing

Verify complete offline operation without internet connectivity.

Run regression tests on file writes, SAF permissions across app restarts, and markdown render fidelity.
