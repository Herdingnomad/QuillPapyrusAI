# Contributing to Quill & Papyrus AI

Thank you for your interest in contributing to **Quill & Papyrus AI**! We welcome contributions ranging from bug fixes and documentation to new editor tools and AI model runtimes.

---

## Core Guiding Principles

1. **Strictly Air-Gapped & Offline-First:**
   Quill & Papyrus AI will **never** send document data, telemetry, or user queries to external cloud endpoints. Any proposed feature must work completely offline without internet connectivity.
2. **Local AI Independence:**
   Inference is executed strictly on the device using native `llama.cpp` C++ binaries and local `.gguf` weights.
3. **Respect System Resources:**
   Mobile hardware has strict RAM, thermals, and battery constraints. AI pipelines should properly manage controller lifecycles and avoid memory leaks.

---

## Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.12+ / stable channel)
* [Android SDK](https://developer.android.com/studio) (API level 34+) and NDK
* Java 17

### Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Herdingnomad/QuillPapyrusAI.git
   cd QuillPapyrusAI
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify analyzer passes:**
   ```bash
   flutter analyze
   ```

4. **Run on an Android device or emulator:**
   ```bash
   flutter run
   ```
   > **Note:** For testing on-device LLM inference with Vulkan GPU acceleration, a physical Android device with at least 6 GB RAM is recommended.

---

## Architecture Overview

```
lib/
├── models/         # Data structures (Chat, Message, DocumentNode, AiModelConfig)
├── providers/      # Riverpod state notifiers (Workspace, Editor, AI)
├── services/       # Core business & native services
│   ├── ai_service.dart          # Native llama.cpp GGUF loader & inference stream
│   ├── rag_service.dart         # Heading-aware document context extraction
│   ├── indexer_service.dart     # SQLite full-text search & workspace indexing
│   ├── saf_storage_service.dart # Android Storage Access Framework bridge
│   ├── diff_service.dart        # Diff calculation for AI suggestions
│   └── frontmatter_service.dart # YAML frontmatter parser
└── widgets/        # UI layer
    ├── ai/         # AI Co-pilot drawer, chat bubbles, model selector
    ├── editor/     # Markdown source editor & preview widgets
    └── file_tree/  # Workspace sidebar tree & folder browser
```

---

## Submitting Pull Requests

1. **Fork the repository** and create your branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Ensure clean formatting and analysis:**
   ```bash
   dart format .
   flutter analyze
   ```
3. **Commit your changes** using clear, conventional commit messages:
   ```bash
   git commit -m "feat: add table formatting shortcut to markdown toolbar"
   ```
4. **Push to your fork** and submit a Pull Request to `main`.

---

## License

By contributing to Quill & Papyrus AI, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
