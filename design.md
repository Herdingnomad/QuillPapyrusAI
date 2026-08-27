Design Specification: Quill & Papyrus AI

1. System Overview & Architecture

Quill & Papyrus AI is a local-first, on-device AI Markdown IDE built for Android using Flutter. It is optimized for foldable form factors (specifically large-screen inner displays like the Samsung Galaxy Fold 8). The app pairs an IDE-like editing experience with locally hosted Google Gemma 4 models (Gemma 4 E4B / E2B) via LiteRT or llama.cpp C-bindings, featuring dynamic RAG grounded in the active workspace directory.

+-------------------------------------------------------------------------+
|                              Flutter UI                                 |
|  +---------------------+  +--------------------+  +------------------+  |
|  | File Tree / Sidebar |  | Markdown IDE / Diff|  | AI Drawer & Chat |  |
|  +---------------------+  +--------------------+  +------------------+  |
+------------------------------------+------------------------------------+
                                     |
+------------------------------------+------------------------------------+
|                         State / Controller Layer                        |
|   - WorkspaceBloc (SAF)    - EditorBloc        - Chat & RAG Controller  |
+------------------------------------+------------------------------------+
       |                             |                         |
+------v------+              +-------v------+          +-------v--------+
| Storage/SAF |              | Local SQLite |          | On-Device LLM  |
| DocumentFile|              | (Chat & FTS5)|          | (Gemma 4 Engine|
+-------------+              +--------------+          +----------------+


2. Technical Stack

UI Framework: Flutter (Dart) with foldable-aware responsive layouts (flutter_adaptive_scaffold / MediaQuery.displayFeatures).

AI Runtime Engine: LiteRT (TFLite Task API / LiteRT-LM) or llama.cpp Dart FFI executing 4-bit quantized Gemma 4 E4B (4.5B effective params) with NPU/GPU acceleration (Vulkan/OpenCL).

Storage & Indexing:

File System: Android Storage Access Framework (SAF) via saf_stream / shared_storage.

Metadata & Chat DB: sqflite (SQLite) with SQLite FTS5 for local keyword/hybrid RAG indexing.

Markdown & Editor:

Custom CodeField / flutter_code_editor for line numbers, syntax highlighting, and inline gutter diffs.

flutter_markdown with markdown extensions for full GFM, emoji packs (flutter_emoji), and [[wikilink]] AST parsers.

3. UI/UX & Layout Specs

Foldable Adaptive Layouts (Samsung Galaxy Fold 8)

Unfolded / Main Inner Display (3-Pane Tri-View):

Left Pane (~20% width): Workspace file-tree, front-matter tag explorer, and search.

Center Pane (~50% width): Tabbed IDE editor (Source with line numbers / Split View / Rich Preview).

Right Pane (~30% width): Collapsible AI Co-Pilot drawer (Active Document Assistant + RAG Chat).

Folded / Cover Display (Single/Dual Pane): Responsive bottom navigation bar to toggle between File Explorer, Active Editor, and AI Chat.

IDE Features & Components

Gutter & Line Numbers: Dynamic line numbers, fold markers for Markdown # headers, and AI diff change indicators.

Inline Diffs: Color-coded additions (soft green #E6FFED) and deletions (soft red #FFEEF0) directly in the buffer with floating "Accept [✓]" / "Reject [✗]" chip controls.

Context Toolbar: Floating action bar on text selection offering quick prompts:

Fix Grammar & Style

Expand / Deepen

Summarize to Bullets

Convert to Action Items

Preview Pipeline: Renders CommonMark + GFM tables, task lists, UTF-8/Unicode emojis, and internal [[wikilinks]] that resolve directly to sibling files in the workspace.

4. Storage, RAG & Data Models

Android SAF Integration

Persists directory access tokens (takePersistableUriPermission).

Performs directory-wide recursive scans to populate the file tree and watch for external modifications.

Supports batch operations: Multi-select moving, renaming, and exporting to .zip or external directories.

Local SQLite Schema (quill_papyrus.db)

-- Conversations Table (Standalone & Doc-linked chats)
CREATE TABLE chats (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    linked_doc_uri TEXT -- Nullable: populated if tied to a specific file
);

-- Messages Table
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    sender TEXT CHECK(sender IN ('user', 'assistant', 'system')) NOT NULL,
    content TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
);

-- Full-Text Search (FTS5) Index for Local RAG
CREATE VIRTUAL TABLE workspace_index USING fts5(
    file_uri UNINDEXED,
    file_name,
    parent_folder,
    heading_context,
    content,
    tags,
    tokenize = 'porter unicode61'
);


Dynamic Directory-Scoped RAG Engine

Directory Isolation: Search queries during doc-assisted mode filter FTS5 results by parent_folder = current_document_folder.

Chunking & Indexing: Markdown documents are split by heading blocks (#, ##, ###) and updated in SQLite FTS5 upon save or directory load.

Retrieval Strategy: Top 3–5 relevant content blocks are retrieved and formatted into Gemma 4's native system prompt context window.

5. On-Device Gemma 4 Model Specs

Primary Target: Gemma 4 E4B (4-bit quantized GGUF / .task bundle, ~3.5 GB RAM footprint).

Fallback / Speed Target: Gemma 4 E2B (4-bit quantized, ~2.0 GB RAM footprint).

Context Window: Up to 128,000 tokens utilizing hybrid sliding-window attention.

Offline Execution: 100% on-device processing via Android NPU/GPU using LiteRT or llama.cpp Dart FFI bindings. Zero external network connectivity required.
