# Unified Multi-Medium Journaling & Art System (`plan.md`)

## 1. System Overview & Philosophy
The goal of this system is to let you write and draw anywhere—**Kindle Scribe Colorsoft**, **Paper Journal**, **OneNote**, or your **Custom Markdown App**—without friction, while automatically consolidating everything into a single, searchable, and editable local Markdown workspace.

* **Single Source of Truth:** Local Markdown files synced between your laptop and phone.
* **Primary Hub:** Chronological Daily Notes (`MM-DD-YY.md`) alongside your long-form project files.
* **Preserve + Transcribe:** Drawings and mixed-media pages are preserved visually as cropped/full-page images embedded inline, while handwritten notes are transcribed into editable Markdown directly underneath.

---

## 2. Directory & File Architecture

```text
/Vault
  ├── /Daily-Logs                # Chronological hub (e.g., 10-24-26.md)
  ├── /Writing-Projects          # Long-form Markdown drafts
  ├── /Assets
  │   ├── /Sketches              # Cropped drawings & full-page visual captures
  │   └── /Raw-Exports           # Original Scribe PDFs & raw photos (Archive)
  └── /Inbox-Dropzone            # Watched folder for automated ingestion
```

### Standardized Note Format (`10-24-26.md`)
```markdown
---
date: 2026-10-24
sources: [native, scribe, paper]
tags: [journal, sketch, worldbuilding]
---

# October 24, 2026

## 09:15 AM - Native Entry
Typed thoughts directly from phone or laptop...

---
## 01:30 PM - Kindle Scribe Import
![Sketch - Character Concept](../Assets/Sketches/10-24-26-scribe-p1-crop1.png)

### Transcribed Notes
Handwritten notes from the Scribe page converted to editable text...
```

---

## 3. Vision AI Evaluation: Using `Gemma 4 E2B` for Artwork Detection & OCR

**Verdict: Yes, `Gemma 4 E2B` (`google/gemma-4-E2B-it`) is an ideal fit for this pipeline—especially for artwork detection and layout routing.**

### Why Gemma 4 E2B Works Well Here
1. **Native Multimodal & Low Footprint:** Gemma 4 E2B is an effective-2B parameter model built with Per-Layer Embeddings (PLE) for edge/local deployment. You can run it locally on your laptop via Ollama, LM Studio, or vLLM with minimal RAM/VRAM usage and zero API costs.
2. **Native Bounding Box Detection:** Gemma 4 natively supports open-vocabulary object detection and outputs structured JSON coordinates in `[ymin, xmin, ymax, xmax]` format (normalized `0` to `1000`). You can prompt it to locate `"hand-drawn sketch, illustration, or diagram"` and use those coordinates to automatically crop your artwork out of a lined page.
3. **Configurable Vision Token Budget:** Gemma 4 allows per-request vision token budgets (`70`, `140`, `280`, `560`, or `1120` tokens).
   * Use **280 tokens** for fast layout detection and bounding-box extraction.
   * Bump to **1120 tokens** when transcribing dense pages of handwritten cursive or small notes.

### Technical Nuances & Mitigations with Gemma 4 E2B
* **Coordinate Normalization:** Gemma 4 returns bounding boxes normalized to a `1000x1000` grid (`[y1, x1, y2, x2]`). Your Python script will multiply these values by the actual image width and height before cropping with Pillow (`PIL`).
* **Messy Handwriting Fallback:** While Gemma 4 E2B at `1120` vision tokens handles clean handwriting and layout segmentation well, if you have particularly messy cursive, you can either:
  * Toggle Gemma 4's built-in **Thinking Mode** (`<|channel>thought`) so it reasons through context to decipher words.
  * Pair E2B (for fast local artwork cropping) with `Gemma 4 E4B` / `12B` or a cloud fallback for heavy text pages.

### Example Gemma 4 E2B Prompt & Output
**Prompt:**
> *"Analyze this journal page. 1. Detect any drawings, sketches, or diagrams and return their bounding boxes as `[ymin, xmin, ymax, xmax]` (0-1000 scale). 2. Transcribe all handwritten text into clean Markdown. Return strictly valid JSON."*

**Expected Output:**
```json
{
  "artworks": [
    {"box_2d": [120, 85, 540, 910], "label": "colored pencil landscape sketch"}
  ],
  "transcribed_text": "### Morning Reflections\nWorked on the canyon scene today. The shadows need warmer tones...",
  "detected_date": "10-24-26",
  "tags": ["sketch", "landscape", "journal"]
}
```

---

## 4. Automated Ingestion Pipelines by Source

### A. Kindle Scribe Colorsoft Pipeline
1. **Trigger:** Tap *Share -> Send to Email* on your Scribe.
2. **Email Rule:** Filter emails from `do-not-reply@amazon.com` with subject `"sent you a file from Kindle"` into a folder/label named `Scribe-Ingest`.
3. **Python Poller (`imaplib` + `PyMuPDF`):**
   * Downloads the linked PDF from the email body.
   * Renders each page at 300 DPI into PNG format (preserving Colorsoft strokes).
   * Passes the PNG to **Gemma 4 E2B** to crop out drawings and transcribe handwriting.

### B. Physical Paper Journal Pipeline
1. **Trigger:** Snap a photo with your phone into your synced `/Inbox-Dropzone` folder.
2. **Pre-Processing (`OpenCV`):**
   * Finds the notebook page contours, performs a 4-point perspective warp to flatten the page, and applies adaptive contrast so ink/pencil pops while paper grain fades.
3. **AI Pass:** Sends the flattened image to **Gemma 4 E2B** for artwork bounding-box extraction and text transcription.

### C. Microsoft OneNote Pipeline
1. **Trigger:** Background script runs every 60 minutes via **Microsoft Graph API** (`GET /me/onenote/pages?$filter=lastModifiedDateTime gt {last_sync}`).
2. **Extraction:**
   * Pulls HTML content and converts text blocks via `markdownify`.
   * Downloads embedded image blobs and rendered SVG ink strokes, passing them through Gemma 4 E2B if handwriting/drawings are present on the canvas.

---

## 5. Updating Your Custom Markdown Software for Inline Images

To make your vibe-coded Markdown editor display sketches and journal captures inline alongside your writing, you can add three targeted upgrades depending on the framework you used:

### A. Path Resolution Hook (Relative & Vault-Root Paths)
Standard Markdown parsers often struggle with local filesystem paths unless configured with a custom protocol or base URL.
* **If built with Electron / Tauri / Webview:** Register a custom protocol handler (e.g., `vault://Assets/Sketches/...`) or intercept `<img>` tags in your Markdown renderer (like `marked.js`, `markdown-it`, or `react-markdown`) to rewrite `../Assets/Sketches/file.png` into an absolute `file://` or local asset URL.
* **Support Obsidian-style Wikilinks (Optional):** Add a regex pre-processor that converts `![[10-24-26-scribe.png]]` into standard `<img src="vault://Assets/Sketches/10-24-26-scribe.png" class="inline-sketch" />`.

### B. Live Inline Preview / WYSIWYG Rendering
* **If using a raw `<textarea>` + Preview Pane:** Upgrade the editor surface to **CodeMirror 6** or **Milkdown** (or add a widget decoration in your existing editor). CodeMirror 6 allows you to add a `Decoration.widget` that renders the actual `<img>` directly underneath the line containing `![alt](path)` while you are typing, so you don't have to switch to a separate preview mode.

### C. Side-by-Side "Source + Transcription" Card UI
For entries imported from your Scribe or Paper Journal, wrap them in a clean HTML container or custom Markdown block so your app displays them gracefully:
* **Click-to-Zoom Lightbox:** Clicking any inline sketch opens a full-screen overlay so you can inspect fine details of your Colorsoft or paper drawings.
* **Split Inspection Mode:** Clicking an "Verify OCR" toggle lets you view the original uncropped page image right next to the transcribed Markdown text so you can easily edit or expand on what you wrote by hand.

---

## 6. Step-by-Step Implementation Roadmap

- [ ] **Phase 1: Folder Setup & App Inline Images**
  - Create `/Daily-Logs`, `/Assets/Sketches`, and `/Inbox-Dropzone` inside your synced Markdown folder.
  - Update your Markdown app's renderer to resolve local image paths from `/Assets/Sketches/` and display them inline with click-to-zoom.
- [ ] **Phase 2: Local Gemma 4 E2B Vision Worker**
  - Set up `google/gemma-4-E2B-it` locally (via Ollama or LM Studio local server).
  - Write a Python script (`ingest.py`) that watches `/Inbox-Dropzone`, sends dropped images/PDFs to Gemma 4 E2B, crops detected `[ymin, xmin, ymax, xmax]` artwork bounding boxes using `Pillow`, and appends the image + transcribed text to today's `MM-DD-YY.md` file.
- [ ] **Phase 3: Paper Pre-Processor & Scribe Email Bridge**
  - Add the OpenCV page-flattening step for phone photos.
  - Add the `imaplib` watcher to automatically pull Kindle Scribe exports from your email into `/Inbox-Dropzone`.
- [ ] **Phase 4: OneNote Graph API Sync**
  - Add the scheduled polling script to pull modified OneNote pages and ink canvases into the same daily Markdown logs.